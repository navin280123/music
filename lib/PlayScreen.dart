import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

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
  _PlayScreenState createState() => _PlayScreenState();
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
        duration: const Duration(milliseconds: 1000), vsync: this);
    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.0)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    widget.audioPlayer.positionStream.listen((position) {
      setState(() {
        sliderValue = position.inSeconds.toDouble();
      });
    });
    _updateAnimationState();
  }

  @override
  void didUpdateWidget(covariant PlayScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isPlaying != widget.isPlaying) _updateAnimationState();
  }

  void _updateAnimationState() {
    widget.isPlaying
        ? _controller.repeat(reverse: true)
        : _controller.animateTo(1.0,
            duration: const Duration(milliseconds: 1000),
            curve: Curves.easeOut);
  }

  void seekAudio(double seconds) {
    widget.audioPlayer.seek(Duration(seconds: seconds.toInt()));
  }

  void showSongSelectionSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.deepPurpleAccent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with title and close button
              Padding(
                padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Select a Song",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white30, thickness: 1),
              Expanded(
                child: ListView.builder(
                  itemCount: widget.audioFiles.length,
                  itemBuilder: (context, index) {
                    final songName =
                        widget.audioFiles[index].path.split('/').last;
                    return Column(
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () {
                            widget.playTrack(
                              index
                            );
                            Navigator.pop(context);
                          },
                          child: Card(
                            color: Colors.deepPurple,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 6.0),
                              child: ListTile(
                                leading: const Icon(Icons.music_note,
                                    color: Colors.white70),
                                title: Text(
                                  songName,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 16),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (index < widget.audioFiles.length - 1)
                          const Divider(
                            color: Colors.white24,
                            thickness: 0.5,
                            indent: 12,
                            endIndent: 12,
                          ),
                      ],
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
    String currentSong = widget.currentlyPlayingIndex != null
        ? widget.audioFiles[widget.currentlyPlayingIndex!].path.split('/').last
        : "No song playing";

    return Scaffold(
      backgroundColor: Colors.deepPurple,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            color: Colors.deepPurpleAccent,
            elevation: 8,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  AnimatedBuilder(
                    animation: _scaleAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _scaleAnimation.value,
                        child: Container(
                          width: 250,
                          height: 250,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: widget.isPlaying
                                ? const LinearGradient(
                                    colors: [
                                        Colors.deepPurple,
                                        Colors.purpleAccent,
                                      ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight)
                                : const LinearGradient(
                                    colors: [Colors.grey, Colors.black26],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight),
                          ),
                          child: Card(
                            shape: const CircleBorder(),
                            color: Colors.transparent,
                            elevation: 8,
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Icon(Icons.music_note_outlined,
                                  size: 150.0,
                                  color: widget.isPlaying
                                      ? Colors.white
                                      : Colors.black54),
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  const Spacer(),
                  // Slider and Play Row in a Column at the bottom
                  Column(
                    children: [
                      const SizedBox(height: 20.0),
                      Container(
                        margin: const EdgeInsets.fromLTRB(12, 0, 12, 15),
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          currentSong,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          thumbShape:
                              RoundSliderThumbShape(enabledThumbRadius: 8.0),
                          overlayShape:
                              RoundSliderOverlayShape(overlayRadius: 16.0),
                          activeTrackColor: Colors.purple,
                          inactiveTrackColor:
                              const Color.fromARGB(255, 255, 255, 255),
                          thumbColor: const Color.fromARGB(255, 0, 0, 0),
                          overlayColor: Colors.deepPurple.withAlpha(32),
                          trackHeight: 5.0,
                        ),
                        child: Slider(
                          value: sliderValue,
                          min: 0,
                          max: widget.duration.inSeconds.toDouble(),
                          onChanged: (value) {
                            setState(() {
                              sliderValue = value;
                            });
                          },
                          onChangeEnd: seekAudio,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatDuration(
                                  Duration(seconds: sliderValue.toInt())),
                              style: const TextStyle(color: Colors.white70),
                            ),
                            Text(
                              _formatDuration(widget.duration),
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20.0),
                      // Play button row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          IconButton(
                            icon: Icon(
                              widget.isRepeat ? Icons.repeat : Icons.shuffle,
                              size: MediaQuery.of(context).size.width * 0.06,
                              color: Colors.white,
                            ),
                            onPressed: () {
                              widget.toggleRepeat();
                            },
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.skip_previous,
                              size: MediaQuery.of(context).size.width * 0.08,
                              color: Colors.white,
                            ),
                            onPressed: onPreviousSong,
                          ),
                          IconButton(
                            icon: Icon(
                              widget.isPlaying
                                  ? Icons.pause_circle_filled
                                  : Icons.play_circle_fill,
                              size: MediaQuery.of(context).size.width * 0.12,
                              color: Colors.white,
                            ),
                            onPressed: widget.currentlyPlayingIndex != null
                                ? () => widget.isPlaying
                                    ? widget.onPause()
                                    : widget.onPlay()
                                : null,
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.skip_next,
                              size: MediaQuery.of(context).size.width * 0.08,
                              color: Colors.white,
                            ),
                            onPressed: onNextSong,
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.library_music,
                              size: MediaQuery.of(context).size.width * 0.06,
                              color: Colors.white,
                            ),
                            onPressed: showSongSelectionSheet,
                          ),
                        ],
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
