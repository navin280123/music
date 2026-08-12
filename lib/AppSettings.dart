import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings extends ChangeNotifier {
  static final AppSettings _instance = AppSettings._internal();
  static AppSettings get instance => _instance;

  AppSettings._internal();

  static const String _keyThemeMode = 'app_theme_mode';
  static const String _keyAutoPlayNext = 'app_auto_play_next';
  static const String _keyHighQualityAudio = 'app_high_quality_audio';
  static const String _keyKeepScreenOn = 'app_keep_screen_on';
  static const String _keyIncludeVoiceMessages = 'app_include_voice_messages';

  ThemeMode _themeMode = ThemeMode.system;
  bool _autoPlayNext = true;
  bool _highQualityAudio = true;
  bool _keepScreenOn = false;
  bool _includeVoiceMessages = false;
  bool _isInitialized = false;

  ThemeMode get themeMode => _themeMode;
  bool get autoPlayNext => _autoPlayNext;
  bool get highQualityAudio => _highQualityAudio;
  bool get keepScreenOn => _keepScreenOn;
  bool get includeVoiceMessages => _includeVoiceMessages;
  bool get isInitialized => _isInitialized;

  /// Loads persisted settings from SharedPreferences
  Future<void> loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final themeModeStr = prefs.getString(_keyThemeMode);
      if (themeModeStr == 'light') {
        _themeMode = ThemeMode.light;
      } else if (themeModeStr == 'dark') {
        _themeMode = ThemeMode.dark;
      } else {
        _themeMode = ThemeMode.system;
      }

      _autoPlayNext = prefs.getBool(_keyAutoPlayNext) ?? true;
      _highQualityAudio = prefs.getBool(_keyHighQualityAudio) ?? true;
      _keepScreenOn = prefs.getBool(_keyKeepScreenOn) ?? false;
      _includeVoiceMessages = prefs.getBool(_keyIncludeVoiceMessages) ?? false;
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading settings: $e');
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// Update theme mode and persist to SharedPreferences
  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      String val = 'system';
      if (mode == ThemeMode.light) val = 'light';
      if (mode == ThemeMode.dark) val = 'dark';
      await prefs.setString(_keyThemeMode, val);
    } catch (e) {
      debugPrint('Error saving theme mode: $e');
    }
  }

  /// Toggle Auto-play next track
  Future<void> setAutoPlayNext(bool value) async {
    if (_autoPlayNext == value) return;
    _autoPlayNext = value;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyAutoPlayNext, value);
    } catch (e) {
      debugPrint('Error saving auto play setting: $e');
    }
  }

  /// Toggle High Quality Audio
  Future<void> setHighQualityAudio(bool value) async {
    if (_highQualityAudio == value) return;
    _highQualityAudio = value;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyHighQualityAudio, value);
    } catch (e) {
      debugPrint('Error saving high quality audio setting: $e');
    }
  }

  /// Toggle Keep Screen On
  Future<void> setKeepScreenOn(bool value) async {
    if (_keepScreenOn == value) return;
    _keepScreenOn = value;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyKeepScreenOn, value);
    } catch (e) {
      debugPrint('Error saving keep screen on setting: $e');
    }
  }

  /// Toggle Include Voice Messages & Recordings
  Future<void> setIncludeVoiceMessages(bool value) async {
    if (_includeVoiceMessages == value) return;
    _includeVoiceMessages = value;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyIncludeVoiceMessages, value);
    } catch (e) {
      debugPrint('Error saving include voice messages setting: $e');
    }
  }

  /// Reset all settings to defaults
  Future<void> resetToDefaults() async {
    _themeMode = ThemeMode.system;
    _autoPlayNext = true;
    _highQualityAudio = true;
    _keepScreenOn = false;
    _includeVoiceMessages = false;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyThemeMode);
      await prefs.remove(_keyAutoPlayNext);
      await prefs.remove(_keyHighQualityAudio);
      await prefs.remove(_keyKeepScreenOn);
      await prefs.remove(_keyIncludeVoiceMessages);
    } catch (e) {
      debugPrint('Error resetting settings: $e');
    }
  }
}
