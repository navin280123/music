import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

class ProfileScreen extends StatefulWidget {
  final List<dynamic> audioFiles;
  final AudioPlayer audioPlayer;
  final int? currentlyPlayingIndex;
  final Duration duration;
  final Duration position;
  final bool isPlaying;
  final Function(int, String,bool,bool) onPlayOrPause;
  final bool isRepeat;

  const ProfileScreen({
    super.key,
    required this.audioFiles,
    required this.audioPlayer,
    required this.currentlyPlayingIndex,
    required this.duration,
    required this.position,
    required this.isPlaying,
    required this.onPlayOrPause,
    required this.isRepeat,
  });

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  double sliderValue = 0;
  bool showBottomSheet = true;
  @override
  void initState() {
    super.initState();
    widget.audioPlayer.onPositionChanged.listen((position) {
      setState(() {
        sliderValue = position.inSeconds.toDouble();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomSheet: widget.isPlaying
          ? _buildNowPlayingBar()
          : null,
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
                  widget.audioFiles[widget.currentlyPlayingIndex!].path,widget.isRepeat,true),
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
    if (widget.currentlyPlayingIndex != null &&
        widget.currentlyPlayingIndex! < widget.audioFiles.length - 1) {
      widget.onPlayOrPause(
        widget.currentlyPlayingIndex! + 1,
        widget.audioFiles[widget.currentlyPlayingIndex! + 1].path,widget.isRepeat,true
      );
    }
  }

  void onPreviousSong() {
    if (widget.currentlyPlayingIndex != null &&
        widget.currentlyPlayingIndex! > 0) {
      widget.onPlayOrPause(
        widget.currentlyPlayingIndex! - 1,
        widget.audioFiles[widget.currentlyPlayingIndex! - 1].path,widget.isRepeat,true
      );
    }
  }
  void onDownSwipe() {
    if(widget.isPlaying){
      widget.onPlayOrPause(widget.currentlyPlayingIndex!,
        widget.audioFiles[widget.currentlyPlayingIndex!].path,widget.isRepeat,true);
    }
    setState(() {
      showBottomSheet = false;
    });
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
