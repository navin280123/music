import 'package:flutter/material.dart';
import 'dart:io';
import 'package:just_audio/just_audio.dart';
import 'package:music/AppTheme.dart';
import 'package:music/ArtworkHelper.dart';

class PlayScreen extends StatefulWidget {
  final List<dynamic> audioFiles;
  final AudioPlayer audioPlayer;
  final int? currentlyPlayingIndex;
  final Duration duration;
  final Duration position;
  final bool isPlaying;
  final bool isRepeat;
  final Function() onPlay;
  final Function() onPause;
  final Function() onNext;
  final Function() onPrevious;
  final Function(int) playTrack;
  final Function() toggleRepeat;

  const PlayScreen({
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
    required this.toggleRepeat,
    required this.isRepeat,
  });

  @override
  State<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends State<PlayScreen>
    with SingleTickerProviderStateMixin {
  double sliderValue = 0;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.96, end: 1.02).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    widget.audioPlayer.positionStream.listen((position) {
      if (mounted) {
        setState(() {
          sliderValue = position.inSeconds.toDouble();
        });
      }
    });
    _updateAnimationState();
  }

  @override
  void didUpdateWidget(covariant PlayScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isPlaying != widget.isPlaying) _updateAnimationState();
  }

  void _updateAnimationState() {
    if (widget.isPlaying) {
      _controller.repeat(reverse: true);
    } else {
      _controller.animateTo(0.0,
          duration: const Duration(milliseconds: 500), curve: Curves.easeOut);
    }
  }

  void seekAudio(double seconds) {
    widget.audioPlayer.seek(Duration(seconds: seconds.toInt()));
  }

  void showSongSelectionSheet() {
    final isDark = AppTheme.isDark(context);
    final sheetBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final itemBg = isDark ? const Color(0xFF282828) : const Color(0xFFF1F5F9);
    final activeItemBg =
        isDark ? const Color(0xFF3A3A3C) : const Color(0xFFEEF2FF);
    final textCol = isDark ? Colors.white : const Color(0xFF0F172A);
    final subTextCol = isDark ? Colors.white60 : const Color(0xFF64748B);
    final borderCol = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE2E8F0);

    showModalBottomSheet(
      context: context,
      backgroundColor: sheetBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              // Header with title and close button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Track Queue (${widget.audioFiles.length})",
                    style: TextStyle(
                      color: textCol,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: subTextCol),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              Divider(color: borderCol, thickness: 1),
              const SizedBox(height: 8),
              Expanded(
                child: widget.audioFiles.isEmpty
                    ? Center(
                        child: Text(
                          "No tracks available",
                          style: TextStyle(color: subTextCol),
                        ),
                      )
                    : ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        itemCount: widget.audioFiles.length,
                        itemBuilder: (context, index) {
                          final filePath = widget.audioFiles[index].path;
                          final songName =
                              filePath.split(Platform.pathSeparator).last;
                          final isCurrent =
                              widget.currentlyPlayingIndex == index;

                          return Container(
                            margin: const EdgeInsets.symmetric(vertical: 4.0),
                            decoration: BoxDecoration(
                              color: isCurrent ? activeItemBg : itemBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isCurrent
                                    ? (isDark
                                        ? Colors.white38
                                        : AppTheme.lightPrimary)
                                    : borderCol,
                              ),
                            ),
                            child: ListTile(
                              leading: ArtworkHelper.buildArtworkWidget(
                                filePath,
                                width: 40,
                                height: 40,
                                borderRadius: 8,
                              ),
                              title: Text(
                                songName,
                                style: TextStyle(
                                  color: isCurrent
                                      ? (isDark
                                          ? Colors.white
                                          : AppTheme.lightPrimary)
                                      : textCol,
                                  fontSize: 14.5,
                                  fontWeight: isCurrent
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                              trailing: isCurrent && widget.isPlaying
                                  ? Icon(
                                      Icons.graphic_eq_rounded,
                                      color: isDark
                                          ? Colors.white
                                          : AppTheme.lightPrimary,
                                      size: 20,
                                    )
                                  : null,
                              onTap: () {
                                widget.playTrack(index);
                                Navigator.pop(context);
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final scaffoldBg = isDark ? AppTheme.darkScaffold : AppTheme.lightScaffold;
    final cardBg = AppTheme.cardBg(context);
    final borderCol = AppTheme.border(context);
    final titleCol = AppTheme.textPrimaryColor(context);
    final subTextCol = AppTheme.textSecondaryColor(context);
    final iconCol = AppTheme.iconCol(context);

    String currentSong = widget.currentlyPlayingIndex != null &&
            widget.currentlyPlayingIndex! < widget.audioFiles.length
        ? widget.audioFiles[widget.currentlyPlayingIndex!].path
            .split(Platform.pathSeparator)
            .last
        : "No song playing";
    String? currentPath = widget.currentlyPlayingIndex != null &&
            widget.currentlyPlayingIndex! < widget.audioFiles.length
        ? widget.audioFiles[widget.currentlyPlayingIndex!].path
        : null;

    final primaryBtnBg =
        isDark ? Colors.white : AppTheme.lightPrimary;
    final primaryBtnIcon =
        isDark ? Colors.black : Colors.white;

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.only(
              left: 16.0, right: 16.0, top: 16.0, bottom: 100.0),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(24.0),
              border: Border.all(
                color: borderCol,
                width: 1,
              ),
              boxShadow: isDark
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(height: 10),
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: currentPath != null
                      ? ArtworkHelper.buildArtworkWidget(
                          currentPath,
                          width: 240,
                          height: 240,
                          borderRadius: 20.0,
                        )
                      : Container(
                          width: 240,
                          height: 240,
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF282828)
                                : const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(20.0),
                          ),
                          child: Icon(
                            Icons.music_note_rounded,
                            size: 90.0,
                            color: isDark ? Colors.white38 : Colors.grey.shade400,
                          ),
                        ),
                ),
                const SizedBox(height: 28.0),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: Text(
                    currentSong,
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: titleCol,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 4.0),
                Text(
                  widget.currentlyPlayingIndex != null
                      ? "Pocketo Play Audio"
                      : "Select a track to play",
                  style: TextStyle(
                    fontSize: 13,
                    color: subTextCol,
                  ),
                ),
                const SizedBox(height: 20.0),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 6.0),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 14.0),
                    activeTrackColor:
                        isDark ? Colors.white : AppTheme.lightPrimary,
                    inactiveTrackColor: isDark
                        ? Colors.white24
                        : const Color(0xFFCBD5E1),
                    thumbColor:
                        isDark ? Colors.white : AppTheme.lightPrimary,
                    overlayColor: isDark
                        ? Colors.white12
                        : AppTheme.lightPrimary.withValues(alpha: 0.15),
                    trackHeight: 3.5,
                  ),
                  child: Slider(
                    value: sliderValue.clamp(
                        0,
                        widget.duration.inSeconds.toDouble() > 0
                            ? widget.duration.inSeconds.toDouble()
                            : 0.0),
                    min: 0,
                    max: widget.duration.inSeconds.toDouble() > 0
                        ? widget.duration.inSeconds.toDouble()
                        : 1.0,
                    onChanged: (value) {
                      setState(() {
                        sliderValue = value;
                      });
                    },
                    onChangeEnd: seekAudio,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDuration(
                            Duration(seconds: sliderValue.toInt())),
                        style: TextStyle(color: subTextCol, fontSize: 12),
                      ),
                      Text(
                        _formatDuration(widget.duration),
                        style: TextStyle(color: subTextCol, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24.0),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: Icon(
                        widget.audioPlayer.loopMode == LoopMode.all
                            ? Icons.repeat_rounded
                            : widget.audioPlayer.loopMode == LoopMode.one
                                ? Icons.repeat_one_rounded
                                : Icons.shuffle_rounded,
                        size: 24,
                        color: widget.audioPlayer.loopMode != LoopMode.off
                            ? (isDark ? Colors.white : AppTheme.lightPrimary)
                            : (isDark ? Colors.white38 : Colors.grey.shade400),
                      ),
                      tooltip: 'Repeat / Shuffle',
                      onPressed: () {
                        if (widget.audioPlayer.loopMode == LoopMode.off) {
                          widget.audioPlayer.setLoopMode(LoopMode.all);
                          widget.audioPlayer.setShuffleModeEnabled(true);
                        } else if (widget.audioPlayer.loopMode ==
                            LoopMode.all) {
                          widget.audioPlayer.setLoopMode(LoopMode.one);
                          widget.audioPlayer.setShuffleModeEnabled(false);
                        } else {
                          widget.audioPlayer.setLoopMode(LoopMode.off);
                        }
                        setState(() {});
                      },
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.skip_previous_rounded,
                        size: 32,
                        color: iconCol,
                      ),
                      tooltip: 'Previous',
                      onPressed: onPreviousSong,
                    ),
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: primaryBtnBg,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: primaryBtnBg.withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: Icon(
                          widget.isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          size: 34,
                          color: primaryBtnIcon,
                        ),
                        onPressed: widget.currentlyPlayingIndex != null
                            ? () => widget.isPlaying
                                ? widget.onPause()
                                : widget.onPlay()
                            : null,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.skip_next_rounded,
                        size: 32,
                        color: iconCol,
                      ),
                      tooltip: 'Next',
                      onPressed: onNextSong,
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.queue_music_rounded,
                        size: 24,
                        color: isDark ? Colors.white60 : Colors.grey.shade600,
                      ),
                      tooltip: 'Song Queue',
                      onPressed: showSongSelectionSheet,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void onNextSong() {
    widget.onNext();
  }

  void onPreviousSong() {
    widget.onPrevious();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String hours = twoDigits(duration.inHours);
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return duration.inHours > 0
        ? "$hours:$minutes:$seconds"
        : "$minutes:$seconds";
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
