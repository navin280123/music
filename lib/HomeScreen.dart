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
  final Function() onPlayOrPause;
  final Function() onNext;
  final Function() onPrevious;
  final Function(int) playTrack;

  const HomeScreen({
    super.key,
    required this.audioFiles,
    required this.audioPlayer,
    required this.currentlyPlayingIndex,
    required this.duration,
    required this.position,
    required this.isPlaying,
    required this.onPlayOrPause,
    required this.onNext,
    required this.onPrevious,
    required this.playTrack,
  });

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  @override
  void initState() {
    super.initState();
    // Add listener for when the audio completes
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.deepPurple,
      body: ListView.builder(
        padding: EdgeInsets.only(bottom: widget.isPlaying ? 70.0 : 0.0),
        itemCount: widget.audioFiles.length,
        itemBuilder: (context, index) {
          return _buildMusicTile(widget.audioFiles[index], index);
        },
      ),
      bottomSheet: widget.isPlaying ? _buildNowPlayingBar() : null,
    );
  }

  Widget _buildMusicTile(FileSystemEntity file, int index) {
    String fileName = file.path.split('/').last;
    bool isPlayingCurrent =
        widget.currentlyPlayingIndex == index && widget.isPlaying;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      elevation: 4.0,
      color: Colors.deepPurple[400],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
        leading: Icon(
          Icons.music_note,
          color: isPlayingCurrent ? Colors.pinkAccent : Colors.white70,
          size: 40.0,
        ),
        title: Text(
          fileName,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isPlayingCurrent ? Colors.white : Colors.white70,
          ),
        ),
        onTap: () {
          widget.onPlayOrPause();
        },
        trailing: IconButton(
          icon: Icon(isPlayingCurrent
              ? Icons.pause_circle_filled
              : Icons.play_circle_fill),
          color: isPlayingCurrent ? Colors.lightBlueAccent : Colors.white70,
          iconSize: 36.0,
          onPressed: () {
            widget.playTrack(index);
          },
        ),
      ),
    );
  }

  Widget _buildNowPlayingBar() {
    String currentSong =
        widget.audioFiles[widget.currentlyPlayingIndex!].path.split('/').last;

    return GestureDetector(
      onVerticalDragEnd: (details) {
        if (details.primaryVelocity! > 0) {
          onDownSwipe();
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.deepPurpleAccent,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20.0),
            topRight: Radius.circular(20.0),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        height: 70.0,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    currentSong,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16.0,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4.0),
                  Text(
                    "${_formatDuration(widget.position)} / ${_formatDuration(widget.duration)}",
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 12.0),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.skip_previous,
                color: Colors.white,
                size: 20.0,
              ),
              onPressed: onPreviousSong,
            ),
            IconButton(
              icon: Icon(
                widget.isPlaying
                    ? Icons.pause_circle_filled
                    : Icons.play_circle_fill,
                color: Colors.white,
                size: 30.0,
              ),
              onPressed: () => widget.onPlayOrPause(),
            ),
            IconButton(
              icon: Icon(
                Icons.skip_next,
                color: Colors.white,
                size: 20.0,
              ),
              onPressed: onNextSong,
            ),
          ],
        ),
      ),
    );
  }

  void onNextSong() {
    widget.onNext();
  }

  void onDownSwipe() {
    widget.onPlayOrPause();
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
}
