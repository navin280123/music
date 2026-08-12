import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CachedTrack {
  final String path;
  final String title;
  final String artist;
  final String album;
  final int? durationMs;
  final int fileSizeBytes;
  final int lastModifiedMs;
  final bool isVoiceMessage;

  CachedTrack({
    required this.path,
    required this.title,
    required this.artist,
    required this.album,
    this.durationMs,
    required this.fileSizeBytes,
    required this.lastModifiedMs,
    required this.isVoiceMessage,
  });

  Map<String, dynamic> toMap() {
    return {
      'path': path,
      'title': title,
      'artist': artist,
      'album': album,
      'durationMs': durationMs,
      'fileSizeBytes': fileSizeBytes,
      'lastModifiedMs': lastModifiedMs,
      'isVoiceMessage': isVoiceMessage,
    };
  }

  factory CachedTrack.fromMap(Map<String, dynamic> map) {
    return CachedTrack(
      path: map['path'] as String? ?? '',
      title: map['title'] as String? ?? '',
      artist: map['artist'] as String? ?? '',
      album: map['album'] as String? ?? '',
      durationMs: map['durationMs'] as int?,
      fileSizeBytes: map['fileSizeBytes'] as int? ?? 0,
      lastModifiedMs: map['lastModifiedMs'] as int? ?? 0,
      isVoiceMessage: map['isVoiceMessage'] as bool? ?? false,
    );
  }

  String toJson() => jsonEncode(toMap());
  factory CachedTrack.fromJson(String source) =>
      CachedTrack.fromMap(jsonDecode(source) as Map<String, dynamic>);
}

class MediaCacheService extends ChangeNotifier {
  static final MediaCacheService _instance = MediaCacheService._internal();
  static MediaCacheService get instance => _instance;

  MediaCacheService._internal();

  static const String _keyCachedTracks = 'pocketo_cached_tracks_v2';
  static const String _keyLastScanTime = 'pocketo_last_scan_timestamp';

  final List<CachedTrack> _cachedTracks = [];
  bool _isInitialized = false;
  DateTime? _lastScanTime;

  List<CachedTrack> get cachedTracks => List.unmodifiable(_cachedTracks);
  bool get isInitialized => _isInitialized;
  DateTime? get lastScanTime => _lastScanTime;

  /// Total cached tracks count
  int get totalCount => _cachedTracks.length;

  /// Count of tracks identified as voice messages/recordings
  int get voiceMessagesCount =>
      _cachedTracks.where((t) => t.isVoiceMessage).length;

  /// Count of regular music tracks
  int get musicTracksCount =>
      _cachedTracks.where((t) => !t.isVoiceMessage).length;

  /// Initialize and load cached metadata from SharedPreferences
  Future<void> init() async {
    if (_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final tracksJson = prefs.getString(_keyCachedTracks);
      final lastScanMillis = prefs.getInt(_keyLastScanTime);

      if (lastScanMillis != null) {
        _lastScanTime = DateTime.fromMillisecondsSinceEpoch(lastScanMillis);
      }

      if (tracksJson != null && tracksJson.isNotEmpty) {
        final List<dynamic> list = jsonDecode(tracksJson) as List<dynamic>;
        _cachedTracks.clear();
        for (final item in list) {
          if (item is Map<String, dynamic>) {
            _cachedTracks.add(CachedTrack.fromMap(item));
          }
        }
      }
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing MediaCacheService: $e');
      _isInitialized = true;
    }
  }

  /// Get file paths based on voice message inclusion setting
  List<String> getFilePaths({required bool includeVoiceMessages}) {
    if (includeVoiceMessages) {
      return _cachedTracks.map((t) => t.path).toList();
    }
    return _cachedTracks
        .where((t) => !t.isVoiceMessage)
        .map((t) => t.path)
        .toList();
  }

