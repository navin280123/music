import 'package:flutter/material.dart';

class AppTheme {
  // Light Theme Palette
  static const Color lightScaffold = Color(0xFFF5F7FA);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightSecondaryCard = Color(0xFFEFF2F6);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF64748B);
  static const Color lightPrimary = Color(0xFF6366F1);
  static const Color lightAccent = Color(0xFF8B5CF6);

  // Dark Theme Palette
  static const Color darkScaffold = Color(0xFF121212);
  static const Color darkCard = Color(0xFF1C1C1E);
  static const Color darkSecondaryCard = Color(0xFF282828);
  static const Color darkBorder = Color(0xFF2C2C2E);
  static const Color darkTextPrimary = Colors.white;
  static const Color darkTextSecondary = Colors.white54;
  static const Color darkPrimary = Color(0xFF818CF8);
  static const Color darkAccent = Color(0xFFA78BFA);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightScaffold,
      primaryColor: lightPrimary,
      colorScheme: const ColorScheme.light(
        primary: lightPrimary,
        secondary: lightAccent,
        surface: lightCard,
        onSurface: lightTextPrimary,
        outline: lightBorder,
      ),
      cardTheme: const CardThemeData(
        color: lightCard,
        elevation: 0,
        margin: EdgeInsets.zero,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: lightCard,
        foregroundColor: lightTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      dividerTheme: const DividerThemeData(
        color: lightBorder,
        thickness: 1,
        space: 1,
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: lightPrimary,
        inactiveTrackColor: Color(0xFFCBD5E1),
        thumbColor: lightPrimary,
        overlayColor: Color(0x296366F1),
        trackHeight: 3.5,
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6.0),
        overlayShape: RoundSliderOverlayShape(overlayRadius: 14.0),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: lightCard,
        surfaceTintColor: Colors.transparent,
      ),
      iconTheme: const IconThemeData(
        color: Color(0xFF334155),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkScaffold,
      primaryColor: darkPrimary,
      colorScheme: const ColorScheme.dark(
        primary: darkPrimary,
        secondary: darkAccent,
        surface: darkCard,
        onSurface: darkTextPrimary,
        outline: darkBorder,
      ),
      cardTheme: const CardThemeData(
        color: darkCard,
        elevation: 0,
        margin: EdgeInsets.zero,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF181818),
        foregroundColor: darkTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF282828),
        thickness: 1,
        space: 1,
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: Colors.white,
        inactiveTrackColor: Colors.white24,
        thumbColor: Colors.white,
        overlayColor: Colors.white12,
        trackHeight: 3.5,
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6.0),
        overlayShape: RoundSliderOverlayShape(overlayRadius: 14.0),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: darkCard,
        surfaceTintColor: Colors.transparent,
      ),
      iconTheme: const IconThemeData(
        color: Colors.white70,
      ),
    );
  }

  // Dynamic Theme Helpers
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color cardBg(BuildContext context) =>
      isDark(context) ? darkCard : lightCard;

  static Color secondaryCardBg(BuildContext context) =>
      isDark(context) ? darkSecondaryCard : lightSecondaryCard;

  static Color border(BuildContext context) =>
      isDark(context) ? darkBorder : lightBorder;

  static Color textPrimaryColor(BuildContext context) =>
      isDark(context) ? darkTextPrimary : lightTextPrimary;

  static Color textSecondaryColor(BuildContext context) =>
      isDark(context) ? darkTextSecondary : lightTextSecondary;

  static Color iconCol(BuildContext context) =>
      isDark(context) ? Colors.white70 : const Color(0xFF334155);

  static Color headerBg(BuildContext context) =>
      isDark(context) ? const Color(0xFF181818) : const Color(0xFFFFFFFF);

  static Color navBarBg(BuildContext context) =>
      isDark(context) ? darkCard : const Color(0xFFFFFFFF);

  static Color navBarSelectedBg(BuildContext context) =>
      isDark(context) ? const Color(0xFF2C2C2E) : const Color(0xFFEEF2FF);

  static Color navBarSelectedText(BuildContext context) =>
      isDark(context) ? Colors.white : lightPrimary;

  static Color miniPlayerBg(BuildContext context) =>
      isDark(context) ? const Color(0xFF1E1E1E) : const Color(0xFFFFFFFF);
}
