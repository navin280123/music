import 'package:audioplayers/audioplayers.dart' as audioPlayers;
import 'package:flutter/material.dart';
import 'package:music/HomeScreen.dart';
import 'package:music/PlayScreen.dart';
import 'package:music/ProfileScreen.dart';
import 'package:music/SearchScreen.dart';
import 'package:music/Notification.dart';
class MainScreen extends StatefulWidget {
  final List<dynamic>
      audioFiles; // List of audio files passed to the MainScreen
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

  void _isRepeatFunction(bool repeat) {
    setState(() {
      _isRepeat = repeat;
    });
  }
  void _playOrPause(int index, String path, bool repeat,bool isclicked) async {
    if(_isPlaying){
      print("Notification is called");
      NotificationServices().showNotification(
        id: 0,
        title: 'Music Player',
        body: 'Music Paused',
        payLoad: 'Music Paused',
      );
    }
    if (repeat&&!isclicked) {
      
      await audioPlayer.stop();
      await audioPlayer.play(audioPlayers.DeviceFileSource(path));
      setState(() {
        _currentlyPlayingIndex = index;
        _isPlaying = true;
      });
    } else {
      if (_currentlyPlayingIndex == index && _isPlaying) {
        await audioPlayer.pause();
        setState(() {
          _isPlaying = false;
        });
      } else {
        if (_currentlyPlayingIndex != null && _currentlyPlayingIndex == index) {
          await audioPlayer.resume();
        } else {
          if (_currentlyPlayingIndex != null) {
            await audioPlayer.stop();
          }
          await audioPlayer.play(audioPlayers.DeviceFileSource(path));
        }
        setState(() {
          _currentlyPlayingIndex = index;
          _isPlaying = true;
        });
      }
    }
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _openSearchScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SearchScreen(
          audioFiles: widget.audioFiles,
          onPlayOrPause: _playOrPause,
          audioPlayer: audioPlayer,
        ),
      ),
    );
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
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            iconSize: 30,
            color: Colors.white,
            padding: EdgeInsets.fromLTRB(0, 0, 20, 0),
            onPressed: _openSearchScreen,
          ),
        ],
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
            isRepeat: _isRepeat,
          ),
          PlayScreen(
            audioFiles: widget.audioFiles,
            audioPlayer: audioPlayer,
            currentlyPlayingIndex: _currentlyPlayingIndex,
            isPlaying: _isPlaying,
            duration: _duration,
            position: _position,
            onPlayOrPause: _playOrPause,
            isRepeat: _isRepeatFunction,
            isRepeating: _isRepeat,
          ),
          ProfileScreen(
            audioFiles: widget.audioFiles,
            audioPlayer: audioPlayer,
            currentlyPlayingIndex: _currentlyPlayingIndex,
            isPlaying: _isPlaying,
            duration: _duration,
            position: _position,
            onPlayOrPause: _playOrPause,
            isRepeat: _isRepeat,
          ),
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
