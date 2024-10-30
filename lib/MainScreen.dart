import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:music/HomeScreen.dart';
import 'package:music/PlayScreen.dart';
import 'package:music/ProfileScreen.dart';
import 'package:music/SearchScreen.dart';

class MainScreen extends StatefulWidget {
  final List<String> audioFiles;

  MainScreen({super.key, required this.audioFiles});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  int? _currentlyPlayingIndex;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isPlaying = false;
  bool _isRepeat = false;

  final AudioPlayer audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _setupAudioPlayer();
  }

  void _setupAudioPlayer() {
    audioPlayer.durationStream.listen((duration) {
      setState(() {
        _duration = duration ?? Duration.zero;
      });
    });
    audioPlayer.positionStream.listen((position) {
      setState(() {
        _position = position;
      });
    });
    audioPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed && !_isRepeat) {
        _nextTrack();
      }
    });
    audioPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed && _isRepeat) {
        _repeatTrack();
      }
    });
  }

  Future<void> playSong(int index) async {
    print("Playing song at index: $index");
    if (index < 0 || index >= widget.audioFiles.length) return;

    final path = widget.audioFiles[index];
    final metadata = _fetchMetadataFromPath(path);

    setState(() {
      print("Setting state");
      _currentlyPlayingIndex = index;
      _isPlaying = true;
    });

    await audioPlayer.setAudioSource(
      AudioSource.uri(
        Uri.file(path),
        tag: MediaItem(
          id: '$index',
          album: metadata['album'] ?? "Unknown Album",
          title: metadata['title'] ?? "Unknown Title",
          artist: metadata['artist'] ?? "Unknown Artist",
          artUri: Uri.parse('asset:///assets/music.png'),
        ),
      ),
    );
    await audioPlayer.play();
  }

  Future<void> play() async {
    if (_currentlyPlayingIndex != null) {
      setState(() {
        _isPlaying = true;
      });
      await audioPlayer.play();
    }
  }

  Future<void> pause() async {
    setState(() {
      _isPlaying = false;
    });
    await audioPlayer.pause();
  }

  Future<void> _nextTrack() async {
    int nextIndex = (_currentlyPlayingIndex ?? 0) + 1;
    if (nextIndex >= widget.audioFiles.length) nextIndex = 0;
    await playSong(nextIndex);
  }

  Future<void> _previousTrack() async {
    int previousIndex = (_currentlyPlayingIndex ?? 0) - 1;
    if (previousIndex < 0) previousIndex = widget.audioFiles.length - 1;
    await playSong(previousIndex);
  }

  void _toggleRepeat() {
    setState(() {
      _isRepeat = !_isRepeat;
    });
  }

  Map<String, String?> _fetchMetadataFromPath(String path) {
    final fileName = path.split(Platform.pathSeparator).last;
    final title = fileName.split('.').first;
    return {
      'title': title,
      'album': "Unknown Album",
      'artist': "Unknown Artist",
    };
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _repeatTrack() {
    if (_isRepeat && _currentlyPlayingIndex != null) {
      playSong(_currentlyPlayingIndex!);
    }
  }

  void _openSearchScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SearchScreen(
          audioFiles: widget.audioFiles.map((path) => File(path)).toList(),
          audioPlayer: audioPlayer,
          playTrack: playSong,
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    return duration.toString().split('.').first.padLeft(8, "0");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        title: const Text("Play Music", style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: _openSearchScreen,
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          HomeScreen(
            audioFiles: widget.audioFiles.map((path) => File(path)).toList(),
            audioPlayer: audioPlayer,
            currentlyPlayingIndex: _currentlyPlayingIndex,
            isPlaying: _isPlaying,
            onPlay: play,
            onPause: pause,
            duration: _duration,
            position: _position,
            onNext: _nextTrack,
            onPrevious: _previousTrack,
            playTrack: playSong,
          ),
          PlayScreen(
            audioFiles: widget.audioFiles.map((path) => File(path)).toList(),
            audioPlayer: audioPlayer,
            currentlyPlayingIndex: _currentlyPlayingIndex,
            isPlaying: _isPlaying,
            onPlay: play,
            onPause: pause,
            duration: _duration,
            position: _position,
            onNext: _nextTrack,
            onPrevious: _previousTrack,
            playTrack: playSong,
            toggleRepeat: _toggleRepeat,
            isRepeat: _isRepeat,
          ),
          ProfileScreen(
            audioFiles: widget.audioFiles.map((path) => File(path)).toList(),
            audioPlayer: audioPlayer,
            currentlyPlayingIndex: _currentlyPlayingIndex,
            isPlaying: _isPlaying,
            duration: _duration,
            position: _position,
            onPlay: play,
            onPause: pause,
            onNext: _nextTrack,
            onPrevious: _previousTrack,
            playTrack: playSong,
          ),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BottomNavigationBar(
            backgroundColor: Colors.deepPurple,
            currentIndex: _currentIndex,
            onTap: _onTabTapped,
            selectedItemColor: Colors.white,
            unselectedItemColor: const Color.fromARGB(255, 35, 35, 35),
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.play_circle_fill), label: 'Play'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.person), label: 'Profile'),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    audioPlayer.dispose();
    super.dispose();
  }
}
