import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
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
                            widget.playTrack(index);
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
    String? currentPath = widget.currentlyPlayingIndex != null
        ? widget.audioFiles[widget.currentlyPlayingIndex!].path
        : null;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 16.0, bottom: 100.0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(24.0),
              border: Border.all(
                color: const Color(0xFF2C2C2E),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(height: 10),
                if (currentPath != null)
                  ArtworkHelper.buildArtworkWidget(
                    currentPath,
                    width: 240,
                    height: 240,
                    borderRadius: 18.0,
                  )
                else
                  Container(
                    width: 240,
                    height: 240,
                    decoration: BoxDecoration(
                      color: const Color(0xFF282828),
                      borderRadius: BorderRadius.circular(18.0),
                    ),
                    child: const Icon(
                      Icons.music_note_rounded,
                      size: 90.0,
                      color: Colors.white38,
                    ),
                  ),
                const SizedBox(height: 28.0),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: Text(
                    currentSong,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 4.0),
                Text(
                  widget.currentlyPlayingIndex != null ? "Pocketo Play Audio" : "Select a track to play",
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.white54,
                  ),
                ),
                const SizedBox(height: 20.0),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 14.0),
                    activeTrackColor: Colors.white,
                    inactiveTrackColor: Colors.white24,
                    thumbColor: Colors.white,
                    overlayColor: Colors.white12,
                    trackHeight: 3.5,
                  ),
                  child: Slider(
                    value: sliderValue.clamp(0, widget.duration.inSeconds.toDouble() > 0 ? widget.duration.inSeconds.toDouble() : 0.0),
                    min: 0,
                    max: widget.duration.inSeconds.toDouble() > 0 ? widget.duration.inSeconds.toDouble() : 1.0,
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
                        _formatDuration(Duration(seconds: sliderValue.toInt())),
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                      Text(
                        _formatDuration(widget.duration),
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
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
                            ? Colors.white
                            : Colors.white38,
                      ),
                      onPressed: () {
                        if (widget.audioPlayer.loopMode == LoopMode.off) {
                          widget.audioPlayer.setLoopMode(LoopMode.all);
                          widget.audioPlayer.setShuffleModeEnabled(true);
                        } else if (widget.audioPlayer.loopMode == LoopMode.all) {
                          widget.audioPlayer.setLoopMode(LoopMode.one);
                          widget.audioPlayer.setShuffleModeEnabled(false);
                        } else {
                          widget.audioPlayer.setLoopMode(LoopMode.off);
                        }
                        setState(() {});
                      },
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.skip_previous_rounded,
                        size: 32,
                        color: Colors.white,
                      ),
                      onPressed: onPreviousSong,
                    ),
                    Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: Icon(
                          widget.isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          size: 34,
                          color: Colors.black,
                        ),
                        onPressed: widget.currentlyPlayingIndex != null
                            ? () => widget.isPlaying
                                ? widget.onPause()
                                : widget.onPlay()
                            : null,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.skip_next_rounded,
                        size: 32,
                        color: Colors.white,
                      ),
                      onPressed: onNextSong,
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.queue_music_rounded,
                        size: 24,
                        color: Colors.white38,
                      ),
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
