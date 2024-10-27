import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:flutter_media_metadata/flutter_media_metadata.dart';
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
  }

  Future<void> _playOrPause(int index, String path, bool repeat, bool isClicked) async {
    if (repeat && !isClicked) {
      await _playNewTrack(index, path);
    } else if (_currentlyPlayingIndex == index && _isPlaying) {
      await audioPlayer.pause();
      setState(() {
        _isPlaying = false;
      });
    } else {
      if (_currentlyPlayingIndex != null && _currentlyPlayingIndex != index) {
        await audioPlayer.stop();
      }
      await _playNewTrack(index, path);
    }
  }

  Future<void> _playNewTrack(int index, String path) async {
    final metadata = await _fetchMetadata(path);

    await audioPlayer.setAudioSource(
      AudioSource.uri(
        Uri.file(path),
        tag: MediaItem(
          id: '$index',
          album: metadata.albumName ?? "Unknown Album",
          title: metadata.trackName ?? "Unknown Title",
          artist: metadata.authorName ?? "Unknown Artist",
          artUri: metadata.albumArt != null ? Uri.parse(Uri.dataFromBytes(metadata.albumArt!).toString()) : null,
        ),
      ),
    );
    await audioPlayer.play();
    setState(() {
      _currentlyPlayingIndex = index;
      _isPlaying = true;
    });
  }

  Future<Metadata> _fetchMetadata(String path) async {
    final metadataRetriever = MetadataRetriever();
    try {
      return await MetadataRetriever.fromFile(File(path));
    } catch (e) {
      print("Error retrieving metadata: $e");
      return Metadata(); // Return empty metadata if an error occurs
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
            isRepeat: _toggleRepeat,
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

  void _toggleRepeat(bool repeat) {
    setState(() {
      _isRepeat = repeat;
    });
  }

  @override
  void dispose() {
    audioPlayer.dispose();
    super.dispose();
  }
}
