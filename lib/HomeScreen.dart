import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:io';

class HomeScreen extends StatefulWidget {
  final List<dynamic> audioFiles;
  final AudioPlayer audioPlayer;
  final int? currentlyPlayingIndex;
  final Duration duration;
  final Duration position;
  final bool isPlaying;
  final Function(int, String) onPlayOrPause;

  const HomeScreen({
    super.key,
    required this.audioFiles,
    required this.audioPlayer,
    required this.currentlyPlayingIndex,
    required this.duration,
    required this.position,
    required this.isPlaying,
    required this.onPlayOrPause,
  });

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool showBottomSheet = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.deepPurple, // Set the background color here
      body: ListView.builder(
        padding: EdgeInsets.only(
            bottom: widget.currentlyPlayingIndex != null ? 70.0 : 0.0),
        itemCount: widget.audioFiles.length,
        itemBuilder: (context, index) {
          return _buildMusicTile(widget.audioFiles[index], index);
        },
      ),
      bottomSheet: widget.isPlaying 
          ? _buildNowPlayingBar()
          : null,
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
          overflow:
              TextOverflow.ellipsis, // Ensure filename is displayed in one line
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isPlayingCurrent ? Colors.white : Colors.white70,
          ),
        ),
        onTap: () {
          widget.onPlayOrPause(index, file.path);
          setState(() {
            showBottomSheet = true;
          });
        },
        trailing: IconButton(
          icon: Icon(isPlayingCurrent
              ? Icons.pause_circle_filled
              : Icons.play_circle_fill),
          color: isPlayingCurrent ? Colors.lightBlueAccent : Colors.white70,
          iconSize: 36.0,
          onPressed: () {
            widget.onPlayOrPause(index, file.path);
            setState(() {
              showBottomSheet = true;
            });
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
          // Swiped down, hide the bottom sheet
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
                mainAxisAlignment:
                    MainAxisAlignment.center, // Center vertically
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
              onPressed: () => widget.onPlayOrPause(
                  widget.currentlyPlayingIndex!,
                  widget.audioFiles[widget.currentlyPlayingIndex!].path),
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
    // Logic for moving to the next song
    if (widget.currentlyPlayingIndex != null &&
        widget.currentlyPlayingIndex! < widget.audioFiles.length - 1) {
      widget.onPlayOrPause(widget.currentlyPlayingIndex! + 1,
          widget.audioFiles[widget.currentlyPlayingIndex! + 1].path);
    }
  }

  void onDownSwipe() {
    if(widget.isPlaying){
      widget.onPlayOrPause(widget.currentlyPlayingIndex!,
        widget.audioFiles[widget.currentlyPlayingIndex!].path);
    }
    setState(() {
      showBottomSheet = false;
    });
  }

  void onPreviousSong() {
    // Logic for moving to the previous song
    if (widget.currentlyPlayingIndex != null &&
        widget.currentlyPlayingIndex! > 0) {
      widget.onPlayOrPause(widget.currentlyPlayingIndex! - 1,
          widget.audioFiles[widget.currentlyPlayingIndex! - 1].path);
    }
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
