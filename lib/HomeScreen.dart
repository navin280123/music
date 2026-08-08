import 'package:flutter/material.dart';
import 'dart:io';

import 'package:just_audio/just_audio.dart';
import 'package:music/AppTheme.dart';
import 'package:music/ArtworkHelper.dart';

class HomeScreen extends StatefulWidget {
  final List<dynamic> audioFiles;
  final AudioPlayer audioPlayer;
  final int? currentlyPlayingIndex;
  final Duration duration;
  final Duration position;
  final bool isPlaying;
  final Function() onPlay;
  final Function() onPause;
  final Function() onNext;
  final Function() onPrevious;
  final Function(int) playTrack;
  final Function(int) onTabTapped;
  final VoidCallback? onRescan;

  const HomeScreen({
    super.key,
    required this.audioFiles,
    required this.audioPlayer,
    required this.currentlyPlayingIndex,
    required this.duration,
    required this.position,
    required this.isPlaying,
    required this.onPlay,
    required this.onPause,
    required this.onNext,
    required this.onPrevious,
    required this.playTrack,
    required this.onTabTapped,
    this.onRescan,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final scaffoldBg = isDark ? AppTheme.darkScaffold : AppTheme.lightScaffold;

    if (widget.audioFiles.isEmpty) {
      return Scaffold(
        backgroundColor: scaffoldBg,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24.0),
                  decoration: BoxDecoration(
                    color: AppTheme.cardBg(context),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.border(context)),
                  ),
                  child: Icon(
                    Icons.music_off_rounded,
                    size: 48,
                    color: AppTheme.textSecondaryColor(context),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  "No Music Found",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryColor(context),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "We couldn't find any audio files on your device. Make sure audio files are stored in Music, Downloads, or Internal Storage.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: AppTheme.textSecondaryColor(context),
                  ),
                ),
                if (widget.onRescan != null) ...[
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: widget.onRescan,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text("Scan For Music"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          isDark ? const Color(0xFF2C2C2E) : AppTheme.lightPrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: ListView.builder(
        padding: const EdgeInsets.only(
          bottom: 20.0,
          top: 8.0,
        ),
        physics: const BouncingScrollPhysics(),
        itemCount: widget.audioFiles.length,
        itemBuilder: (context, index) {
          return _buildMusicTile(context, widget.audioFiles[index], index);
        },
      ),
    );
  }

  Widget _buildMusicTile(
      BuildContext context, FileSystemEntity file, int index) {
    final isDark = AppTheme.isDark(context);
    String fileName = file.path.split(Platform.pathSeparator).last;
    bool isPlayingCurrent =
        widget.currentlyPlayingIndex == index && widget.isPlaying;
    bool isCurrentSelected = widget.currentlyPlayingIndex == index;

    final selectedBg =
        isDark ? const Color(0xFF282828) : const Color(0xFFEEF2FF);
    final normalBg = AppTheme.cardBg(context);
    final selectedBorder =
        isDark ? Colors.white38 : AppTheme.lightPrimary.withValues(alpha: 0.5);
    final normalBorder = AppTheme.border(context);

    final titleColor = isCurrentSelected
        ? (isDark ? Colors.white : AppTheme.lightPrimary)
        : AppTheme.textPrimaryColor(context);
    final subtitleColor = AppTheme.textSecondaryColor(context);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 16.0),
      decoration: BoxDecoration(
        color: isCurrentSelected ? selectedBg : normalBg,
        borderRadius: BorderRadius.circular(14.0),
        border: Border.all(
          color: isCurrentSelected ? selectedBorder : normalBorder,
          width: 1.0,
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(vertical: 4.0, horizontal: 12.0),
        leading: ArtworkHelper.buildArtworkWidget(
          file.path,
          width: 48,
          height: 48,
          borderRadius: 8.0,
        ),
        title: Text(
          fileName,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: isCurrentSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 14.5,
            color: titleColor,
          ),
        ),
        subtitle: Text(
          "Audio Track",
          style: TextStyle(
            fontSize: 12.0,
            color: subtitleColor,
          ),
        ),
        onTap: () {
          widget.playTrack(index);
        },
        trailing: IconButton(
          icon: Icon(
            isPlayingCurrent
                ? Icons.pause_circle_filled_rounded
                : Icons.play_circle_fill_rounded,
            color: isCurrentSelected
                ? (isDark ? Colors.white : AppTheme.lightPrimary)
                : (isDark ? Colors.white70 : const Color(0xFF475569)),
            size: 32.0,
          ),
          onPressed: () {
            if (isPlayingCurrent) {
              widget.onPause();
            } else {
              widget.playTrack(index);
            }
          },
        ),
      ),
    );
  }
}
