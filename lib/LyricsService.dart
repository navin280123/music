import 'dart:io';
import 'package:audiotags/audiotags.dart';
import 'package:flutter/foundation.dart';

class LyricLine {
  final Duration timestamp;
  final String text;

  LyricLine({required this.timestamp, required this.text});
}

class LyricsService {
  /// Fetches lyrics for a given audio file path (.lrc file, companion text, or ID3 lyrics tag)
  static Future<List<LyricLine>> getLyricsForFile(String filePath) async {
    try {
      // 1. Check for companion .lrc file
      final lrcPath = _replaceExtension(filePath, '.lrc');
      final lrcFile = File(lrcPath);
      if (await lrcFile.exists()) {
        final content = await lrcFile.readAsString();
        final parsed = parseLrc(content);
        if (parsed.isNotEmpty) return parsed;
      }

      // 2. Check for companion .txt file
      final txtPath = _replaceExtension(filePath, '.txt');
      final txtFile = File(txtPath);
      if (await txtFile.exists()) {
        final content = await txtFile.readAsString();
        final parsed = parseLrc(content);
        if (parsed.isNotEmpty) return parsed;
      }

      // 3. Check ID3 tag for embedded lyrics
      final tag = await AudioTags.read(filePath);
      if (tag?.lyrics != null && tag!.lyrics!.trim().isNotEmpty) {
        final parsed = parseLrc(tag.lyrics!);
        if (parsed.isNotEmpty) return parsed;

        // If not timestamped LRC, convert plain text lines into untimed lyric lines
        final plainLines = tag.lyrics!
            .split('\n')
            .map((l) => l.trim())
            .where((l) => l.isNotEmpty)
            .toList();

        return List.generate(plainLines.length, (i) {
          return LyricLine(
            timestamp: Duration(seconds: i * 4), // Rough estimate for plain text
            text: plainLines[i],
          );
        });
      }
    } catch (e) {
      debugPrint("Error reading lyrics for $filePath: $e");
    }

    return [];
  }

  /// Parses standard LRC content: [mm:ss.xx] or [mm:ss]
  static List<LyricLine> parseLrc(String content) {
    final List<LyricLine> lines = [];
    final regExp = RegExp(r'\[(\d{2}):(\d{2})(?:\.(\d{2,3}))?\](.*)');

    for (final line in content.split('\n')) {
      final match = regExp.firstMatch(line.trim());
      if (match != null) {
        final minutes = int.tryParse(match.group(1) ?? '0') ?? 0;
        final seconds = int.tryParse(match.group(2) ?? '0') ?? 0;
        final fractionStr = match.group(3) ?? '0';
        final millis = int.tryParse(fractionStr.padRight(3, '0').substring(0, 3)) ?? 0;

        final duration = Duration(
          minutes: minutes,
          seconds: seconds,
          milliseconds: millis,
        );

        final text = (match.group(4) ?? '').trim();
        if (text.isNotEmpty) {
          lines.add(LyricLine(timestamp: duration, text: text));
        }
      }
    }

    lines.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return lines;
  }

  /// Returns the index of the currently active lyric line based on playback position
  static int getActiveLyricIndex(List<LyricLine> lyrics, Duration currentPosition) {
    if (lyrics.isEmpty) return -1;
    for (int i = lyrics.length - 1; i >= 0; i--) {
      if (currentPosition >= lyrics[i].timestamp) {
        return i;
      }
    }
    return 0;
  }

  static String _replaceExtension(String path, String newExt) {
    final dotIndex = path.lastIndexOf('.');
    if (dotIndex != -1) {
      return "${path.substring(0, dotIndex)}$newExt";
    }
    return "$path$newExt";
  }
}
