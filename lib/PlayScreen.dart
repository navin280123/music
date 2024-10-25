import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

class PlayScreen extends StatefulWidget {
  final List<dynamic> audioFiles;
  final AudioPlayer audioPlayer;
  final int? currentlyPlayingIndex;
  final Duration duration;
  final Duration position;
  final bool isPlaying;
  final Function(int, String) onPlayOrPause;

  const PlayScreen({
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
  _PlayScreenState createState() => _PlayScreenState();
}

class _PlayScreenState extends State<PlayScreen> {
  double sliderValue = 0;

  @override
  void initState() {
    super.initState();
    widget.audioPlayer.onPositionChanged.listen((position) {
      setState(() {
        sliderValue = position.inSeconds.toDouble();
      });
    });
  }

  void seekAudio(double seconds) {
    widget.audioPlayer.seek(Duration(seconds: seconds.toInt()));
  }

  @override
  Widget build(BuildContext context) {
    String currentSong = widget.currentlyPlayingIndex != null
        ? widget.audioFiles[widget.currentlyPlayingIndex!].path.split('/').last
        : "No song playing";

    return Scaffold(
      backgroundColor: Colors.deepPurple, // Background color set to deep purple
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            color: Colors.deepPurpleAccent,
            elevation: 8,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                    Card(
                    shape: CircleBorder(),
                    color: const Color.fromARGB(255, 193, 186, 212),
                    elevation: 8,
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Icon(
                      Icons.music_note_outlined,
                      size: 200.0,
                      color: Colors.deepPurple,
                      ),
                    ),
                    ),
                  const SizedBox(height: 20.0),
                  Text(
                    currentSong,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: const Color.fromARGB(255, 255, 255, 255),
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 30.0),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Slider(
                          value: sliderValue,
                          min: 0,
                          max: widget.duration.inSeconds.toDouble(),
                          onChanged: (value) {
                            setState(() {
                              sliderValue = value;
                            });
                          },
                          onChangeEnd: (value) {
                            seekAudio(value);
                          },
                          activeColor: const Color.fromARGB(255, 175, 156, 208),
                          inactiveColor: Colors.deepPurple[100],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatDuration(
                                  Duration(seconds: sliderValue.toInt())),
                              style: const TextStyle(color: Colors.grey),
                            ),
                            Text(
                              _formatDuration(widget.duration),
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30.0),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.skip_previous,
                          size: 48.0,
                          color: Color.fromARGB(255, 255, 255, 255),
                        ),
                        onPressed: onPreviousSong,
                      ),
                      IconButton(
                        icon: Icon(
                          widget.isPlaying
                              ? Icons.pause_circle_filled
                              : Icons.play_circle_fill,
                          size: 64.0,
                          color: const Color.fromARGB(255, 255, 255, 255),
                        ),
                        onPressed: widget.currentlyPlayingIndex != null
                            ? () => widget.onPlayOrPause(
                                  widget.currentlyPlayingIndex!,
                                  widget
                                      .audioFiles[widget.currentlyPlayingIndex!]
                                      .path,
                                )
                            : null,
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.skip_next,
                          size: 48.0,
                          color: Color.fromARGB(255, 255, 255, 255),
                        ),
                        onPressed: onNextSong,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void onNextSong() {
    if (widget.currentlyPlayingIndex != null &&
        widget.currentlyPlayingIndex! < widget.audioFiles.length - 1) {
      widget.onPlayOrPause(
        widget.currentlyPlayingIndex! + 1,
        widget.audioFiles[widget.currentlyPlayingIndex! + 1].path,
      );
    }
  }

  void onPreviousSong() {
    if (widget.currentlyPlayingIndex != null &&
        widget.currentlyPlayingIndex! > 0) {
      widget.onPlayOrPause(
        widget.currentlyPlayingIndex! - 1,
        widget.audioFiles[widget.currentlyPlayingIndex! - 1].path,
      );
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
