import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:music/helpers/artwork_helper.dart';

/// Extracts and caches dominant color palettes from track album artwork.
class ColorPaletteService {
  static final ColorPaletteService _instance = ColorPaletteService._internal();
  static ColorPaletteService get instance => _instance;
  ColorPaletteService._internal();

  final Map<String, TrackPalette> _cache = {};

  /// Returns the [_TrackPalette] for the given file path.
  /// Uses cached result if available. Returns a neutral palette if artwork is missing.
  Future<TrackPalette> getPalette(String? filePath) async {
    if (filePath == null || filePath.isEmpty) return TrackPalette.neutral();

    if (_cache.containsKey(filePath)) return _cache[filePath]!;

    try {
      final Uint8List? bytes = await ArtworkHelper.getArtworkBytes(filePath);
      if (bytes == null || bytes.isEmpty) {
        _cache[filePath] = TrackPalette.neutral();
        return _cache[filePath]!;
      }

      final codec = await ui.instantiateImageCodec(bytes, targetWidth: 100, targetHeight: 100);
      final frame = await codec.getNextFrame();
      final image = frame.image;

      final PaletteGenerator pg = await PaletteGenerator.fromImage(image);

      final dominant = pg.dominantColor?.color ?? TrackPalette.neutral().dominant;
      final vibrant = pg.vibrantColor?.color ??
          pg.lightVibrantColor?.color ??
          dominant;
      final muted = pg.mutedColor?.color ??
          pg.darkMutedColor?.color ??
          dominant;

      final palette = TrackPalette(
        dominant: dominant,
        vibrant: vibrant,
        muted: muted,
      );

      _cache[filePath] = palette;
      return palette;
    } catch (e) {
      debugPrint('ColorPaletteService error for $filePath: $e');
      _cache[filePath] = TrackPalette.neutral();
      return _cache[filePath]!;
    }
  }

  /// Clears the palette cache (call when ArtworkHelper cache is also cleared).
  void clearCache() => _cache.clear();
}

/// Holds three representative colors extracted from a track's album art.
class TrackPalette {
  final Color dominant;
  final Color vibrant;
  final Color muted;

  const TrackPalette({
    required this.dominant,
    required this.vibrant,
    required this.muted,
  });

  factory TrackPalette.neutral() => const TrackPalette(
        dominant: Color(0xFF1C1C1E),
        vibrant: Color(0xFF818CF8),
        muted: Color(0xFF2C2C2E),
      );

  /// A subtle tinted background gradient for the player screen.
  List<Color> get playerGradient => [
        dominant.withValues(alpha: 0.85),
        muted.withValues(alpha: 0.6),
        const Color(0xFF0D0D0F),
      ];

  /// A subtle mini-player tint (very low opacity to stay readable).
  Color get miniPlayerTint => dominant.withValues(alpha: 0.18);

  /// The text-safe foreground accent (vibrant for contrast).
  Color get accent => vibrant;
}

