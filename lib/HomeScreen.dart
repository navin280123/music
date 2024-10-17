import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'package:external_path/external_path.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<FileSystemEntity> _musicFiles = [];

  @override
  void initState() {
    super.initState();
    _requestPermission();
  }

  // Request permission for storage
  Future<void> _requestPermission() async {
    if (await Permission.storage.request().isGranted) {
      _fetchMusicFiles();
    } else {
      print('Permission denied');
      // Handle permission denied
    }
  }

  // Fetch music files from internal and external directories
  Future<void> _fetchMusicFiles() async {
    List<FileSystemEntity> musicFiles = [];

    // Fetch music files from internal storage "Music" directory
    String internalMusicPath = await ExternalPath.getExternalStoragePublicDirectory(ExternalPath.DIRECTORY_MUSIC);
    musicFiles.addAll(_getMusicFilesFromDirectory(internalMusicPath));

    // Fetch files from the external SD card if available
    List<String> externalDirs = await ExternalPath.getExternalStorageDirectories();
    for (String dir in externalDirs) {
      musicFiles.addAll(_getMusicFilesFromDirectory(dir));
    }

    setState(() {
      _musicFiles = musicFiles;
    });
  }

  // Filter and fetch music files by their extensions
  List<FileSystemEntity> _getMusicFilesFromDirectory(String path) {
    Directory dir = Directory(path);
    List<FileSystemEntity> musicFiles = [];
    try {
      if (dir.existsSync()) {
        // List all files recursively and filter by extensions
        musicFiles = dir
            .listSync(recursive: true)
            .where((file) => file.path.endsWith('.mp3') || file.path.endsWith('.wav') || file.path.endsWith('.aac'))
            .toList();
      }
    } catch (e) {
      print('Error reading directory: $e');
    }
    return musicFiles;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Music Files'),
      ),
      body: _musicFiles.isEmpty
          ? const Center(child: Text('No music files found'))
          : ListView.builder(
              itemCount: _musicFiles.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(_musicFiles[index].path.split('/').last), // Display the file name
                  subtitle: Text(_musicFiles[index].path), // Display the file path
                  onTap: () {
                    // Optionally, handle file click, like playing the music file
                  },
                );
              },
            ),
    );
  }
}
