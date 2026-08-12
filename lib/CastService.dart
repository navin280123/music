import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:cast/cast.dart';
import 'package:flutter/foundation.dart';

enum CastPlaybackState { idle, playing, paused, buffering }

class CastService extends ChangeNotifier {
  static final CastService _instance = CastService._internal();
  static CastService get instance => _instance;

  CastService._internal();

  // Local HTTP Streaming Server
  HttpServer? _server;
  int _serverPort = 8989;
  String? _localIp;
  String? _currentCastingPath;
  String? _currentTitle;
  String? _currentArtist;

  // Cast Device State
  CastDevice? _connectedDevice;
  CastSession? _session;
  StreamSubscription? _sessionStateSub;
  StreamSubscription? _messageSub;
  int? _mediaSessionId;

  bool _isDiscovering = false;
  final List<CastDevice> _discoveredDevices = [];
  CastPlaybackState _playbackState = CastPlaybackState.idle;
  double _volume = 1.0;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  // Getters
  bool get isConnected => _connectedDevice != null && _session != null;
  bool get isCasting => isConnected && _playbackState != CastPlaybackState.idle;
  CastDevice? get connectedDevice => _connectedDevice;
  String? get connectedDeviceName => _connectedDevice?.name;
  List<CastDevice> get discoveredDevices =>
      List.unmodifiable(_discoveredDevices);
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

  /// Returns the HTTP stream URL for remote devices to play
  String? get streamUrl {
    if (_localIp == null || _server == null) return null;
    return 'http://$_localIp:$_serverPort/stream.mp3';
  }

  /// Initialize local networking and resolve local Wi-Fi IP
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

  /// Start the local HTTP audio streaming server
  Future<bool> startStreamServer(String filePath,
      {String? title, String? artist}) async {
    _currentCastingPath = filePath;
    _currentTitle = title ?? filePath.split(Platform.pathSeparator).last;
    _currentArtist = artist ?? 'Local Audio';

    await _resolveLocalIp();

    if (_server != null) {
      notifyListeners();
      return true;
    }

    try {
      // Bind to an available port
      _server = await HttpServer.bind(
        InternetAddress.anyIPv4,
        _serverPort,
        shared: true,
      );
    } catch (e) {
      // If 8989 is busy, bind to an ephemeral port
      try {
        _server = await HttpServer.bind(
          InternetAddress.anyIPv4,
          0,
          shared: true,
        );
        _serverPort = _server!.port;
      } catch (err) {
        debugPrint('Failed to start stream server: $err');
        return false;
      }
    }

    _server!.listen(_handleHttpRequest);
    debugPrint('Audio stream server started at $streamUrl');
    notifyListeners();
    return true;
  }

