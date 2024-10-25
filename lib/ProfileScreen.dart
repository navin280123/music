import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

class ProfileScreen extends StatefulWidget {
  final List<dynamic> audioFiles;
  final AudioPlayer audioPlayer;
  final int? currentlyPlayingIndex;
  final Duration duration;
  final Duration position;
  final bool isPlaying;
  final Function(int, String) onPlayOrPause;

  const ProfileScreen({
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
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
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


  @override
  Widget build(BuildContext context) {
  return Scaffold(
    body: Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: widget.audioFiles.length,
            itemBuilder: (context, index) {
              return ListTile(
                title: Text("Profile Screen"),
                trailing: IconButton(
                  icon: Icon(
                    widget.currentlyPlayingIndex == index && widget.isPlaying
                        ? Icons.pause
                        : Icons.play_arrow,
                  ),
                  onPressed: () {
                    widget.onPlayOrPause(index, widget.audioFiles[index]['url']);
                  },
                ),
              );
            },
          ),
        ),
        Slider(
          value: sliderValue,
          min: 0,
          max: widget.duration.inSeconds.toDouble(),
          onChanged: (value) {
            setState(() {
              sliderValue = value;
              widget.audioPlayer.seek(Duration(seconds: value.toInt()));
            });
          },
        ),
        Text(
          '${widget.position.inMinutes}:${(widget.position.inSeconds % 60).toString().padLeft(2, '0')} / ${widget.duration.inMinutes}:${(widget.duration.inSeconds % 60).toString().padLeft(2, '0')}',
        ),
      ],
    ),
  );
  }

}
