import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

enum JamRole { none, host, client }

enum JamConnectionStatus {
  disconnected,
  checkingNetwork,
  networkReady,
  noNetwork,
  hosting,
  connecting,
  connected,
  error,
}

class JamConnectionInfo {
  final String sessionId;
  final String sessionName;
  final String hostIp;
  final int httpPort;
  final int wsPort;

  const JamConnectionInfo({
    required this.sessionId,
    required this.sessionName,
    required this.hostIp,
    required this.httpPort,
    required this.wsPort,
  });

  Map<String, dynamic> toJson() => {
        'app': 'pocketplay',
        'type': 'jam_session',
        'version': 1,
        'id': sessionId,
        'name': sessionName,
        'ip': hostIp,
        'port': httpPort,
        'wsPort': wsPort,
      };

  String toJsonString() => jsonEncode(toJson());

  static JamConnectionInfo? fromJsonString(String raw) {
    try {
      final map = jsonDecode(raw);
      if (map is Map &&
          map['app'] == 'pocketplay' &&
          map['type'] == 'jam_session' &&
          map['ip'] != null) {
        return JamConnectionInfo(
          sessionId: map['id']?.toString() ?? 'JAM-${Random().nextInt(9000) + 1000}',
          sessionName: map['name']?.toString() ?? 'Pocketo Jam',
          hostIp: map['ip'].toString(),
          httpPort: map['port'] is int ? map['port'] : int.tryParse(map['port'].toString()) ?? 8992,
          wsPort: map['wsPort'] is int ? map['wsPort'] : int.tryParse(map['wsPort'].toString()) ?? 8993,
        );
      }
    } catch (e) {
      debugPrint('[JamSyncService] Parse QR error: $e');
    }
    return null;
  }
}

class JamPeer {
  final String id;
  final String address;
  final DateTime joinedAt;

  JamPeer({
    required this.id,
    required this.address,
    required this.joinedAt,
  });
}

class JamSyncService extends ChangeNotifier {
  static final JamSyncService _instance = JamSyncService._internal();
  static JamSyncService get instance => _instance;

  JamSyncService._internal();

  // ── State Variables ────────────────────────────────────────────────────────
  JamRole _role = JamRole.none;
  JamConnectionStatus _status = JamConnectionStatus.disconnected;
  String? _errorMessage;

  String? _localIp;
  bool _isHotspotLikely = false;
  JamConnectionInfo? _currentSession;

  // Track State
  String? _currentTrackPath;
  String? _currentTitle;
  String? _currentArtist;
  Duration _currentDuration = Duration.zero;
  Duration _currentPosition = Duration.zero;
  bool _isPlaying = false;

  // Clock Sync & Phase-Locked Loop (PLL) State
  int _anchorHostTimeMs = 0;
  int _anchorPositionMs = 0;
  double _clockOffsetMs = 0; // Host Time - Client Time
  int _rttMs = 0;
  double _userLatencyOffsetMs = 0; // Manual fine-tune adjustment (+/- ms)
  int _lastDriftMs = 0;
  double _currentPlaybackSpeed = 1.0;
  Timer? _hostSyncHeartbeatTimer;
  Timer? _clientPllTimer;
  Timer? _clientPingTimer;

  // Host networking
  HttpServer? _httpServer;
  HttpServer? _wsServer;
  final int _httpPort = 8992;
  final int _wsPort = 8993;
  final Set<WebSocket> _connectedClientSockets = {};
  final List<JamPeer> _connectedPeers = [];

  // Client networking
  WebSocket? _clientSocket;
  StreamSubscription? _clientSocketSub;
  AudioPlayer? _clientPlayer;
  bool _ownsClientPlayer = false;

  // ── Getters ────────────────────────────────────────────────────────────────
  JamRole get role => _role;
  bool get isHost => _role == JamRole.host;
  bool get isClient => _role == JamRole.client;
  bool get isInJam => _role != JamRole.none && (_status == JamConnectionStatus.hosting || _status == JamConnectionStatus.connected);
  JamConnectionStatus get status => _status;
  String? get errorMessage => _errorMessage;
  String? get localIp => _localIp;
  bool get isHotspotLikely => _isHotspotLikely;
  JamConnectionInfo? get currentSession => _currentSession;
  int get peerCount => isHost ? _connectedPeers.length : (_status == JamConnectionStatus.connected ? 1 : 0);
  List<JamPeer> get connectedPeers => List.unmodifiable(_connectedPeers);

