import 'package:flutter/material.dart';
import 'dart:io';

import 'package:just_audio/just_audio.dart';

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

  const HomeScreen(
      {super.key,
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
      required this.onTabTapped});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool bottombar = false;
  @override
  void initState() {
    super.initState();
    // Add listener for when the audio completes
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0B1E),
      body: ListView.builder(
        padding: const EdgeInsets.only(
          bottom: 20.0,
          top: 12.0,
        ),
        physics: const BouncingScrollPhysics(),
        itemCount: widget.audioFiles.length,
        itemBuilder: (context, index) {
          return _buildMusicTile(widget.audioFiles[index], index);
        },
      ),
    );
  }

  Widget _buildMusicTile(FileSystemEntity file, int index) {
    String fileName = file.path.split('/').last;
    bool isPlayingCurrent =
        widget.currentlyPlayingIndex == index && widget.isPlaying;
    bool isCurrentSelected = widget.currentlyPlayingIndex == index;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 16.0),
      decoration: BoxDecoration(
        color: isCurrentSelected ? const Color(0xFF241548) : const Color(0xFF180F33),
        borderRadius: BorderRadius.circular(18.0),
        border: Border.all(
          color: isCurrentSelected
              ? const Color(0xFFC77DFF).withValues(alpha: 0.6)
              : Colors.white.withValues(alpha: 0.08),
          width: isCurrentSelected ? 1.5 : 1.0,
        ),
        boxShadow: isCurrentSelected
            ? [
                BoxShadow(
                  color: const Color(0xFF7B2CBF).withValues(alpha: 0.3),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(vertical: 4.0, horizontal: 14.0),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isPlayingCurrent
                  ? [const Color(0xFF9D4EDD), const Color(0xFFC77DFF)]
                  : [const Color(0xFF3C1670), const Color(0xFF5A189A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isPlayingCurrent ? Icons.graphic_eq_rounded : Icons.music_note_rounded,
            color: Colors.white,
            size: 22.0,
          ),
        ),
        title: Text(
          fileName,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: isCurrentSelected ? FontWeight.bold : FontWeight.w600,
            fontSize: 15.0,
            color: isCurrentSelected ? Colors.white : Colors.white.withValues(alpha: 0.9),
          ),
        ),
        subtitle: Text(
          "Audio Track",
          style: TextStyle(
            fontSize: 12.0,
            color: Colors.white.withValues(alpha: 0.5),
          ),
        ),
        onTap: () {
          widget.playTrack(index);
          setState(() {
            bottombar = true;
          });
        },
        trailing: Container(
          decoration: BoxDecoration(
            color: isPlayingCurrent
                ? const Color(0xFFC77DFF).withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.06),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(
              isPlayingCurrent
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
              color: isPlayingCurrent ? const Color(0xFFC77DFF) : Colors.white70,
              size: 26.0,
            ),
            onPressed: () {
              if (isPlayingCurrent) {
                widget.onPause();
              } else {
                widget.playTrack(index);
                setState(() {
                  bottombar = true;
                });
              }
            },
          ),
        ),
      ),
    );
  }


}