  /// Check if a given file path is detected as a voice message/recording
  static bool isVoiceNotePath(String filePath) {
    final lowerPath = filePath.toLowerCase();
    final fileName = filePath.split(Platform.pathSeparator).last.toLowerCase();

    // 1. Check directory path patterns (WhatsApp, Telegram, Call Recorders, Voice Memos)
    if (lowerPath.contains('whatsapp/media/whatsapp voice notes') ||
        lowerPath.contains('whatsapp voice notes') ||
        lowerPath.contains('whatsapp audio/private') ||
        lowerPath.contains('whatsapp business/media/whatsapp voice notes') ||
        lowerPath.contains('telegram/telegram audio') ||
        lowerPath.contains('recordings') ||
        lowerPath.contains('voice recorder') ||
        lowerPath.contains('voice_recorder') ||
        lowerPath.contains('voicememos') ||
        lowerPath.contains('voice memos') ||
        lowerPath.contains('sound_recorder') ||
        lowerPath.contains('call_recordings') ||
        lowerPath.contains('call recordings') ||
        lowerPath.contains('callrecording') ||
        lowerPath.contains('com.facebook.orca') ||
        lowerPath.contains('.statuses')) {
      return true;
    }

    // 2. Check filename prefixes and patterns
    if (fileName.startsWith('ptt-') || // Push to talk (WhatsApp / Telegram)
        fileName.startsWith('aud-') || // WhatsApp audio
        fileName.startsWith('voice-') ||
        fileName.startsWith('voice_') ||
        fileName.startsWith('rec_') ||
        fileName.startsWith('recording_') ||
        fileName.startsWith('call_') ||
        fileName.startsWith('audio_record_') ||
        fileName.startsWith('voicenote_')) {
      return true;
    }

    // 3. Check for .opus files outside main Music directories
    if (fileName.endsWith('.opus') &&
        !lowerPath.contains('/music') &&
        !lowerPath.contains('/download')) {
      return true;
    }

    return false;
  }

  /// Create a CachedTrack from a FileSystemEntity
  static CachedTrack createTrackFromPath(String path) {
    final file = File(path);
    final fileName = path.split(Platform.pathSeparator).last;
    final dotIndex = fileName.lastIndexOf('.');
    final title = dotIndex != -1 ? fileName.substring(0, dotIndex) : fileName;

    int size = 0;
    int modified = 0;
    try {
      final stat = file.statSync();
      size = stat.size;
      modified = stat.modified.millisecondsSinceEpoch;
    } catch (_) {}

    final bool isVoice = isVoiceNotePath(path);

    return CachedTrack(
      path: path,
      title: title,
      artist: isVoice ? 'Voice Recording' : 'Local Audio',
      album: isVoice ? 'Recordings' : 'Pocketo Music',
      fileSizeBytes: size,
      lastModifiedMs: modified,
      isVoiceMessage: isVoice,
    );
  }

  /// Update cached tracks with newly scanned file list and persist to disk
  Future<void> updateCacheFromScannedFiles(List<String> rawPaths) async {
    final Map<String, CachedTrack> existingMap = {
      for (var t in _cachedTracks) t.path: t
    };

    final List<CachedTrack> updatedList = [];

    for (final path in rawPaths) {
      if (existingMap.containsKey(path)) {
        updatedList.add(existingMap[path]!);
      } else {
        updatedList.add(createTrackFromPath(path));
      }
    }

    _cachedTracks.clear();
    _cachedTracks.addAll(updatedList);
    _lastScanTime = DateTime.now();

    notifyListeners();
    await _saveToDisk();
  }

  /// Save current cache to SharedPreferences
  Future<void> _saveToDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _cachedTracks.map((t) => t.toMap()).toList();
      await prefs.setString(_keyCachedTracks, jsonEncode(list));
      if (_lastScanTime != null) {
        await prefs.setInt(
            _keyLastScanTime, _lastScanTime!.millisecondsSinceEpoch);
      }
    } catch (e) {
      debugPrint('Error saving media cache to disk: $e');
    }
  }

  /// Clear the cache completely (forces fresh scan on next launch)
  Future<void> clearCache() async {
    _cachedTracks.clear();
    _lastScanTime = null;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyCachedTracks);
      await prefs.remove(_keyLastScanTime);
    } catch (e) {
      debugPrint('Error clearing media cache: $e');
    }
  }
}
