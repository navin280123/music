import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:music/AppSettings.dart';
import 'package:music/AppTheme.dart';
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
}
