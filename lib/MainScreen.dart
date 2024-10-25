import 'package:audioplayers/audioplayers.dart' as audioPlayers;
import 'package:flutter/material.dart';
import 'package:music/HomeScreen.dart';
import 'package:music/PlayScreen.dart';
import 'package:music/ProfileScreen.dart';

class MainScreen extends StatefulWidget {
  final List<dynamic> audioFiles; // List of audio files passed to the MainScreen
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
  
  final audioPlayers.AudioPlayer audioPlayer = audioPlayers.AudioPlayer();

  @override
  void initState() {
    super.initState();
    audioPlayer.onDurationChanged.listen((Duration duration) {
      setState(() {
        _duration = duration;
      });
    });
    audioPlayer.onPositionChanged.listen((Duration position) {
      setState(() {
        _position = position;
      });
    });
  }

  void _playOrPause(int index, String path) async {
    if (_currentlyPlayingIndex == index && _isPlaying) {
      await audioPlayer.pause();
      setState(() {
        _isPlaying = false;
      });
    } else {
      if (_currentlyPlayingIndex != null) {
        await audioPlayer.stop();
      }
      await audioPlayer.play(audioPlayers.DeviceFileSource(path));
      setState(() {
        _currentlyPlayingIndex = index;
        _isPlaying = true;
      });
    }
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        title: const Text(
          "Play Music",
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          HomeScreen(
            audioFiles: widget.audioFiles,
            audioPlayer: audioPlayer,
            currentlyPlayingIndex: _currentlyPlayingIndex,
            isPlaying: _isPlaying,
            duration: _duration,
            position: _position,
            onPlayOrPause: _playOrPause,
          ),
          PlayScreen(
            audioFiles: widget.audioFiles,
            audioPlayer: audioPlayer,
            currentlyPlayingIndex: _currentlyPlayingIndex,
            isPlaying: _isPlaying,
            duration: _duration,
            position: _position,
            onPlayOrPause: _playOrPause,
          ),
          ProfileScreen(audioFiles: widget.audioFiles, audioPlayer: audioPlayer),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.deepPurple,
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        selectedItemColor: Colors.white,
        unselectedItemColor: const Color.fromARGB(255, 35, 35, 35),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.play_circle_fill),
            label: 'Play',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
