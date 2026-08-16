import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:music/widgets/ab_looper_widget.dart';
import 'package:music/core/app_settings.dart';
import 'package:music/core/app_theme.dart';
import 'package:music/services/lyrics_service.dart';
import 'package:music/services/media_cache_service.dart';
import 'package:music/services/playlist_manager.dart';
import 'package:music/services/sleep_timer_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('AppSettings initializes with defaults and toggles correctly', () async {
    final settings = AppSettings.instance;
    await settings.loadSettings();

    expect(settings.themeMode, ThemeMode.system);
    expect(settings.autoPlayNext, true);
    expect(settings.highQualityAudio, true);
    expect(settings.keepScreenOn, false);

    await settings.setThemeMode(ThemeMode.dark);
    expect(settings.themeMode, ThemeMode.dark);

    await settings.setThemeMode(ThemeMode.light);
    expect(settings.themeMode, ThemeMode.light);

    await settings.setAutoPlayNext(false);
    expect(settings.autoPlayNext, false);

    await settings.setHighQualityAudio(false);
    expect(settings.highQualityAudio, false);

    await settings.setKeepScreenOn(true);
    expect(settings.keepScreenOn, true);

    await settings.resetToDefaults();
    expect(settings.themeMode, ThemeMode.system);
    expect(settings.autoPlayNext, true);
  });

  test('AppTheme creates valid light and dark ThemeData', () {
    final light = AppTheme.lightTheme;
    final dark = AppTheme.darkTheme;

    expect(light.brightness, Brightness.light);
    expect(dark.brightness, Brightness.dark);
    expect(light.scaffoldBackgroundColor, AppTheme.lightScaffold);
    expect(dark.scaffoldBackgroundColor, AppTheme.darkScaffold);
  });

  test('PlaylistManager handles favorites, playlists, and play stats correctly', () async {
    final manager = PlaylistManager.instance;
    await manager.init();

    // Favorites
    expect(manager.isFavorite('/storage/test_song.mp3'), false);
    await manager.toggleFavorite('/storage/test_song.mp3');
    expect(manager.isFavorite('/storage/test_song.mp3'), true);
    await manager.toggleFavorite('/storage/test_song.mp3');
    expect(manager.isFavorite('/storage/test_song.mp3'), false);

    // Custom Playlists
    final created = await manager.createPlaylist('Chill Vibes');
    expect(created, true);
    expect(manager.getPlaylistNames().contains('Chill Vibes'), true);

    await manager.addSongToPlaylist('Chill Vibes', '/storage/song1.mp3');
    expect(manager.getSongsInPlaylist('Chill Vibes').length, 1);

    await manager.removeSongFromPlaylist('Chill Vibes', '/storage/song1.mp3');
    expect(manager.getSongsInPlaylist('Chill Vibes').isEmpty, true);

    await manager.deletePlaylist('Chill Vibes');
    expect(manager.getPlaylistNames().contains('Chill Vibes'), false);

    // Play stats
    await manager.recordSongPlay('/storage/song1.mp3');
    await manager.recordSongPlay('/storage/song1.mp3');
    expect(manager.getSongPlayCount('/storage/song1.mp3'), 2);
    expect(manager.totalPlaysCount >= 2, true);
  });

  test('LyricsService parses LRC formatted text accurately', () {
    const lrc = '''
[00:05.50]First line of lyrics
[00:15.00]Second line of song
[01:02.30]Chorus starts here
''';
    final lines = LyricsService.parseLrc(lrc);
    expect(lines.length, 3);
    expect(lines[0].text, 'First line of lyrics');
    expect(lines[0].timestamp.inSeconds, 5);
    expect(lines[1].text, 'Second line of song');
    expect(lines[1].timestamp.inSeconds, 15);
    expect(lines[2].text, 'Chorus starts here');
    expect(lines[2].timestamp.inSeconds, 62);

    final activeIndex = LyricsService.getActiveLyricIndex(lines, const Duration(seconds: 16));
    expect(activeIndex, 1);
  });

  test('ABLooperService sets and clears loop markers correctly', () {
    final looper = ABLooperService.instance;
    looper.clear();

    looper.setPointA(const Duration(seconds: 10));
    expect(looper.pointA, const Duration(seconds: 10));
    expect(looper.pointB, null);

    looper.setPointB(const Duration(seconds: 25));
    expect(looper.pointB, const Duration(seconds: 25));
    expect(looper.isEnabled, true);

    looper.toggleEnabled();
    expect(looper.isEnabled, false);

    looper.clear();
    expect(looper.pointA, null);
    expect(looper.pointB, null);
    expect(looper.isEnabled, false);
  });

  test('AppSettings includes and persists includeVoiceMessages toggle', () async {
    final settings = AppSettings.instance;
    await settings.loadSettings();

    // Default should be false (voice messages filtered out)
    expect(settings.includeVoiceMessages, false);

    await settings.setIncludeVoiceMessages(true);
    expect(settings.includeVoiceMessages, true);

    await settings.setIncludeVoiceMessages(false);
    expect(settings.includeVoiceMessages, false);
  });

  test('MediaCacheService detects voice note paths accurately', () {
    // WhatsApp voice notes
    expect(
      MediaCacheService.isVoiceNotePath(
          '/storage/emulated/0/WhatsApp/Media/WhatsApp Voice Notes/PTT-20240101-WA0001.opus'),
      true,
    );
    expect(
      MediaCacheService.isVoiceNotePath(
          '/storage/emulated/0/WhatsApp/Media/WhatsApp Audio/AUD-20240101-WA0002.mp3'),
      true,
    );
    // Telegram / Recordings
    expect(
      MediaCacheService.isVoiceNotePath(
          '/storage/emulated/0/Telegram/Telegram Audio/voice_message_123.ogg'),
      true,
    );
    expect(
      MediaCacheService.isVoiceNotePath(
          '/storage/emulated/0/Recordings/call_recording_01.m4a'),
      true,
    );

    // Regular Music files
    expect(
      MediaCacheService.isVoiceNotePath(
          '/storage/emulated/0/Music/Coldplay - Yellow.mp3'),
      false,
    );
    expect(
      MediaCacheService.isVoiceNotePath(
          '/storage/emulated/0/Download/Imagine Dragons - Believer.flac'),
      false,
    );
  });

  test('MediaCacheService caches tracks and filters voice messages based on setting', () async {
    final cache = MediaCacheService.instance;
    await cache.init();

    final testPaths = [
      '/storage/emulated/0/Music/Song A.mp3',
      '/storage/emulated/0/Music/Song B.mp3',
      '/storage/emulated/0/WhatsApp/Media/WhatsApp Voice Notes/PTT-1.opus',
    ];

    await cache.updateCacheFromScannedFiles(testPaths);

    expect(cache.totalCount, 3);
    expect(cache.musicTracksCount, 2);
    expect(cache.voiceMessagesCount, 1);

    // Filtered by default (includeVoiceMessages: false)
    final filteredPaths = cache.getFilePaths(includeVoiceMessages: false);
    expect(filteredPaths.length, 2);
    expect(filteredPaths.contains('/storage/emulated/0/Music/Song A.mp3'), true);
    expect(filteredPaths.contains('/storage/emulated/0/Music/Song B.mp3'), true);
    expect(filteredPaths.contains('/storage/emulated/0/WhatsApp/Media/WhatsApp Voice Notes/PTT-1.opus'), false);

    // All tracks when includeVoiceMessages: true
    final allPaths = cache.getFilePaths(includeVoiceMessages: true);
    expect(allPaths.length, 3);
  });

  test('SleepTimerService manages timer state and formats correctly', () {
    final timer = SleepTimerService.instance;
    expect(timer.isActive, false);
    expect(timer.formattedRemainingTime, 'Off');
  });
}

