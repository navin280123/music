import 'dart:typed_data';
import 'package:audiotags/audiotags.dart';
import 'package:flutter/material.dart';
import 'package:music/AppTheme.dart';

class ArtworkHelper {
  static final Map<String, Uint8List?> _artworkCache = {};

  /// Clears the in-memory album art cache
  static void clearCache() {
    _artworkCache.clear();
  }

  static Future<Uint8List?> getArtwork(String filePath) async {
    if (_artworkCache.containsKey(filePath)) {
      return _artworkCache[filePath];
    }

    try {
      final tag = await AudioTags.read(filePath);
      final bytes =
          (tag?.pictures.isNotEmpty ?? false) ? tag!.pictures.first.bytes : null;
      _artworkCache[filePath] = bytes;
      return bytes;
    } catch (_) {
      _artworkCache[filePath] = null;
      return null;
    }
  }

  static Widget buildArtworkWidget(
    String filePath, {
    double width = 48.0,
    double height = 48.0,
    double borderRadius = 10.0,
  }) {
    return FutureBuilder<Uint8List?>(
      future: getArtwork(filePath),
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes != null && bytes.isNotEmpty) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: Image.memory(
              bytes,
              width: width,
              height: height,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  _buildFallbackArtwork(context, width, height, borderRadius),
            ),
          );
        }
        return _buildFallbackArtwork(context, width, height, borderRadius);
      },
    );
  }

  static Widget _buildFallbackArtwork(
    BuildContext context,
    double width,
    double height,
    double borderRadius,
  ) {
    final isDark = AppTheme.isDark(context);
    final bgColor =
        isDark ? const Color(0xFF282828) : const Color(0xFFE2E8F0);
    final iconColor =
        isDark ? Colors.white60 : const Color(0xFF64748B);

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Container(
        width: width,
        height: height,
        color: bgColor,
        child: Image.asset(
          'assets/music.png',
          width: width,
          height: height,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Center(
            child: Icon(
              Icons.music_note_rounded,
              color: iconColor,
              size: width * 0.5,
            ),
          ),
        ),
      ),
    );
  }
}
