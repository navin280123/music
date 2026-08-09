import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:music/ArtworkHelper.dart';
import 'package:music/PlaylistManager.dart';

class DriveModeScreen extends StatefulWidget {
  final List<dynamic> audioFiles;
  final AudioPlayer audioPlayer;
  final int? currentlyPlayingIndex;
  final bool isPlaying;
  final Function() onPlay;
  final Function() onPause;
  final Function() onNext;
  final Function() onPrevious;

  const DriveModeScreen({
    super.key,
    required this.audioFiles,
    required this.audioPlayer,
    required this.currentlyPlayingIndex,
    required this.isPlaying,
    required this.onPlay,
    required this.onPause,
    required this.onNext,
    required this.onPrevious,
  });

  @override
  State<DriveModeScreen> createState() => _DriveModeScreenState();
}

class _DriveModeScreenState extends State<DriveModeScreen> {
  @override
  void initState() {
    super.initState();
    // Keep device screen awake during Drive Mode
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentPath = widget.currentlyPlayingIndex != null &&
            widget.currentlyPlayingIndex! < widget.audioFiles.length
        ? widget.audioFiles[widget.currentlyPlayingIndex!].path
        : null;

    final songName = currentPath != null
        ? currentPath.split(Platform.pathSeparator).last
        : "No Track Playing";

    final isFav = currentPath != null && PlaylistManager.instance.isFavorite(currentPath);

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity != null) {
            if (details.primaryVelocity! < -300) {
              // Swipe Left -> Next
              HapticFeedback.mediumImpact();
              widget.onNext();
            } else if (details.primaryVelocity! > 300) {
              // Swipe Right -> Previous
              HapticFeedback.mediumImpact();
              widget.onPrevious();
            }
          }
        },
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Column(
              children: [
                // Top Exit & Car Mode Badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.directions_car_rounded, color: Color(0xFF38BDF8), size: 18),
                          SizedBox(width: 8),
                          Text(
                            "DRIVE MODE",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white, size: 32),
                      onPressed: () => Navigator.pop(context),
                      tooltip: "Exit Drive Mode",
                    ),
                  ],
                ),
                const Spacer(),

                // Center Album Art & Gestures
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    if (widget.isPlaying) {
                      widget.onPause();
                    } else {
                      widget.onPlay();
                    }
                  },
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 220,
                        height: 220,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF38BDF8).withValues(alpha: 0.2),
                              blurRadius: 30,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: currentPath != null
                            ? ArtworkHelper.buildArtworkWidget(
                                currentPath,
                                width: 220,
                                height: 220,
                                borderRadius: 24,
                              )
                            : Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E293B),
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: const Icon(
                                  Icons.music_note_rounded,
                                  size: 80,
                                  color: Colors.white54,
                                ),
                              ),
                      ),
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          widget.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          size: 48,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // Large Track Title
                Text(
                  songName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                const Text(
                  "Swipe Left/Right to Skip • Tap Center to Pause",
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),

                // Huge Oversized Controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Favorite Toggle
                    if (currentPath != null)
                      IconButton(
                        iconSize: 36,
                        icon: Icon(
                          isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          color: isFav ? const Color(0xFFF43F5E) : Colors.white70,
                        ),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          PlaylistManager.instance.toggleFavorite(currentPath);
                          setState(() {});
                        },
                      ),

                    // Previous Button
                    IconButton(
                      iconSize: 54,
                      icon: const Icon(Icons.skip_previous_rounded, color: Colors.white),
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        widget.onPrevious();
                      },
                    ),

                    // Big Play/Pause Button
                    Container(
                      width: 76,
                      height: 76,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        iconSize: 44,
                        icon: Icon(
                          widget.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          color: Colors.black,
                        ),
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          if (widget.isPlaying) {
                            widget.onPause();
                          } else {
                            widget.onPlay();
                          }
                        },
                      ),
                    ),

                    // Next Button
                    IconButton(
                      iconSize: 54,
                      icon: const Icon(Icons.skip_next_rounded, color: Colors.white),
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        widget.onNext();
                      },
                    ),

                    // Voice / Quick Mute
                    IconButton(
                      iconSize: 36,
                      icon: Icon(
                        widget.audioPlayer.volume > 0
                            ? Icons.volume_up_rounded
                            : Icons.volume_off_rounded,
                        color: Colors.white70,
                      ),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        if (widget.audioPlayer.volume > 0) {
                          widget.audioPlayer.setVolume(0.0);
                        } else {
                          widget.audioPlayer.setVolume(1.0);
                        }
                        setState(() {});
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