  String? get currentTitle => _currentTitle;
  String? get currentArtist => _currentArtist;
  Duration get currentDuration => _currentDuration;
  Duration get currentPosition => _currentPosition;
  bool get isPlaying => _isPlaying;

  // Sync Diagnostics
  int get rttMs => _rttMs;
  int get lastDriftMs => _lastDriftMs;
  double get userLatencyOffsetMs => _userLatencyOffsetMs;
  double get currentPlaybackSpeed => _currentPlaybackSpeed;

  void setUserLatencyOffsetMs(double offsetMs) {
    _userLatencyOffsetMs = offsetMs;
    notifyListeners();
  }

  // ── Network Discovery & IP Resolution ──────────────────────────────────────
  Future<bool> detectNetwork() async {
    final wasInJam = isInJam;
    if (!wasInJam) {
      _status = JamConnectionStatus.checkingNetwork;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );

      String? foundIp;
      bool hotspotFlag = false;

      for (final iface in interfaces) {
        final name = iface.name.toLowerCase();
        for (final addr in iface.addresses) {
          if (!addr.isLoopback && !addr.address.startsWith('127.')) {
            final ip = addr.address;
            if (name.contains('ap') ||
                name.contains('wlan') ||
                name.contains('swlan') ||
                name.contains('tether') ||
                ip.startsWith('192.168.43.') ||
                ip.startsWith('192.168.49.') ||
                ip.startsWith('172.20.10.') ||
                ip.startsWith('192.168.')) {
              foundIp = ip;
              if (ip.startsWith('192.168.43.') || ip.startsWith('172.20.10.') || name.contains('ap') || name.contains('tether')) {
                hotspotFlag = true;
              }
              break;
            } else {
              foundIp ??= ip;
            }
          }
        }
        if (foundIp != null && hotspotFlag) break;
      }

      _localIp = foundIp;
      _isHotspotLikely = hotspotFlag;

      if (_localIp != null) {
        if (!wasInJam) {
          _status = JamConnectionStatus.networkReady;
        }
        notifyListeners();
        return true;
      } else {
        if (!wasInJam) {
          _status = JamConnectionStatus.noNetwork;
          _errorMessage = 'No active Hotspot or Wi-Fi network detected.';
        }
        notifyListeners();
        return false;
      }
    } catch (e) {
      debugPrint('[JamSyncService] Network detection failed: $e');
      if (!wasInJam) {
        _status = JamConnectionStatus.noNetwork;
        _errorMessage = 'Unable to inspect network interfaces: $e';
      }
      notifyListeners();
      return false;
    }
  }

  // ── Host Flow ──────────────────────────────────────────────────────────────
  Future<bool> startHostSession({
    String? customSessionName,
    String? initialTrackPath,
    String? title,
    String? artist,
    Duration duration = Duration.zero,
    Duration position = Duration.zero,
    bool isPlaying = false,
  }) async {
    await leaveSession();

    final hasNetwork = await detectNetwork();
    if (!hasNetwork || _localIp == null) {
      return false;
    }

    try {
      _role = JamRole.host;
      _status = JamConnectionStatus.hosting;
      _currentTrackPath = initialTrackPath;
      _currentTitle = title;
      _currentArtist = artist;
      _currentDuration = duration;
      _currentPosition = position;
      _isPlaying = isPlaying;

      _anchorPositionMs = position.inMilliseconds;
      _anchorHostTimeMs = DateTime.now().millisecondsSinceEpoch;

      final randId = (Random().nextInt(9000) + 1000).toString();
      final sessionName = customSessionName ?? 'Pocketo Jam #$randId';

      _currentSession = JamConnectionInfo(
        sessionId: 'JAM-$randId',
        sessionName: sessionName,
        hostIp: _localIp!,
        httpPort: _httpPort,
        wsPort: _wsPort,
      );

      // Start HTTP file streaming server
      await _startHttpServer();

      // Start WebSocket control server
      await _startWsServer();

      // Start periodic clock sync heartbeat (every 1.5 seconds)
      _hostSyncHeartbeatTimer?.cancel();
      _hostSyncHeartbeatTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) {
        if (isHost && _status == JamConnectionStatus.hosting) {
          _broadcast({
            'action': 'SYNC_HEARTBEAT',
            'hostServerTime': DateTime.now().millisecondsSinceEpoch,
            'anchorPositionMs': _anchorPositionMs,
            'anchorHostTimeMs': _anchorHostTimeMs,
            'isPlaying': _isPlaying,
            'durationMs': _currentDuration.inMilliseconds,
          });
        }
      });

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[JamSyncService] Failed to start host session: $e');
      _status = JamConnectionStatus.error;
      _errorMessage = 'Failed to start Jam session: $e';
      await leaveSession();
      notifyListeners();
      return false;
    }
  }

  Future<void> _startHttpServer() async {
    _httpServer = await HttpServer.bind(
      InternetAddress.anyIPv4,
      _httpPort,
      shared: true,
    );
    debugPrint('[JamSyncService] HTTP Server listening on port $_httpPort');

    _httpServer!.listen((HttpRequest request) async {
      try {
        final path = request.uri.path;
        if (path == '/jam_stream' || path.startsWith('/stream')) {
          if (_currentTrackPath == null) {
            request.response.statusCode = HttpStatus.notFound;
            await request.response.close();
            return;
          }

          final file = File(_currentTrackPath!);
          if (!await file.exists()) {
            request.response.statusCode = HttpStatus.notFound;
            await request.response.close();
            return;
          }

          final fileLength = await file.length();
          final ext = _currentTrackPath!.split('.').last.toLowerCase();
          final contentType = _getContentType(ext);

          final rangeHeader = request.headers.value(HttpHeaders.rangeHeader);
          if (rangeHeader != null && rangeHeader.startsWith('bytes=')) {
            final range = rangeHeader.substring(6).split('-');
            final start = int.tryParse(range[0]) ?? 0;
            final end = (range.length > 1 && range[1].isNotEmpty)
                ? (int.tryParse(range[1]) ?? (fileLength - 1))
                : (fileLength - 1);

            final chunkLength = (end - start) + 1;

            request.response.statusCode = HttpStatus.partialContent;
            request.response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
            request.response.headers.set(
              HttpHeaders.contentRangeHeader,
              'bytes $start-$end/$fileLength',
            );
            request.response.headers.set(HttpHeaders.contentLengthHeader, chunkLength);
            request.response.headers.set(HttpHeaders.contentTypeHeader, contentType);

            await request.response.addStream(file.openRead(start, end + 1));
            await request.response.close();
          } else {
            request.response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
            request.response.headers.set(HttpHeaders.contentLengthHeader, fileLength);
            request.response.headers.set(HttpHeaders.contentTypeHeader, contentType);

            await request.response.addStream(file.openRead());
            await request.response.close();
          }
        } else {
          request.response.statusCode = HttpStatus.notFound;
          await request.response.close();
        }
      } catch (e) {
        debugPrint('[JamSyncService] HTTP Error: $e');
        try {
          request.response.statusCode = HttpStatus.internalServerError;
          await request.response.close();
        } catch (_) {}
      }
    });
  }

  Future<void> _startWsServer() async {
    _wsServer = await HttpServer.bind(
      InternetAddress.anyIPv4,
      _wsPort,
      shared: true,
    );
    debugPrint('[JamSyncService] WebSocket Server listening on port $_wsPort');

    _wsServer!.listen((HttpRequest request) async {
      if (WebSocketTransformer.isUpgradeRequest(request)) {
        try {
          final socket = await WebSocketTransformer.upgrade(request);
          final peerId = 'peer_${Random().nextInt(9999)}';
          final peerIp = request.connectionInfo?.remoteAddress.address ?? 'Unknown';

          final peer = JamPeer(
            id: peerId,
            address: peerIp,
            joinedAt: DateTime.now(),
          );

          _connectedClientSockets.add(socket);
          _connectedPeers.add(peer);
          notifyListeners();

          debugPrint('[JamSyncService] Client joined: $peerIp. Total peers: ${_connectedPeers.length}');

          final now = DateTime.now().millisecondsSinceEpoch;
          int livePositionMs = _anchorPositionMs;
          if (_isPlaying && _anchorHostTimeMs > 0) {
            livePositionMs += (now - _anchorHostTimeMs);
          }

          // Send current state with exact live clock anchors
          _sendDirectMessage(socket, {
            'action': 'INIT_STATE',
            'sessionId': _currentSession?.sessionId,
            'title': _currentTitle,
            'artist': _currentArtist,
            'durationMs': _currentDuration.inMilliseconds,
            'anchorPositionMs': livePositionMs,
            'anchorHostTimeMs': now,
            'positionMs': livePositionMs,
            'isPlaying': _isPlaying,
            'streamUrl': _getStreamUrl(),
            'hostServerTime': now,
          });

          socket.listen(
            (data) {
              _handleHostReceivedClientMessage(socket, data);
            },
            onDone: () {
              _connectedClientSockets.remove(socket);
              _connectedPeers.removeWhere((p) => p.id == peerId);
              notifyListeners();
              debugPrint('[JamSyncService] Client disconnected: $peerIp');
            },
            onError: (err) {
              _connectedClientSockets.remove(socket);
              _connectedPeers.removeWhere((p) => p.id == peerId);
              notifyListeners();
              debugPrint('[JamSyncService] Client error: $err');
            },
          );
        } catch (e) {
          debugPrint('[JamSyncService] WebSocket Upgrade error: $e');
        }
      }
    });
  }

  void _handleHostReceivedClientMessage(WebSocket socket, dynamic rawData) {
    try {
      final msg = jsonDecode(rawData.toString());
      if (msg is Map) {
        if (msg['action'] == 'PING') {
          final clientSendTime = msg['t0'];
          _sendDirectMessage(socket, {
            'action': 'PONG',
            't0': clientSendTime,
            't1': DateTime.now().millisecondsSinceEpoch,
          });
        }
      }
    } catch (_) {}
  }

  // ── Host Playback Broadcast Hooks ──────────────────────────────────────────

  void onHostTrackChanged({
    required String filePath,
    required String title,
    required String artist,
    required Duration duration,
    Duration initialPosition = Duration.zero,
    bool isPlaying = true,
  }) {
    if (!isHost) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    _currentTrackPath = filePath;
    _currentTitle = title;
    _currentArtist = artist;
    _currentDuration = duration;
    _currentPosition = initialPosition;
    _isPlaying = isPlaying;

    _anchorPositionMs = initialPosition.inMilliseconds;
    _anchorHostTimeMs = now;

    _broadcast({
      'action': 'TRACK_CHANGED',
      'title': title,
      'artist': artist,
      'durationMs': duration.inMilliseconds,
      'anchorPositionMs': _anchorPositionMs,
      'anchorHostTimeMs': _anchorHostTimeMs,
      'isPlaying': isPlaying,
      'streamUrl': _getStreamUrl(),
      'hostServerTime': now,
    });
    notifyListeners();
  }

  void onHostPlaybackStateChanged(bool isPlaying, Duration position) {
    if (!isHost) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    _isPlaying = isPlaying;
    _currentPosition = position;

    _anchorPositionMs = position.inMilliseconds;
    _anchorHostTimeMs = now;

    _broadcast({
      'action': isPlaying ? 'PLAY' : 'PAUSE',
      'isPlaying': isPlaying,
      'anchorPositionMs': _anchorPositionMs,
      'anchorHostTimeMs': _anchorHostTimeMs,
      'hostServerTime': now,
    });
    notifyListeners();
  }

  void onHostSeek(Duration position) {
    if (!isHost) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    _currentPosition = position;
    _anchorPositionMs = position.inMilliseconds;
    _anchorHostTimeMs = now;

    _broadcast({
      'action': 'SEEK',
      'anchorPositionMs': _anchorPositionMs,
      'anchorHostTimeMs': _anchorHostTimeMs,
      'isPlaying': _isPlaying,
      'hostServerTime': now,
    });
    notifyListeners();
  }

  void updateHostLivePosition(Duration position, bool isPlaying) {
    if (!isHost) return;
    _currentPosition = position;
    _isPlaying = isPlaying;
    _anchorPositionMs = position.inMilliseconds;
    _anchorHostTimeMs = DateTime.now().millisecondsSinceEpoch;
  }

  void _broadcast(Map<String, dynamic> payload) {
    final raw = jsonEncode(payload);
    for (final socket in List<WebSocket>.from(_connectedClientSockets)) {
      try {
        socket.add(raw);
      } catch (e) {
        debugPrint('[JamSyncService] Failed to broadcast to client: $e');
      }
    }
  }

  void _sendDirectMessage(WebSocket socket, Map<String, dynamic> payload) {
    try {
      socket.add(jsonEncode(payload));
    } catch (_) {}
  }

  String? _getStreamUrl() {
    if (_localIp == null) return null;
    return 'http://$_localIp:$_httpPort/jam_stream';
  }

  // ── Client Flow ────────────────────────────────────────────────────────────
  Future<bool> joinSession(
    JamConnectionInfo info, {
    AudioPlayer? sharedPlayer,
  }) async {
    await leaveSession();

    _role = JamRole.client;
    _status = JamConnectionStatus.connecting;
    _errorMessage = null;
    _currentSession = info;
    notifyListeners();

    if (sharedPlayer != null) {
      _clientPlayer = sharedPlayer;
      _ownsClientPlayer = false;
    } else {
      _clientPlayer = AudioPlayer();
      _ownsClientPlayer = true;
    }

    try {
      final wsUri = Uri.parse('ws://${info.hostIp}:${info.wsPort}');
      debugPrint('[JamSyncService] Connecting to Host at $wsUri');

      _clientSocket = await WebSocket.connect(wsUri.toString()).timeout(
        const Duration(seconds: 7),
        onTimeout: () {
          throw TimeoutException('Could not connect to Jam host. Make sure you are connected to the same Hotspot/Wi-Fi.');
        },
      );

      _status = JamConnectionStatus.connected;
      notifyListeners();

      _clientSocketSub = _clientSocket!.listen(
        (data) => _handleClientReceivedMessage(data),
        onDone: () {
          debugPrint('[JamSyncService] Disconnected from Host Jam');
          _status = JamConnectionStatus.disconnected;
          _errorMessage = 'Jam Session ended by host.';
          _clientPlayer?.pause();
          notifyListeners();
        },
        onError: (err) {
          debugPrint('[JamSyncService] Host socket error: $err');
          _status = JamConnectionStatus.error;
          _errorMessage = 'Connection lost: $err';
          _clientPlayer?.pause();
          notifyListeners();
        },
      );

      // Perform rapid initial NTP calibration (4 pings)
      _sendPing();
      Timer(const Duration(milliseconds: 200), _sendPing);
      Timer(const Duration(milliseconds: 500), _sendPing);
      Timer(const Duration(milliseconds: 900), _sendPing);

      // Regular clock sync ping every 3 seconds
      _clientPingTimer?.cancel();
      _clientPingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
        _sendPing();
      });

      // Start continuous Adaptive Phase-Locked Loop (PLL) (every 500ms)
      _startClientPhaseLockedLoop();

      return true;
    } catch (e) {
      debugPrint('[JamSyncService] Failed to join session: $e');
      _status = JamConnectionStatus.error;
      _errorMessage = 'Failed to connect: $e';
      await leaveSession();
      notifyListeners();
      return false;
    }
  }

  void _sendPing() {
    if (_clientSocket != null && _status == JamConnectionStatus.connected) {
      try {
        _clientSocket!.add(jsonEncode({
          'action': 'PING',
          't0': DateTime.now().millisecondsSinceEpoch,
        }));
      } catch (_) {}
    }
  }

  Future<void> _handleClientReceivedMessage(dynamic raw) async {
    try {
      final msg = jsonDecode(raw.toString());
      if (msg is! Map) return;

      final action = msg['action']?.toString();

      if (action == 'PONG') {
        final t0 = msg['t0'] as int?;
        final t1 = msg['t1'] as int?; // Host time
        if (t0 != null && t1 != null) {
          final t2 = DateTime.now().millisecondsSinceEpoch; // Client receive time
          final rtt = t2 - t0;
          final offset = t1 + (rtt / 2.0) - t2;

          _rttMs = rtt;
          if (_clockOffsetMs == 0) {
            _clockOffsetMs = offset;
          } else {
            // Smooth offset update with exponential moving average
            _clockOffsetMs = (_clockOffsetMs * 0.7) + (offset * 0.3);
          }
        }
        return;
      }

      if (action == 'INIT_STATE' || action == 'TRACK_CHANGED') {
        _currentTitle = msg['title']?.toString() ?? 'Synced Track';
        _currentArtist = msg['artist']?.toString() ?? 'Host Device';
        _currentDuration = Duration(milliseconds: msg['durationMs'] ?? 0);
        _isPlaying = msg['isPlaying'] == true;

        _anchorPositionMs = msg['anchorPositionMs'] ?? msg['positionMs'] ?? 0;
        _anchorHostTimeMs = msg['anchorHostTimeMs'] ?? msg['hostServerTime'] ?? DateTime.now().millisecondsSinceEpoch;

        final streamUrl = msg['streamUrl']?.toString();
        if (streamUrl != null && streamUrl.isNotEmpty && _clientPlayer != null) {
          try {
            final audioSource = AudioSource.uri(
              Uri.parse(streamUrl),
              tag: MediaItem(
                id: 'jam_stream_${DateTime.now().millisecondsSinceEpoch}',
                title: _currentTitle ?? 'Jam Track',
                artist: _currentArtist ?? 'Pocketo Jam',
                album: 'Pocketo Jam Session',
              ),
            );

            // Compute expected current playback position based on host timeline
            final targetPos = _calculateCurrentTargetPosition();

            await _clientPlayer!.setAudioSource(
              audioSource,
              initialPosition: targetPos,
            );

            // Resync target position right after buffering is complete
            final targetPosAfterLoad = _calculateCurrentTargetPosition();
            await _clientPlayer!.seek(targetPosAfterLoad);

            if (_isPlaying) {
              await _clientPlayer!.play();
            } else {
              await _clientPlayer!.pause();
            }
          } catch (e) {
            debugPrint('[JamSyncService] Failed to load stream: $e');
          }
        }
        notifyListeners();
      } else if (action == 'PLAY') {
        _isPlaying = true;
        _anchorPositionMs = msg['anchorPositionMs'] ?? 0;
        _anchorHostTimeMs = msg['anchorHostTimeMs'] ?? DateTime.now().millisecondsSinceEpoch;

        if (_clientPlayer != null) {
          final targetPos = _calculateCurrentTargetPosition();
          await _clientPlayer!.seek(targetPos);
          await _clientPlayer!.play();
        }
        notifyListeners();
      } else if (action == 'PAUSE') {
        _isPlaying = false;
        _anchorPositionMs = msg['anchorPositionMs'] ?? 0;
        _anchorHostTimeMs = msg['anchorHostTimeMs'] ?? DateTime.now().millisecondsSinceEpoch;

        if (_clientPlayer != null) {
          await _clientPlayer!.seek(Duration(milliseconds: _anchorPositionMs));
          await _clientPlayer!.pause();
        }
        notifyListeners();
      } else if (action == 'SEEK') {
        _anchorPositionMs = msg['anchorPositionMs'] ?? 0;
        _anchorHostTimeMs = msg['anchorHostTimeMs'] ?? DateTime.now().millisecondsSinceEpoch;
        _isPlaying = msg['isPlaying'] == true;

        if (_clientPlayer != null) {
          final targetPos = _calculateCurrentTargetPosition();
          await _clientPlayer!.seek(targetPos);
          if (_isPlaying) {
            await _clientPlayer!.play();
          }
        }
        notifyListeners();
      } else if (action == 'SYNC_HEARTBEAT') {
        _anchorPositionMs = msg['anchorPositionMs'] ?? _anchorPositionMs;
        _anchorHostTimeMs = msg['anchorHostTimeMs'] ?? _anchorHostTimeMs;
        _isPlaying = msg['isPlaying'] == true;
        if (msg['durationMs'] != null) {
          _currentDuration = Duration(milliseconds: msg['durationMs']);
        }
      }
    } catch (e) {
      debugPrint('[JamSyncService] Error handling client packet: $e');
    }
  }

  Duration _calculateCurrentTargetPosition() {
    if (!_isPlaying) {
      return Duration(milliseconds: _anchorPositionMs);
    }
    final clientNow = DateTime.now().millisecondsSinceEpoch;
    final estimatedHostNow = clientNow + _clockOffsetMs;
    final elapsedSinceAnchor = estimatedHostNow - _anchorHostTimeMs;

    // Apply manual user latency offset (+/- fine tuning for Bluetooth / speakers)
    final targetMs = max(0, (_anchorPositionMs + elapsedSinceAnchor + _userLatencyOffsetMs).round());
    return Duration(milliseconds: targetMs);
  }

  // ── Adaptive Phase-Locked Loop (PLL) Engine ────────────────────────────────
  void _startClientPhaseLockedLoop() {
    _clientPllTimer?.cancel();
    _clientPllTimer = Timer.periodic(const Duration(milliseconds: 600), (_) async {
      if (!isClient || _status != JamConnectionStatus.connected || _clientPlayer == null || !_isPlaying) {
        return;
      }

      final targetPos = _calculateCurrentTargetPosition();
      final actualPos = _clientPlayer!.position;
      final driftMs = targetPos.inMilliseconds - actualPos.inMilliseconds;
      _lastDriftMs = driftMs;

      // 1. Large drift (> 350ms): Direct seek to snap instantly
      if (driftMs.abs() > 350) {
        debugPrint('[JamSyncService] Snap seek due to large drift: ${driftMs}ms');
        await _clientPlayer!.seek(targetPos);
        if (_currentPlaybackSpeed != 1.0) {
          _currentPlaybackSpeed = 1.0;
          await _clientPlayer!.setSpeed(1.0);
        }
      }
      // 2. Moderate drift (30ms to 350ms): Micro-adjust playback speed for seamless smooth alignment
      else if (driftMs > 30) {
        // Client is lagging behind host: speed up slightly
        final desiredSpeed = min(1.06, 1.0 + (driftMs / 3000.0));
        if ((_currentPlaybackSpeed - desiredSpeed).abs() > 0.005) {
          _currentPlaybackSpeed = desiredSpeed;
          await _clientPlayer!.setSpeed(desiredSpeed);
        }
      } else if (driftMs < -30) {
        // Client is ahead of host: slow down slightly
        final desiredSpeed = max(0.94, 1.0 + (driftMs / 3000.0));
        if ((_currentPlaybackSpeed - desiredSpeed).abs() > 0.005) {
          _currentPlaybackSpeed = desiredSpeed;
          await _clientPlayer!.setSpeed(desiredSpeed);
        }
      } else {
        // Drift is < 30ms (perfect in-phase lock): normalize to standard 1.0x speed
        if (_currentPlaybackSpeed != 1.0) {
          _currentPlaybackSpeed = 1.0;
          await _clientPlayer!.setSpeed(1.0);
        }
      }
      notifyListeners();
    });
  }

  // ── Leave / Teardown ───────────────────────────────────────────────────────
  Future<void> leaveSession() async {
    _hostSyncHeartbeatTimer?.cancel();
    _hostSyncHeartbeatTimer = null;
    _clientPingTimer?.cancel();
    _clientPingTimer = null;
    _clientPllTimer?.cancel();
    _clientPllTimer = null;

    if (_clientSocketSub != null) {
      await _clientSocketSub!.cancel();
      _clientSocketSub = null;
    }

    if (_clientSocket != null) {
      try {
        await _clientSocket!.close();
      } catch (_) {}
      _clientSocket = null;
    }

    if (_ownsClientPlayer && _clientPlayer != null) {
      try {
        await _clientPlayer!.stop();
        await _clientPlayer!.dispose();
      } catch (_) {}
      _clientPlayer = null;
    }

    for (final socket in _connectedClientSockets) {
      try {
        await socket.close();
      } catch (_) {}
    }
    _connectedClientSockets.clear();
    _connectedPeers.clear();

    if (_httpServer != null) {
      try {
        await _httpServer!.close(force: true);
      } catch (_) {}
      _httpServer = null;
    }

    if (_wsServer != null) {
      try {
        await _wsServer!.close(force: true);
      } catch (_) {}
      _wsServer = null;
    }

    _role = JamRole.none;
    _status = JamConnectionStatus.disconnected;
    _currentSession = null;
    _errorMessage = null;
    _clockOffsetMs = 0;
    _rttMs = 0;
    _lastDriftMs = 0;
    _currentPlaybackSpeed = 1.0;
    notifyListeners();
  }

  String _getContentType(String extension) {
    switch (extension) {
      case 'm4a':
      case 'aac':
        return 'audio/aac';
      case 'wav':
        return 'audio/wav';
      case 'flac':
        return 'audio/flac';
      case 'ogg':
      case 'opus':
        return 'audio/ogg';
      default:
        return 'audio/mpeg';
    }
  }
}