  /// HTTP request handler supporting partial byte range requests (HTTP 206)
  void _handleHttpRequest(HttpRequest request) async {
    request.response.headers.add('Access-Control-Allow-Origin', '*');
    request.response.headers
        .add('Access-Control-Allow-Headers', 'Range, Content-Type');
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

      if (end >= totalLength) {
        end = totalLength - 1;
      }

      final contentLength = end - start + 1;
      request.response.statusCode = HttpStatus.partialContent;
      request.response.headers
          .set(HttpHeaders.contentRangeHeader, 'bytes $start-$end/$totalLength');
      request.response.headers.contentLength = contentLength;

      try {
        final stream = file.openRead(start, end + 1);
        await request.response.addStream(stream);
      } catch (e) {
        debugPrint('Stream interrupted: $e');
      } finally {
        await request.response.close();
      }
    } else {
      // Full content
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

  /// Stop the local stream server
  Future<void> stopStreamServer() async {
    if (_server != null) {
      await _server!.close(force: true);
      _server = null;
    }
    _currentCastingPath = null;
    notifyListeners();
  }

  /// Scan for local Cast (Chromecast / Google Nest / Android TV) devices
  Future<void> startDiscovery({Duration timeout = const Duration(seconds: 4)}) async {
    if (_isDiscovering) return;
    _isDiscovering = true;
    _discoveredDevices.clear();
    notifyListeners();

    try {
      final devices = await CastDiscoveryService().search(timeout: timeout);
      _discoveredDevices.clear();
      _discoveredDevices.addAll(devices);
    } catch (e) {
      debugPrint('Error discovering Cast devices: $e');
    } finally {
      _isDiscovering = false;
      notifyListeners();
    }
  }

  /// Connect to a Cast device and launch media receiver
  Future<bool> connectToDevice(CastDevice device) async {
    await disconnect();

    try {
      _connectedDevice = device;
      notifyListeners();

      final session = await CastSessionManager().startSession(
        device,
        const Duration(seconds: 10),
      );
      _session = session;

      _sessionStateSub = session.stateStream.listen((state) {
        if (state == CastSessionState.closed) {
          disconnect();
        }
      });

      _messageSub = session.messageStream.listen(_handleCastMessage);

      // Launch default media receiver app
      session.sendMessage(CastSession.kNamespaceReceiver, {
        'type': 'LAUNCH',
        'appId': 'CC1AD845', // Default Media Receiver
        'requestId': Random().nextInt(99999),
      });

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Failed to connect to Cast device: $e');
      await disconnect();
      return false;
    }
  }

  /// Handle incoming status messages from the Chromecast / receiver
  void _handleCastMessage(Map<String, dynamic> msg) {
    final type = msg['type'] as String?;
    if (type == 'MEDIA_STATUS') {
      final statuses = msg['status'] as List<dynamic>?;
      if (statuses != null && statuses.isNotEmpty) {
        final status = statuses[0] as Map<String, dynamic>;
        _mediaSessionId = status['mediaSessionId'] as int?;
        final stateStr = status['playerState'] as String?;

        if (stateStr == 'PLAYING') {
          _playbackState = CastPlaybackState.playing;
        } else if (stateStr == 'PAUSED') {
          _playbackState = CastPlaybackState.paused;
        } else if (stateStr == 'BUFFERING') {
          _playbackState = CastPlaybackState.buffering;
        } else if (stateStr == 'IDLE') {
          _playbackState = CastPlaybackState.idle;
        }

        final currTime = status['currentTime'] as num?;
        if (currTime != null) {
          _position = Duration(seconds: currTime.toInt());
        }

        final mediaMap = status['media'] as Map<String, dynamic>?;
        if (mediaMap != null && mediaMap['duration'] != null) {
          _duration = Duration(seconds: (mediaMap['duration'] as num).toInt());
        }

        final volumeMap = status['volume'] as Map<String, dynamic>?;
        if (volumeMap != null && volumeMap['level'] != null) {
          _volume = (volumeMap['level'] as num).toDouble();
        }

        notifyListeners();
      }
    }
  }

  /// Cast an audio track to the connected device
  Future<bool> castTrack(
    String filePath, {
    String? title,
    String? artist,
    String? albumArtUrl,
  }) async {
    final serverOk =
        await startStreamServer(filePath, title: title, artist: artist);
    if (!serverOk || streamUrl == null) return false;

    if (_session == null) return true; // Stream server running for direct URL

    try {
      final trackTitle = title ?? filePath.split(Platform.pathSeparator).last;
      final trackArtist = artist ?? 'Pocketo Play';

      _session!.sendMessage(CastSession.kNamespaceMedia, {
        'type': 'LOAD',
        'requestId': Random().nextInt(99999),
        'media': {
          'contentId': streamUrl,
          'streamType': 'BUFFERED',
          'contentType': 'audio/mp3',
          'metadata': {
            'metadataType': 3, // Music Track
            'title': trackTitle,
            'artist': trackArtist,
          },
        },
        'autoplay': true,
        'currentTime': 0,
      });

      _playbackState = CastPlaybackState.playing;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error casting track to device: $e');
      return false;
    }
  }

  /// Play/Resume remote playback
  void play() {
    if (_session == null || _mediaSessionId == null) return;
    _session!.sendMessage(CastSession.kNamespaceMedia, {
      'type': 'PLAY',
      'requestId': Random().nextInt(99999),
      'mediaSessionId': _mediaSessionId,
    });
    _playbackState = CastPlaybackState.playing;
    notifyListeners();
  }

  /// Pause remote playback
  void pause() {
    if (_session == null || _mediaSessionId == null) return;
    _session!.sendMessage(CastSession.kNamespaceMedia, {
      'type': 'PAUSE',
      'requestId': Random().nextInt(99999),
      'mediaSessionId': _mediaSessionId,
    });
    _playbackState = CastPlaybackState.paused;
    notifyListeners();
  }

  /// Seek to duration on remote device
  void seek(Duration pos) {
    if (_session == null || _mediaSessionId == null) return;
    _session!.sendMessage(CastSession.kNamespaceMedia, {
      'type': 'SEEK',
      'requestId': Random().nextInt(99999),
      'mediaSessionId': _mediaSessionId,
      'currentTime': pos.inSeconds,
    });
    _position = pos;
    notifyListeners();
  }

  /// Set remote volume (0.0 to 1.0)
  void setVolume(double vol) {
    _volume = vol.clamp(0.0, 1.0);
    if (_session != null) {
      _session!.sendMessage(CastSession.kNamespaceReceiver, {
        'type': 'SET_VOLUME',
        'requestId': Random().nextInt(99999),
        'volume': {'level': _volume},
      });
    }
    notifyListeners();
  }

  /// Disconnect from Cast device and stop streaming
  Future<void> disconnect() async {
    _sessionStateSub?.cancel();
    _messageSub?.cancel();
    _sessionStateSub = null;
    _messageSub = null;

    if (_session != null) {
      try {
        await CastSessionManager().endSession(_session!.sessionId);
      } catch (_) {}
      _session = null;
    }

    _connectedDevice = null;
    _mediaSessionId = null;
    _playbackState = CastPlaybackState.idle;
    await stopStreamServer();
    notifyListeners();
  }
}
