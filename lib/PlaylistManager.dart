import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PlaylistManager extends ChangeNotifier {
  static final PlaylistManager _instance = PlaylistManager._internal();
  static PlaylistManager get instance => _instance;

  PlaylistManager._internal();

  static const String _keyFavorites = 'pocketo_favorites';
  static const String _keyPlaylists = 'pocketo_playlists';
  static const String _keyPlayCounts = 'pocketo_play_counts';
  static const String _keyRecentlyPlayed = 'pocketo_recently_played';
  static const String _keyListeningSeconds = 'pocketo_listening_seconds';
  static const String _keyFirstPlayDates = 'pocketo_first_play_dates';
  static const String _keyHourlyActivity = 'pocketo_hourly_activity';

  final Set<String> _favoritePaths = {};
  final Map<String, List<String>> _customPlaylists = {};
  final Map<String, int> _playCounts = {};
  final List<String> _recentlyPlayed = [];
  final Map<String, int> _listeningSeconds = {}; // path -> total seconds listened
  final Map<String, String> _firstPlayDates = {}; // path -> ISO date string
  final Map<int, int> _hourlyActivity = {}; // hour (0-23) -> count

  Set<String> get favoritePaths => _favoritePaths;
  Map<String, List<String>> get customPlaylists => _customPlaylists;
  Map<String, int> get playCounts => _playCounts;
  List<String> get recentlyPlayed => _recentlyPlayed;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  // ---- INIT ----

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();

      final favList = prefs.getStringList(_keyFavorites) ?? [];
      _favoritePaths.clear();
      _favoritePaths.addAll(favList);

      final playlistsJson = prefs.getString(_keyPlaylists);
      if (playlistsJson != null && playlistsJson.isNotEmpty) {
        final decoded = jsonDecode(playlistsJson) as Map<String, dynamic>;
        _customPlaylists.clear();
        decoded.forEach((key, value) {
          if (value is List) {
            _customPlaylists[key] = List<String>.from(value);
          }
        });
      }

      final playCountsJson = prefs.getString(_keyPlayCounts);
      if (playCountsJson != null && playCountsJson.isNotEmpty) {
        final decodedCounts = jsonDecode(playCountsJson) as Map<String, dynamic>;
        _playCounts.clear();
        decodedCounts.forEach((key, value) {
          if (value is int) _playCounts[key] = value;
        });
      }

      final recentList = prefs.getStringList(_keyRecentlyPlayed) ?? [];
      _recentlyPlayed.clear();
      _recentlyPlayed.addAll(recentList);

      // Load listening seconds
      final listeningJson = prefs.getString(_keyListeningSeconds);
      if (listeningJson != null && listeningJson.isNotEmpty) {
        final decoded = jsonDecode(listeningJson) as Map<String, dynamic>;
        _listeningSeconds.clear();
        decoded.forEach((key, value) {
          if (value is int) _listeningSeconds[key] = value;
        });
      }

      // Load first play dates
      final datesJson = prefs.getString(_keyFirstPlayDates);
      if (datesJson != null && datesJson.isNotEmpty) {
        final decoded = jsonDecode(datesJson) as Map<String, dynamic>;
        _firstPlayDates.clear();
        decoded.forEach((key, value) {
          if (value is String) _firstPlayDates[key] = value;
        });
      }

      // Load hourly activity
      final hourlyJson = prefs.getString(_keyHourlyActivity);
      if (hourlyJson != null && hourlyJson.isNotEmpty) {
        final decoded = jsonDecode(hourlyJson) as Map<String, dynamic>;
        _hourlyActivity.clear();
        decoded.forEach((key, value) {
          final hour = int.tryParse(key);
          if (hour != null && value is int) _hourlyActivity[hour] = value;
        });
      }

      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing PlaylistManager: $e');
      _isInitialized = true;
      notifyListeners();
    }
  }

  // ---- FAVORITES ----

  bool isFavorite(String filePath) => _favoritePaths.contains(filePath);

  Future<void> toggleFavorite(String filePath) async {
    if (_favoritePaths.contains(filePath)) {
      _favoritePaths.remove(filePath);
    } else {
      _favoritePaths.add(filePath);
    }
    notifyListeners();
    await _saveFavorites();
  }

  Future<void> _saveFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_keyFavorites, _favoritePaths.toList());
    } catch (e) {
      debugPrint('Error saving favorites: $e');
    }
  }

  // ---- CUSTOM PLAYLISTS ----

  List<String> getPlaylistNames() => _customPlaylists.keys.toList();
  List<String> getSongsInPlaylist(String playlistName) =>
      _customPlaylists[playlistName] ?? [];

  Future<bool> createPlaylist(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || _customPlaylists.containsKey(trimmed)) return false;
    _customPlaylists[trimmed] = [];
    notifyListeners();
    await _savePlaylists();
    return true;
  }

  Future<void> deletePlaylist(String name) async {
    if (_customPlaylists.containsKey(name)) {
      _customPlaylists.remove(name);
      notifyListeners();
      await _savePlaylists();
    }
  }

  Future<void> renamePlaylist(String oldName, String newName) async {
    final trimmedNew = newName.trim();
    if (trimmedNew.isEmpty ||
        !_customPlaylists.containsKey(oldName) ||
        _customPlaylists.containsKey(trimmedNew)) { return; }
    final songs = _customPlaylists.remove(oldName)!;
    _customPlaylists[trimmedNew] = songs;
    notifyListeners();
    await _savePlaylists();
  }

  Future<void> addSongToPlaylist(String playlistName, String filePath) async {
    if (!_customPlaylists.containsKey(playlistName)) {
      _customPlaylists[playlistName] = [];
    }
    if (!_customPlaylists[playlistName]!.contains(filePath)) {
      _customPlaylists[playlistName]!.add(filePath);
      notifyListeners();
      await _savePlaylists();
    }
  }

  Future<void> removeSongFromPlaylist(String playlistName, String filePath) async {
    if (_customPlaylists.containsKey(playlistName)) {
      _customPlaylists[playlistName]!.remove(filePath);
      notifyListeners();
      await _savePlaylists();
    }
  }

  Future<void> _savePlaylists() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyPlaylists, jsonEncode(_customPlaylists));
    } catch (e) {
      debugPrint('Error saving playlists: $e');
    }
  }

  // ---- PLAY STATS & RECENTLY PLAYED ----

  /// Call this whenever a song starts playing.
  Future<void> recordSongPlay(String filePath) async {
    if (filePath.isEmpty) return;

    _playCounts[filePath] = (_playCounts[filePath] ?? 0) + 1;

    _recentlyPlayed.remove(filePath);
    _recentlyPlayed.insert(0, filePath);
    if (_recentlyPlayed.length > 50) _recentlyPlayed.removeLast();

    // Record first play date if not already set
    _firstPlayDates.putIfAbsent(
        filePath, () => DateTime.now().toIso8601String());

    // Record hourly activity
    final hour = DateTime.now().hour;
    _hourlyActivity[hour] = (_hourlyActivity[hour] ?? 0) + 1;

    notifyListeners();
    await _saveStats();
  }

  /// Call this when a song is paused or stopped to accumulate listening time.
  Future<void> recordListeningDuration(String filePath, Duration duration) async {
    if (filePath.isEmpty || duration.inSeconds <= 0) return;
    _listeningSeconds[filePath] =
        (_listeningSeconds[filePath] ?? 0) + duration.inSeconds;
    notifyListeners();
    await _saveListeningData();
  }

  Future<void> _saveStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyPlayCounts, jsonEncode(_playCounts));
      await prefs.setStringList(_keyRecentlyPlayed, _recentlyPlayed);
      await prefs.setString(
        _keyFirstPlayDates,
        jsonEncode(_firstPlayDates),
      );
      await prefs.setString(
        _keyHourlyActivity,
        jsonEncode(
            _hourlyActivity.map((k, v) => MapEntry(k.toString(), v))),
      );
    } catch (e) {
      debugPrint('Error saving stats: $e');
    }
  }

  Future<void> _saveListeningData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyListeningSeconds, jsonEncode(_listeningSeconds));
    } catch (e) {
      debugPrint('Error saving listening data: $e');
    }
  }

  int getSongPlayCount(String filePath) => _playCounts[filePath] ?? 0;

  int get totalPlaysCount =>
      _playCounts.values.fold(0, (sum, count) => sum + count);

  /// Total listening time across all tracks in minutes.
  int get totalListeningMinutes {
    final totalSec = _listeningSeconds.values.fold(0, (a, b) => a + b);
    return (totalSec / 60).round();
  }

  /// Returns the hour (0-23) with the most listening activity.
  int? get mostActiveHour {
    if (_hourlyActivity.isEmpty) return null;
    return _hourlyActivity.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }

  /// Listening activity map (0-23 hour -> play count) for charts.
  Map<int, int> get hourlyActivity => Map.unmodifiable(_hourlyActivity);

  List<MapEntry<String, int>> getTopPlayedSongs({int limit = 10}) {
    final entries = _playCounts.entries.toList();
    entries.sort((a, b) => b.value.compareTo(a.value));
    return entries.take(limit).toList();
  }

  /// Whether today is a "song anniversary" for this file (first played exactly N years ago).
  String? getAnniversaryLabel(String filePath) {
    final dateStr = _firstPlayDates[filePath];
    if (dateStr == null) return null;
    try {
      final firstPlay = DateTime.parse(dateStr);
      final now = DateTime.now();
      if (firstPlay.month == now.month && firstPlay.day == now.day) {
        final years = now.year - firstPlay.year;
        if (years >= 1) return '🎂 ${years}yr anniversary';
      }
    } catch (_) {}
    return null;
  }

  // ---- FOLDER GROUPING ----

  static Map<String, List<String>> groupSongsByFolder(List<String> filePaths) {
    final Map<String, List<String>> folderMap = {};
    for (final path in filePaths) {
      final file = File(path);
      final parentDir = file.parent.path;
      final folderName = parentDir.split(Platform.pathSeparator).last;
      final displayFolder =
          folderName.isEmpty ? 'Internal Storage' : folderName;

      if (!folderMap.containsKey(displayFolder)) {
        folderMap[displayFolder] = [];
      }
      folderMap[displayFolder]!.add(path);
    }
    return folderMap;
  }
}
