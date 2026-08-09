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

  final Set<String> _favoritePaths = {};
  final Map<String, List<String>> _customPlaylists = {};
  final Map<String, int> _playCounts = {};
  final List<String> _recentlyPlayed = [];

  Set<String> get favoritePaths => _favoritePaths;
  Map<String, List<String>> get customPlaylists => _customPlaylists;
  Map<String, int> get playCounts => _playCounts;
  List<String> get recentlyPlayed => _recentlyPlayed;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  /// Loads all playlists, favorites, and statistics from SharedPreferences
  Future<void> init() async {
    if (_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load favorites
      final favList = prefs.getStringList(_keyFavorites) ?? [];
      _favoritePaths.clear();
      _favoritePaths.addAll(favList);

      // Load custom playlists
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

      // Load play counts
      final playCountsJson = prefs.getString(_keyPlayCounts);
      if (playCountsJson != null && playCountsJson.isNotEmpty) {
        final decodedCounts = jsonDecode(playCountsJson) as Map<String, dynamic>;
        _playCounts.clear();
        decodedCounts.forEach((key, value) {
          if (value is int) {
            _playCounts[key] = value;
          }
        });
      }

      // Load recently played
      final recentList = prefs.getStringList(_keyRecentlyPlayed) ?? [];
      _recentlyPlayed.clear();
      _recentlyPlayed.addAll(recentList);

      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint("Error initializing PlaylistManager: $e");
      _isInitialized = true;
      notifyListeners();
    }
  }

  // --- FAVORITES ---

  bool isFavorite(String filePath) {
    return _favoritePaths.contains(filePath);
  }

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
      debugPrint("Error saving favorites: $e");
    }
  }

  // --- CUSTOM PLAYLISTS ---

  List<String> getPlaylistNames() {
    return _customPlaylists.keys.toList();
  }

  List<String> getSongsInPlaylist(String playlistName) {
    return _customPlaylists[playlistName] ?? [];
  }

  Future<bool> createPlaylist(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || _customPlaylists.containsKey(trimmed)) {
      return false;
    }
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
        _customPlaylists.containsKey(trimmedNew)) {
      return;
    }
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
      debugPrint("Error saving playlists: $e");
    }
  }

  // --- PLAY STATS & RECENTLY PLAYED ---

  Future<void> recordSongPlay(String filePath) async {
    if (filePath.isEmpty) return;

    // Increment play count
    _playCounts[filePath] = (_playCounts[filePath] ?? 0) + 1;

    // Update recently played (max 50 tracks)
    _recentlyPlayed.remove(filePath);
    _recentlyPlayed.insert(0, filePath);
    if (_recentlyPlayed.length > 50) {
      _recentlyPlayed.removeLast();
    }

    notifyListeners();
    await _saveStats();
  }

  Future<void> _saveStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyPlayCounts, jsonEncode(_playCounts));
      await prefs.setStringList(_keyRecentlyPlayed, _recentlyPlayed);
    } catch (e) {
      debugPrint("Error saving stats: $e");
    }
  }

  int getSongPlayCount(String filePath) {
    return _playCounts[filePath] ?? 0;
  }

  int get totalPlaysCount {
    return _playCounts.values.fold(0, (sum, count) => sum + count);
  }

  List<MapEntry<String, int>> getTopPlayedSongs({int limit = 10}) {
    final entries = _playCounts.entries.toList();
    entries.sort((a, b) => b.value.compareTo(a.value));
    return entries.take(limit).toList();
  }

  // --- FOLDER GROUPING HELPER ---

  static Map<String, List<String>> groupSongsByFolder(List<String> filePaths) {
    final Map<String, List<String>> folderMap = {};
    for (final path in filePaths) {
      final file = File(path);
      final parentDir = file.parent.path;
      final folderName = parentDir.split(Platform.pathSeparator).last;
      final displayFolder = folderName.isEmpty ? "Internal Storage" : folderName;

      if (!folderMap.containsKey(displayFolder)) {
        folderMap[displayFolder] = [];
      }
      folderMap[displayFolder]!.add(path);
    }
    return folderMap;
  }
}
