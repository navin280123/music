import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:multicast_dns/multicast_dns.dart';
import 'package:http/http.dart' as http;

enum CastPlaybackState { idle, playing, paused, buffering }

class CastDevice {
  final String name;
  final String host;
  final int port;
  final String? model;
  final String type;

  const CastDevice({
    required this.name,
    required this.host,
    required this.port,
    this.model,
    this.type = 'chromecast',
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CastDevice &&
          runtimeType == other.runtimeType &&
          host == other.host &&
          port == other.port;

  @override
  int get hashCode => host.hashCode ^ port.hashCode;
}

class CastService extends ChangeNotifier {
  static final CastService _instance = CastService._internal();
  static CastService get instance => _instance;

  CastService._internal();

  // ── Local HTTP Streaming Server ──────────────────────────────────────────
  HttpServer? _server;
  int _serverPort = 8989;
  String? _localIp;
  String? _currentCastingPath;
  String? _currentTitle;
  String? _currentArtist;

  // ── Active Cast State ────────────────────────────────────────────────────
  CastDevice? _connectedDevice;
  bool _isDiscovering = false;
  final List<CastDevice> _discoveredDevices = [];
  CastPlaybackState _playbackState = CastPlaybackState.idle;
  double _volume = 1.0;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero; // updated from MEDIA_STATUS

  // ── Google Cast socket state ─────────────────────────────────────────────
  SecureSocket? _castSocket;
  StreamSubscription? _castSocketSub;
  Timer? _heartbeatTimer;
  final List<int> _receiveBuffer = [];
  int _requestId = 1;
  String? _castTransportId;
  String? _castSessionId;
  int? _mediaSessionId; // real session ID received from MEDIA_STATUS

  // ── DLNA ─────────────────────────────────────────────────────────────────
  String? _dlnaControlUrl;

  // ── Phone audio callbacks & event handlers ──────────────────────────────────
  Future<void> Function()? _onPausePhone;
  Future<void> Function(Duration lastPosition)? _onResumePhone;
  VoidCallback? _onTrackEnded;
  Timer? _positionTimer;
  int _pollCounter = 0;

  set onTrackEnded(VoidCallback? callback) {
    _onTrackEnded = callback;
  }

  // ── Getters ──────────────────────────────────────────────────────────────
  bool get isConnected => _connectedDevice != null;
  bool get isCasting => isConnected && _playbackState != CastPlaybackState.idle;
  CastDevice? get connectedDevice => _connectedDevice;
  String? get connectedDeviceName => _connectedDevice?.name;
  List<CastDevice> get discoveredDevices => List.unmodifiable(_discoveredDevices);
  bool get isDiscovering => _isDiscovering;
  CastPlaybackState get playbackState => _playbackState;
  bool get isCastPlaying => _playbackState == CastPlaybackState.playing;
  double get volume => _volume;
  Duration get position => _position;
  Duration get duration => _duration;
  String? get localIp => _localIp;
  int get serverPort => _serverPort;
  String? get currentTitle => _currentTitle;
  String? get currentArtist => _currentArtist;

  /// HTTP stream URL with the correct file extension for the current track.
  String? get streamUrl {
    if (_localIp == null || _server == null) return null;
    final ext = _currentCastingPath?.split('.').last.toLowerCase() ?? 'mp3';
    return 'http://$_localIp:$_serverPort/stream.$ext';
  }

  /// MIME content type derived from the current casting file's extension.
  String get _streamContentType {
    final ext = _currentCastingPath?.split('.').last.toLowerCase() ?? 'mp3';
    switch (ext) {
      case 'm4a':
      case 'aac': return 'audio/aac';
      case 'wav': return 'audio/wav';
      case 'flac': return 'audio/flac';
      case 'ogg':
      case 'opus': return 'audio/ogg';
      default: return 'audio/mpeg';
    }
  }

  // ── Public API ────────────────────────────────────────────────────────────

  void setPhonePlayerCallbacks({
    Future<void> Function()? onPause,
    Future<void> Function(Duration lastPosition)? onResume,
  }) {
    _onPausePhone = onPause;
    _onResumePhone = onResume;
  }

  Future<void> init() async {
    await _resolveLocalIp();
  }

  Future<void> _resolveLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback && !addr.address.startsWith('127.')) {
            _localIp = addr.address;
            break;
          }
        }
        if (_localIp != null) break;
      }
    } catch (e) {
      debugPrint('Error resolving local IP: $e');
    }
  }

  Future<bool> startStreamServer(String filePath, {String? title, String? artist}) async {
    _currentCastingPath = filePath;
    _currentTitle = title ?? filePath.split(Platform.pathSeparator).last;
    _currentArtist = artist ?? 'Local Audio';
    await _resolveLocalIp();

    if (_server != null) {
      notifyListeners();
      return true;
    }

    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, _serverPort, shared: true);
    } catch (e) {
      try {
        _server = await HttpServer.bind(InternetAddress.anyIPv4, 0, shared: true);
        _serverPort = _server!.port;
      } catch (err) {
        debugPrint('Failed to start stream server: $err');
        return false;
      }
    }

    _server!.listen(_handleHttpRequest);
    debugPrint('Stream server running at $streamUrl');
    notifyListeners();
    return true;
  }

  void _handleHttpRequest(HttpRequest request) async {
    request.response.headers.add('Access-Control-Allow-Origin', '*');
    request.response.headers.add('Access-Control-Allow-Headers', 'Range, Content-Type');
    request.response.headers.add('Accept-Ranges', 'bytes');

    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.ok;
      await request.response.close();
      return;
    }

    if (_currentCastingPath == null) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }

    final file = File(_currentCastingPath!);
    if (!file.existsSync()) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }

    final totalLength = file.lengthSync();
    final ext = file.path.split('.').last.toLowerCase();
    String contentType = 'audio/mpeg';
    if (ext == 'm4a' || ext == 'aac') contentType = 'audio/mp4';
    if (ext == 'wav') contentType = 'audio/wav';
    if (ext == 'flac') contentType = 'audio/flac';
    if (ext == 'ogg' || ext == 'opus') contentType = 'audio/ogg';

    request.response.headers.contentType = ContentType.parse(contentType);

    final rangeHeader = request.headers.value('range');
    if (rangeHeader != null && rangeHeader.startsWith('bytes=')) {
      final range = rangeHeader.substring(6).split('-');
      int start = int.tryParse(range[0]) ?? 0;
      int end = (range.length > 1 && range[1].isNotEmpty)
          ? (int.tryParse(range[1]) ?? totalLength - 1)
          : totalLength - 1;
      if (start >= totalLength) {
        request.response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
        await request.response.close();
        return;
      }
      if (end >= totalLength) end = totalLength - 1;
      request.response.statusCode = HttpStatus.partialContent;
      request.response.headers
          .set(HttpHeaders.contentRangeHeader, 'bytes $start-$end/$totalLength');
      request.response.headers.contentLength = end - start + 1;
      try {
        await request.response.addStream(file.openRead(start, end + 1));
      } catch (e) {
        debugPrint('Stream interrupted: $e');
      } finally {
        await request.response.close();
      }
    } else {
      request.response.statusCode = HttpStatus.ok;
      request.response.headers.contentLength = totalLength;
      try {
        await request.response.addStream(file.openRead());
      } catch (e) {
        debugPrint('Stream error: $e');
      } finally {
        await request.response.close();
      }
    }
  }

  Future<void> stopStreamServer() async {
    if (_server != null) {
      await _server!.close(force: true);
      _server = null;
    }
    _currentCastingPath = null;
    notifyListeners();
  }

  Future<void> startDiscovery({Duration timeout = const Duration(seconds: 4)}) async {
    if (_isDiscovering) return;
    _isDiscovering = true;
    _discoveredDevices.clear();
    notifyListeners();

    final Set<CastDevice> found = {};

    try {
      final MDnsClient client = MDnsClient();
      await client.start();
      const String name = '_googlecast._tcp.local';
      await for (final PtrResourceRecord ptr in client
          .lookup<PtrResourceRecord>(ResourceRecordQuery.serverPointer(name))
          .timeout(timeout, onTimeout: (sink) => sink.close())) {
        await for (final SrvResourceRecord srv
            in client.lookup<SrvResourceRecord>(ResourceRecordQuery.service(ptr.domainName))) {
          await for (final IPAddressResourceRecord ip in client
              .lookup<IPAddressResourceRecord>(ResourceRecordQuery.addressIPv4(srv.target))) {
            String deviceName = srv.target.replaceAll('.local', '');
            await for (final TxtResourceRecord txt in client
                .lookup<TxtResourceRecord>(ResourceRecordQuery.text(ptr.domainName))) {
              for (final entry in txt.text.split('\n')) {
                if (entry.startsWith('fn=')) {
                  deviceName = entry.substring(3);
                  break;
                }
              }
            }
            found.add(CastDevice(name: deviceName, host: ip.address.address, port: srv.port, type: 'chromecast'));
          }
        }
      }
      client.stop();
    } catch (e) {
      debugPrint('mDNS error: $e');
    }

    try {
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;
      const ssdpMsg = 'M-SEARCH * HTTP/1.1\r\nHOST: 239.255.255.250:1900\r\n'
          'MAN: "ssdp:discover"\r\nMX: 2\r\n'
          'ST: urn:schemas-upnp-org:device:MediaRenderer:1\r\n\r\n';
      socket.send(utf8.encode(ssdpMsg), InternetAddress('239.255.255.250'), 1900);
      socket.listen((event) {
        if (event == RawSocketEvent.read) {
          final dg = socket.receive();
          if (dg != null) {
            final text = utf8.decode(dg.data, allowMalformed: true);
            if (text.contains('200 OK') || text.contains('NOTIFY')) {
              found.add(CastDevice(
                name: 'Smart Device (${dg.address.address})',
                host: dg.address.address,
                port: dg.port,
                type: 'smart_tv',
              ));
            }
          }
        }
      });
      await Future.delayed(const Duration(milliseconds: 1500));
      socket.close();
    } catch (e) {
      debugPrint('SSDP error: $e');
    }

    _discoveredDevices.clear();
    _discoveredDevices.addAll(found);
    _isDiscovering = false;
    notifyListeners();
  }

  Future<bool> connectToDevice(CastDevice device) async {
    _connectedDevice = device;
    _dlnaControlUrl = null;
    _castTransportId = null;
    _castSessionId = null;

    if (device.type == 'smart_tv' || device.type == 'dlna') {
      _dlnaControlUrl = await _resolveDlnaControlUrl(device);
      debugPrint('DLNA control URL: $_dlnaControlUrl');
    }

    if (device.type == 'chromecast') {
      await _openCastSocket(device);
    }

    _playbackState = CastPlaybackState.playing;
    notifyListeners();
    return true;
  }

  Future<bool> castTrack(
    String filePath, {
    String? title,
    String? artist,
    Duration? duration,
    Duration startPosition = Duration.zero,
  }) async {
    if (_onPausePhone != null) {
      await _onPausePhone!();
      debugPrint('CastService: paused phone audio');
    }

    _position = startPosition;
    if (duration != null && duration > Duration.zero) {
      _duration = duration;
    }

    final serverOk = await startStreamServer(filePath, title: title, artist: artist);
    if (!serverOk || streamUrl == null) return false;

    final url = streamUrl!;
    final trackTitle = title ?? filePath.split(Platform.pathSeparator).last;
    final trackArtist = artist ?? 'Local Audio';

    if (_connectedDevice?.type == 'chromecast') {
      await _chromeCastLoad(url, trackTitle, trackArtist, startSeconds: startPosition.inSeconds.toDouble());
    } else if (_connectedDevice?.type == 'smart_tv' || _connectedDevice?.type == 'dlna') {
      await _dlnaSendPlay(url, trackTitle, trackArtist);
      if (startPosition > Duration.zero) {
        await Future.delayed(const Duration(milliseconds: 500));
        _dlnaSeek(startPosition);
      }
    }

    _playbackState = CastPlaybackState.playing;
    _startPositionTimer();
    notifyListeners();
    return true;
  }

  void play() {
    if (_connectedDevice?.type == 'chromecast') {
      _chromeCastControl('PLAY');
    } else if (_dlnaControlUrl != null) {
      _dlnaControl('Play');
    }
    _playbackState = CastPlaybackState.playing;
    _startPositionTimer();
    notifyListeners();
  }

  void pause() {
    if (_connectedDevice?.type == 'chromecast') {
      _chromeCastControl('PAUSE');
    } else if (_dlnaControlUrl != null) {
      _dlnaControl('Pause');
    }
    _playbackState = CastPlaybackState.paused;
    _stopPositionTimer();
    notifyListeners();
  }

  void seek(Duration pos) {
    _position = pos;
    if (_connectedDevice?.type == 'chromecast') {
      _chromeCastSeek(pos.inSeconds.toDouble());
    } else if (_dlnaControlUrl != null) {
      _dlnaSeek(pos);
    }
    notifyListeners();
  }

  void setVolume(double vol) {
    _volume = vol.clamp(0.0, 1.0);
    // Send to Chromecast receiver
    if (_connectedDevice?.type == 'chromecast' && _castSocket != null) {
      _chromeCastSend('sender-0', 'receiver-0', _ccReceiverNs, {
        'type': 'SET_VOLUME',
        'requestId': _requestId++,
        'volume': {'level': _volume, 'muted': false},
      });
    }
    notifyListeners();
  }

  void _startPositionTimer() {
    _positionTimer?.cancel();
    _pollCounter = 0;
    _positionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_playbackState == CastPlaybackState.playing) {
        _position += const Duration(seconds: 1);
        if (_duration > Duration.zero && _position >= _duration) {
          _position = _duration;
          _stopPositionTimer();
          _playbackState = CastPlaybackState.idle;
          notifyListeners();
          _onTrackEnded?.call();
          return;
        }
        notifyListeners();

        _pollCounter++;
        if (_pollCounter >= 5) {
          _pollCounter = 0;
          _pollCastStatus();
        }
      } else {
        _stopPositionTimer();
      }
    });
  }

  void _stopPositionTimer() {
    _positionTimer?.cancel();
    _positionTimer = null;
  }

  void _pollCastStatus() {
    if (_connectedDevice?.type == 'chromecast' &&
        _castSocket != null &&
        _castTransportId != null) {
      _chromeCastSend('sender-0', _castTransportId!, _ccMediaNs, {
        'type': 'GET_STATUS',
        'requestId': _requestId++,
        'mediaSessionId': _mediaSessionId ?? 1,
      });
    }
  }

  Future<void> disconnect() async {
    _stopPositionTimer();
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;

    if (_connectedDevice?.type == 'chromecast' && _castSocket != null) {
      try {
        // Send STOP command to media session
        if (_castTransportId != null) {
          _chromeCastSend('sender-0', _castTransportId!, _ccMediaNs, {
            'type': 'STOP',
            'requestId': _requestId++,
            'mediaSessionId': _mediaSessionId ?? 1,
          });
        }

        // Send STOP command to receiver app to stop Default Media Receiver
        if (_castSessionId != null) {
          _chromeCastSend('sender-0', 'receiver-0', _ccReceiverNs, {
            'type': 'STOP',
            'requestId': _requestId++,
            'sessionId': _castSessionId,
          });
        }

        // Close connection channels
        if (_castTransportId != null) {
          _chromeCastSend('sender-0', _castTransportId!, _ccConnectNs, {'type': 'CLOSE'});
        }
        _chromeCastSend('sender-0', 'receiver-0', _ccConnectNs, {'type': 'CLOSE'});

        await Future.delayed(const Duration(milliseconds: 250));
      } catch (e) {
        debugPrint('Error sending stop during disconnect: $e');
      }
    } else if (_dlnaControlUrl != null) {
      await _dlnaControl('Stop');
    }

    await _castSocketSub?.cancel();
    _castSocketSub = null;
    try {
      await _castSocket?.close();
    } catch (_) {}
    _castSocket = null;

    final lastPos = _position;

    _connectedDevice = null;
    _dlnaControlUrl = null;
    _castTransportId = null;
    _castSessionId = null;
    _mediaSessionId = null;
    _playbackState = CastPlaybackState.idle;
    _receiveBuffer.clear();

    await stopStreamServer();

    if (_onResumePhone != null) {
      await _onResumePhone!(lastPos);
      debugPrint('CastService: resumed phone audio at $lastPos after disconnect');
    }

    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  Google Cast v2 Protocol
  //  Docs: https://developers.google.com/cast/docs/reference/messages
  //
  //  Transport: TLS SecureSocket on port 8009 (self-signed cert accepted)
  //  Framing  : 4-byte big-endian length prefix + protobuf CastMessage
  // ═══════════════════════════════════════════════════════════════════════════

  static const _ccConnectNs   = 'urn:x-cast:com.google.cast.tp.connection';
  static const _ccHeartbeatNs = 'urn:x-cast:com.google.cast.tp.heartbeat';
  static const _ccReceiverNs  = 'urn:x-cast:com.google.cast.receiver';
  static const _ccMediaNs     = 'urn:x-cast:com.google.cast.media';

  Future<void> _openCastSocket(CastDevice device) async {
    try {
      _receiveBuffer.clear();
      _requestId = 1;
      _castTransportId = null;
      _castSessionId = null;
      _mediaSessionId = null;

      _castSocket = await SecureSocket.connect(
        device.host,
        8009,
        onBadCertificate: (_) => true,
        timeout: const Duration(seconds: 8),
      );

      _castSocketSub = _castSocket!.listen(
        _onCastData,
        onError: (e) => debugPrint('Cast socket error: $e'),
        onDone: () => debugPrint('Cast socket closed'),
        cancelOnError: false,
      );

      _heartbeatTimer?.cancel();
      _heartbeatTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        _chromeCastSend('sender-0', 'receiver-0', _ccHeartbeatNs, {'type': 'PING'});
      });

      // CONNECT to the receiver — no extra fields beyond type+origin for
      // maximum compatibility with Google Home / Nest devices.
      _chromeCastSend('sender-0', 'receiver-0', _ccConnectNs, {
        'type': 'CONNECT',
        'origin': {},
      });

      // Give the device 400 ms to ACK the CONNECT before we send LAUNCH.
      await Future.delayed(const Duration(milliseconds: 400));

      // Ask for current receiver status (warms up the channel).
      _chromeCastSend('sender-0', 'receiver-0', _ccReceiverNs, {
        'type': 'GET_STATUS',
        'requestId': _requestId++,
      });

      debugPrint('Cast: socket open to ${device.host}:8009');
    } catch (e) {
      debugPrint('Cast: failed to open socket: $e');
    }
  }

  void _onCastData(List<int> data) {
    _receiveBuffer.addAll(data);
    _parseCastMessages();
  }

  void _parseCastMessages() {
    while (_receiveBuffer.length >= 4) {
      final len = (_receiveBuffer[0] << 24) |
          (_receiveBuffer[1] << 16) |
          (_receiveBuffer[2] << 8) |
          _receiveBuffer[3];

      if (_receiveBuffer.length < 4 + len) break;

      final msgBytes = _receiveBuffer.sublist(4, 4 + len);
      _receiveBuffer.removeRange(0, 4 + len);

      try {
        final payload = _decodeCastPayload(msgBytes);
        if (payload == null) continue;

        final json = jsonDecode(payload) as Map<String, dynamic>;
        final type = json['type'] as String?;

        debugPrint('Cast RX: type=$type');

        if (type == 'PING') {
          _chromeCastSend('sender-0', 'receiver-0', _ccHeartbeatNs, {'type': 'PONG'});
        } else if (type == 'RECEIVER_STATUS') {
          _handleReceiverStatus(json);
        } else if (type == 'MEDIA_STATUS') {
          _handleMediaStatus(json);
        } else if (type == 'LAUNCH_ERROR') {
          debugPrint('Cast LAUNCH_ERROR: ${json["reason"]} — ${json["description"]}');
        } else if (type == 'LOAD_FAILED') {
          debugPrint('Cast LOAD_FAILED: detailedErrorCode=${json["detailedErrorCode"]}');
        } else if (type == 'INVALID_REQUEST') {
          debugPrint('Cast INVALID_REQUEST: reason=${json["reason"]}');
        }
      } catch (e) {
        debugPrint('Cast parse error: $e');
      }
    }
  }

  void _handleReceiverStatus(Map<String, dynamic> json) {
    final status = json['status'] as Map<String, dynamic>?;
    final apps = status?['applications'] as List<dynamic>?;

    if (apps != null && apps.isNotEmpty) {
      final app = apps.first as Map<String, dynamic>;
      final newTransport = app['transportId'] as String?;
      final newSession   = app['sessionId']   as String?;

      if (newTransport != null && newTransport != _castTransportId) {
        _castTransportId = newTransport;
        _castSessionId   = newSession;
        debugPrint('Cast: app running — transportId=$_castTransportId');

        // Connect to the media-session transport channel.
        _chromeCastSend('sender-0', _castTransportId!, _ccConnectNs, {
          'type': 'CONNECT',
          'origin': {},
        });
      }
    } else {
      // No apps running — receiver is idle.
      debugPrint('Cast: receiver is idle (no running app)');
    }
  }

  void _handleMediaStatus(Map<String, dynamic> json) {
    final statuses = json['status'] as List<dynamic>?;
    if (statuses != null && statuses.isNotEmpty) {
      final s = statuses.first as Map<String, dynamic>;

      // Track the real media session ID for subsequent PLAY/PAUSE/SEEK/STOP.
      final msid = s['mediaSessionId'];
      if (msid != null) _mediaSessionId = (msid as num).toInt();

      // Parse duration from media info
      final mediaInfo = s['media'] as Map<String, dynamic>?;
      final dur = mediaInfo?['duration'];
      if (dur != null) {
        _duration = Duration(milliseconds: ((dur as num) * 1000).round());
      }

      final playerState = s['playerState'] as String?;
      if (playerState == 'PLAYING') {
        _playbackState = CastPlaybackState.playing;
        if (_positionTimer == null || !_positionTimer!.isActive) {
          _startPositionTimer();
        }
      } else if (playerState == 'PAUSED') {
        _playbackState = CastPlaybackState.paused;
        _stopPositionTimer();
      } else if (playerState == 'BUFFERING') {
        _playbackState = CastPlaybackState.buffering;
      } else if (playerState == 'IDLE') {
        _stopPositionTimer();
        final idleReason = s['idleReason'] as String?;
        debugPrint('Cast IDLE reason: $idleReason');
        if (idleReason == 'FINISHED') {
          _playbackState = CastPlaybackState.idle;
          _onTrackEnded?.call();
        } else if (idleReason == 'ERROR') {
          _playbackState = CastPlaybackState.idle;
        }
      }

      final currentTime = s['currentTime'];
      if (currentTime != null) {
        _position =
            Duration(milliseconds: ((currentTime as num) * 1000).round());
      }
      notifyListeners();
    }
  }

  Future<void> _chromeCastLoad(String url, String title, String artist, {double startSeconds = 0.0}) async {
    if (_castSocket == null) {
      if (_connectedDevice != null) {
        await _openCastSocket(_connectedDevice!);
        // Wait for CONNECT + GET_STATUS round-trip.
        await Future.delayed(const Duration(seconds: 2));
      }
      if (_castSocket == null) {
        debugPrint('Cast: no socket, cannot LOAD');
        return;
      }
    }

    // Launch the Default Media Receiver (appId CC1AD845).
    // Google Home Mini / Nest speakers all support this receiver.
    final launchReqId = _requestId++;
    _chromeCastSend('sender-0', 'receiver-0', _ccReceiverNs, {
      'type': 'LAUNCH',
      'appId': 'CC1AD845',
      'requestId': launchReqId,
    });

    debugPrint('Cast: LAUNCH sent (reqId=$launchReqId), waiting for transportId...');

    // Wait up to 15 seconds for the receiver app to start.
    // Google Home Mini can be slower than Chromecast dongle.
    for (int i = 0; i < 75; i++) {
      await Future.delayed(const Duration(milliseconds: 200));
      if (_castTransportId != null) break;
    }

    if (_castTransportId == null) {
      debugPrint('Cast: timeout — Default Media Receiver did not launch');
      return;
    }

    // Give the transport CONNECT time to be processed on the device side.
    await Future.delayed(const Duration(milliseconds: 600));

    // Determine the correct MIME type from the actual file extension
    // so Google Home Mini's strict media pipeline accepts it.
    final contentType = _streamContentType;

    _chromeCastSend('sender-0', _castTransportId!, _ccMediaNs, {
      'type': 'LOAD',
      'requestId': _requestId++,
      'sessionId': _castSessionId,
      'media': {
        'contentId': url,
        // Use the URL as contentUrl as well (some Cast v3 receivers need this)
        'contentUrl': url,
        'contentType': contentType,
        // LIVE = HTTP streaming; BUFFERED = local file with known length.
        'streamType': 'BUFFERED',
        'metadata': {
          'metadataType': 3, // MusicTrackMediaMetadata
          'title': title,
          'artist': artist,
          'albumName': '',
          'images': [],
        },
      },
      'autoplay': true,
      'currentTime': startSeconds,
      'playbackRate': 1,
      'customData': {},
      'activeTrackIds': [],
    });

    debugPrint('Cast: LOAD sent → $url  [type=$contentType, startSeconds=$startSeconds]');

    if (startSeconds > 0) {
      await Future.delayed(const Duration(milliseconds: 600));
      _chromeCastSeek(startSeconds);
    }
  }

  void _chromeCastControl(String type) {
    if (_castTransportId == null || _castSocket == null) return;
    _chromeCastSend('sender-0', _castTransportId!, _ccMediaNs, {
      'type': type,
      'requestId': _requestId++,
      // Use the real mediaSessionId if we have it; fall back to 1.
      'mediaSessionId': _mediaSessionId ?? 1,
    });
  }

  void _chromeCastSeek(double seconds) {
    if (_castTransportId == null || _castSocket == null) return;
    _chromeCastSend('sender-0', _castTransportId!, _ccMediaNs, {
      'type': 'SEEK',
      'requestId': _requestId++,
      'mediaSessionId': _mediaSessionId ?? 1,
      'currentTime': seconds,
      'resumeState': 'PLAYBACK_START',
    });
  }

  void _chromeCastSend(
    String sourceId,
    String destinationId,
    String namespace,
    Map<String, dynamic> payload,
  ) {
    if (_castSocket == null) return;
    try {
      final bytes = _encodeCastMessage(
        sourceId: sourceId,
        destinationId: destinationId,
        namespace: namespace,
        payload: jsonEncode(payload),
      );
      _castSocket!.add(bytes);
    } catch (e) {
      debugPrint('Cast send error: $e');
    }
  }

  // ── Protobuf CastMessage encoding/decoding ───────────────────────────────
  //
  //  Fields: 1=protocol_version(varint=0), 2=source_id, 3=destination_id,
  //          4=namespace, 5=payload_type(varint=0), 6=payload_utf8

  Uint8List _encodeCastMessage({
    required String sourceId,
    required String destinationId,
    required String namespace,
    required String payload,
  }) {
    final List<int> msg = [];
    msg.addAll([0x08, 0x00]); // field 1: protocol_version = 0
    _pbWriteString(msg, 2, sourceId);
    _pbWriteString(msg, 3, destinationId);
    _pbWriteString(msg, 4, namespace);
    msg.addAll([0x28, 0x00]); // field 5: payload_type = 0 (STRING)
    _pbWriteString(msg, 6, payload);

    final len = msg.length;
    return Uint8List.fromList([
      (len >> 24) & 0xff,
      (len >> 16) & 0xff,
      (len >> 8) & 0xff,
      len & 0xff,
      ...msg,
    ]);
  }

  void _pbWriteString(List<int> buf, int field, String value) {
    final bytes = utf8.encode(value);
    buf.add((field << 3) | 2); // wire type 2
    buf.addAll(_pbVarint(bytes.length));
    buf.addAll(bytes);
  }

  List<int> _pbVarint(int value) {
    final r = <int>[];
    while (value > 0x7f) {
      r.add((value & 0x7f) | 0x80);
      value >>= 7;
    }
    r.add(value & 0x7f);
    return r;
  }

  String? _decodeCastPayload(List<int> bytes) {
    int i = 0;
    while (i < bytes.length) {
      final tagByte = bytes[i++];
      final wireType = tagByte & 0x07;
      final fieldNum = tagByte >> 3;

      if (wireType == 0) {
        while (i < bytes.length && (bytes[i] & 0x80) != 0) {
          i++;
        }
        i++;
      } else if (wireType == 2) {
        int len = 0, shift = 0;
        while (i < bytes.length) {
          final b = bytes[i++];
          len |= (b & 0x7f) << shift;
          shift += 7;
          if ((b & 0x80) == 0) break;
        }
        if (fieldNum == 6) {
          return utf8.decode(bytes.sublist(i, i + len), allowMalformed: true);
        }
        i += len;
      } else {
        break;
      }
    }
    return null;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  DLNA / UPnP helpers
  // ═══════════════════════════════════════════════════════════════════════════

  Future<String?> _resolveDlnaControlUrl(CastDevice device) async {
    const descPaths = ['/MediaRenderer/desc.xml', '/description.xml', '/device-desc.xml', '/upnp/IGD.xml'];
    const probePorts = [1400, 49152, 49153, 8080, 8060];
    for (final port in probePorts) {
      for (final path in descPaths) {
        try {
          final resp = await http
              .get(Uri.parse('http://${device.host}:$port$path'))
              .timeout(const Duration(seconds: 2));
          if (resp.statusCode == 200 && resp.body.contains('AVTransport')) {
            final body = resp.body;
            final avIdx = body.indexOf('AVTransport');
            if (avIdx == -1) continue;
            final ctrlStart = body.indexOf('<controlURL>', avIdx) + '<controlURL>'.length;
            final ctrlEnd = body.indexOf('</controlURL>', ctrlStart);
            if (ctrlStart > 0 && ctrlEnd > ctrlStart) {
              String relUrl = body.substring(ctrlStart, ctrlEnd);
              if (!relUrl.startsWith('http')) relUrl = 'http://${device.host}:$port$relUrl';
              return relUrl;
            }
          }
        } catch (_) {}
      }
    }
    return null;
  }

  Future<void> _dlnaSendPlay(String url, String title, String artist) async {
    if (_dlnaControlUrl == null) return;
    try {
      final body = '''<?xml version="1.0" encoding="utf-8"?>
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
  <s:Body>
    <u:SetAVTransportURI xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
      <InstanceID>0</InstanceID>
      <CurrentURI>$url</CurrentURI>
      <CurrentURIMetaData>&lt;DIDL-Lite xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/"&gt;&lt;item id="1" parentID="0" restricted="0"&gt;&lt;dc:title&gt;$title&lt;/dc:title&gt;&lt;dc:creator&gt;$artist&lt;/dc:creator&gt;&lt;upnp:class&gt;object.item.audioItem.musicTrack&lt;/upnp:class&gt;&lt;res&gt;$url&lt;/res&gt;&lt;/item&gt;&lt;/DIDL-Lite&gt;</CurrentURIMetaData>
    </u:SetAVTransportURI>
  </s:Body>
</s:Envelope>''';
      await http.post(Uri.parse(_dlnaControlUrl!),
          headers: {'Content-Type': 'text/xml; charset="utf-8"', 'SOAPACTION': '"urn:schemas-upnp-org:service:AVTransport:1#SetAVTransportURI"'},
          body: body).timeout(const Duration(seconds: 5));
      await _dlnaControl('Play');
    } catch (e) {
      debugPrint('DLNA sendPlay error: $e');
    }
  }

  Future<void> _dlnaControl(String action) async {
    if (_dlnaControlUrl == null) return;
    final speed = action == 'Play' ? '<Speed>1</Speed>' : '';
    final body = '''<?xml version="1.0" encoding="utf-8"?>
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
  <s:Body>
    <u:$action xmlns:u="urn:schemas-upnp-org:service:AVTransport:1"><InstanceID>0</InstanceID>$speed</u:$action>
  </s:Body>
</s:Envelope>''';
    try {
      await http.post(Uri.parse(_dlnaControlUrl!),
          headers: {'Content-Type': 'text/xml; charset="utf-8"', 'SOAPACTION': '"urn:schemas-upnp-org:service:AVTransport:1#$action"'},
          body: body).timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('DLNA $action error: $e');
    }
  }

  Future<void> _dlnaSeek(Duration pos) async {
    if (_dlnaControlUrl == null) return;
    final h = pos.inHours.toString().padLeft(2, '0');
    final m = (pos.inMinutes % 60).toString().padLeft(2, '0');
    final s = (pos.inSeconds % 60).toString().padLeft(2, '0');
    final body = '''<?xml version="1.0" encoding="utf-8"?>
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
  <s:Body>
    <u:Seek xmlns:u="urn:schemas-upnp-org:service:AVTransport:1"><InstanceID>0</InstanceID><Unit>REL_TIME</Unit><Target>$h:$m:$s</Target></u:Seek>
  </s:Body>
</s:Envelope>''';
    try {
      await http.post(Uri.parse(_dlnaControlUrl!),
          headers: {'Content-Type': 'text/xml; charset="utf-8"', 'SOAPACTION': '"urn:schemas-upnp-org:service:AVTransport:1#Seek"'},
          body: body).timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('DLNA Seek error: $e');
    }
  }
}
