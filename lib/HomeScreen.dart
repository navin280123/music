import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:io';

class HomeScreen extends StatefulWidget {
  final List<dynamic> audioFiles;

  const HomeScreen({super.key, required this.audioFiles});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  AudioPlayer _audioPlayer = AudioPlayer();
  int? _currentlyPlayingIndex;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _audioPlayer.onDurationChanged.listen((Duration duration) {
      setState(() {
        _duration = duration;
      });
    });
    _audioPlayer.onPositionChanged.listen((Duration position) {
      setState(() {
        _position = position;
      });
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            color: Colors.deepPurple,
            child: widget.audioFiles.isEmpty
                ? const Center(
                    child: Text(
                      'No music files found',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.only(
                        bottom: _currentlyPlayingIndex != null ? 80.0 : 0.0),
                    itemCount: widget.audioFiles.length,
                    itemBuilder: (context, index) {
                      return _buildMusicTile(widget.audioFiles[index], index);
                    },
                  ),
          ),
          if (_currentlyPlayingIndex != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildMusicControlCard(),
            ),
        ],
      ),
    );
  }

  Widget _buildMusicTile(FileSystemEntity file, int index) {
    String fileName = file.path.split('/').last;
    ImageProvider image = const AssetImage('assets/music.png');
    bool isPlaying = _currentlyPlayingIndex == index;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      color: Colors.deepPurple[300],
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
        leading: ClipOval(
          child: Image(image: image, width: 50, height: 50, fit: BoxFit.cover),
        ),
        title: Text(
          fileName,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.white,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        onTap: () => _playOrPause(index, file.path, isPlaying),
        trailing: IconButton(
          icon: Icon(
            isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
            color: Colors.deepPurple,
          ),
          iconSize: 30,
          onPressed: () => _playOrPause(index, file.path, isPlaying),
        ),
      ),
    );
  }

  void _playOrPause(int index, String path, bool isPlaying) async {
    if (isPlaying) {
      await _audioPlayer.pause();
      setState(() {
        _currentlyPlayingIndex = null;
        _isPlaying = false;
      });
    } else {
      if (_currentlyPlayingIndex != null) {
        await _audioPlayer.stop();
      }
      await _audioPlayer.play(DeviceFileSource(path));
      setState(() {
        _currentlyPlayingIndex = index;
        _isPlaying = true;
      });
    }
  }

  Widget _buildMusicControlCard() {
    String fileName =
        widget.audioFiles[_currentlyPlayingIndex!].path.split('/').last;

    return GestureDetector(
      onVerticalDragEnd: (details) {
        if (details.velocity.pixelsPerSecond.dy > 0) {
          _stopPlayback(); // Stop the playback when swiped down
        }
      },
      child: Dismissible(
        key: Key(fileName),
        confirmDismiss: (DismissDirection direction) async {
          // Handle swipe left and right for track control
          if (direction == DismissDirection.startToEnd) {
            _playPrevious();
          } else if (direction == DismissDirection.endToStart) {
            _playNext();
          }
          return false; // Prevent dismissal of widget
        },
        child: Card(
          margin: const EdgeInsets.all(0),
          color: Colors.deepPurpleAccent[200],
          elevation: 10,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const SizedBox(
                        width: 10), 
                    Expanded(
                      child: Text(
                        fileName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis, // Truncate long text
                        maxLines: 1, // Limit to a single line
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.skip_previous,
                          size: 20, color: Colors.white),
                      onPressed: _playPrevious,
                    ),
                    IconButton(
                      icon: Icon(
                        _isPlaying
                            ? Icons.pause_circle_filled
                            : Icons.play_circle_filled,
                        size: 30,
                        color: Colors.white,
                      ),
                      onPressed: () {
                        setState(() {
                          if (_isPlaying) {
                            _audioPlayer.pause();
                          } else {
                            _audioPlayer.resume();
                          }
                          _isPlaying = !_isPlaying;
                        });
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.skip_next,
                          size: 20, color: Colors.white),
                      onPressed: _playNext,
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

 

  void _playNext() async {
    if (_currentlyPlayingIndex != null &&
        _currentlyPlayingIndex! < widget.audioFiles.length - 1) {
      await _audioPlayer.stop();
      setState(() {
        _currentlyPlayingIndex = _currentlyPlayingIndex! + 1;
      });
      await _audioPlayer.play(
          DeviceFileSource(widget.audioFiles[_currentlyPlayingIndex!].path));
    }
  }

  void _playPrevious() async {
    if (_currentlyPlayingIndex != null && _currentlyPlayingIndex! > 0) {
      await _audioPlayer.stop();
      setState(() {
        _currentlyPlayingIndex = _currentlyPlayingIndex! - 1;
      });
      await _audioPlayer.play(
          DeviceFileSource(widget.audioFiles[_currentlyPlayingIndex!].path));
    }
  }

  void _stopPlayback() async {
    await _audioPlayer.stop();
    setState(() {
      _currentlyPlayingIndex = null;
      _isPlaying = false;
    });
  }
}
