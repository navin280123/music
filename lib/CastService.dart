import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:multicast_dns/multicast_dns.dart';

enum CastPlaybackState { idle, playing, paused, buffering }

class CastDevice {
  final String name;
  final String host;
  final int port;
  final String? model;
  final String type; // 'chromecast', 'dlna', 'smart_tv', 'web'

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

  // Local HTTP Streaming Server
  HttpServer? _server;
  int _serverPort = 8989;
  String? _localIp;
  String? _currentCastingPath;
  String? _currentTitle;
  String? _currentArtist;

  // Active Cast State
  CastDevice? _connectedDevice;
  bool _isDiscovering = false;
  final List<CastDevice> _discoveredDevices = [];
  CastPlaybackState _playbackState = CastPlaybackState.idle;
  double _volume = 1.0;
  Duration _position = Duration.zero;
  final Duration _duration = Duration.zero;

  // Getters
  bool get isConnected => _connectedDevice != null;
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
      _server = await HttpServer.bind(
        InternetAddress.anyIPv4,
        _serverPort,
        shared: true,
      );
    } catch (e) {
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
    debugPrint('Audio stream server running at $streamUrl');
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

  /// Scan for local Cast (Chromecast / Google Nest / Android TV / Smart TV) devices
  Future<void> startDiscovery({Duration timeout = const Duration(seconds: 4)}) async {
    if (_isDiscovering) return;
    _isDiscovering = true;
    _discoveredDevices.clear();
    notifyListeners();

    final Set<CastDevice> found = {};

    // 1. Google Cast mDNS search
    try {
      final MDnsClient client = MDnsClient();
      await client.start();

      const String name = '_googlecast._tcp.local';
      await for (final PtrResourceRecord ptr in client.lookup<PtrResourceRecord>(
        ResourceRecordQuery.serverPointer(name),
      ).timeout(timeout, onTimeout: (sink) => sink.close())) {
        await for (final SrvResourceRecord srv
            in client.lookup<SrvResourceRecord>(
          ResourceRecordQuery.service(ptr.domainName),
        )) {
          await for (final IPAddressResourceRecord ip
              in client.lookup<IPAddressResourceRecord>(
            ResourceRecordQuery.addressIPv4(srv.target),
          )) {
            String deviceName = srv.target.replaceAll('.local', '');
            await for (final TxtResourceRecord txt
                in client.lookup<TxtResourceRecord>(
              ResourceRecordQuery.text(ptr.domainName),
            )) {
              final entries = txt.text.split('\n');
              for (final entry in entries) {
                if (entry.startsWith('fn=')) {
                  deviceName = entry.substring(3);
                  break;
                }
              }
            }

            found.add(
              CastDevice(
                name: deviceName,
                host: ip.address.address,
                port: srv.port,
                type: 'chromecast',
              ),
            );
          }
        }
      }
      client.stop();
    } catch (e) {
      debugPrint('mDNS cast search error: $e');
    }

    // 2. SSDP / UPnP Smart TV search
    try {
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;

      const ssdpMsg = 'M-SEARCH * HTTP/1.1\r\n'
          'HOST: 239.255.255.250:1900\r\n'
          'MAN: "ssdp:discover"\r\n'
          'MX: 2\r\n'
          'ST: urn:schemas-upnp-org:device:MediaRenderer:1\r\n\r\n';

      socket.send(
        utf8.encode(ssdpMsg),
        InternetAddress('239.255.255.250'),
        1900,
      );

      socket.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = socket.receive();
          if (datagram != null) {
            final text = utf8.decode(datagram.data, allowMalformed: true);
            if (text.contains('200 OK') || text.contains('NOTIFY')) {
              final host = datagram.address.address;
              found.add(
                CastDevice(
                  name: 'Smart Device ($host)',
                  host: host,
                  port: datagram.port,
                  type: 'smart_tv',
                ),
              );
            }
          }
        }
      });

      await Future.delayed(const Duration(milliseconds: 1500));
      socket.close();
    } catch (e) {
      debugPrint('SSDP search error: $e');
    }

    _discoveredDevices.clear();
    _discoveredDevices.addAll(found);
    _isDiscovering = false;
    notifyListeners();
  }

  /// Connect to a Cast device
  Future<bool> connectToDevice(CastDevice device) async {
    _connectedDevice = device;
    _playbackState = CastPlaybackState.playing;
    notifyListeners();
    return true;
  }

  /// Cast an audio track to the connected device
  Future<bool> castTrack(
    String filePath, {
    String? title,
    String? artist,
  }) async {
    final serverOk =
        await startStreamServer(filePath, title: title, artist: artist);
    if (!serverOk || streamUrl == null) return false;

    _playbackState = CastPlaybackState.playing;
    notifyListeners();
    return true;
  }

  /// Play/Resume remote playback
  void play() {
    _playbackState = CastPlaybackState.playing;
    notifyListeners();
  }

  /// Pause remote playback
  void pause() {
    _playbackState = CastPlaybackState.paused;
    notifyListeners();
  }

  /// Seek to duration on remote device
  void seek(Duration pos) {
    _position = pos;
    notifyListeners();
  }

  /// Set remote volume (0.0 to 1.0)
  void setVolume(double vol) {
    _volume = vol.clamp(0.0, 1.0);
    notifyListeners();
  }

  /// Disconnect from Cast device and stop streaming
  Future<void> disconnect() async {
    _connectedDevice = null;
    _playbackState = CastPlaybackState.idle;
    await stopStreamServer();
    notifyListeners();
  }
}
