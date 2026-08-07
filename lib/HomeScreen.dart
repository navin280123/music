import 'package:flutter/material.dart';
import 'dart:io';

import 'package:just_audio/just_audio.dart';
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
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: ListView.builder(
        padding: const EdgeInsets.only(
          bottom: 20.0,
          top: 8.0,
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
      margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 16.0),
      decoration: BoxDecoration(
        color: isCurrentSelected ? const Color(0xFF282828) : const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: isCurrentSelected
              ? Colors.white38
              : const Color(0xFF2C2C2E),
          width: 1.0,
        ),
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
            color: Colors.white,
          ),
        ),
        subtitle: Text(
          "Audio Track",
          style: const TextStyle(
            fontSize: 12.0,
            color: Colors.white54,
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
            color: Colors.white,
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
