import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:io';

class HomeScreen extends StatefulWidget {
  final List<dynamic> audioFiles; // Receive audio files

  const HomeScreen({super.key, required this.audioFiles});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.audioFiles.isEmpty
          ? const Center(
              child: Text(
                'No music files found',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            )
          : ListView.builder(
              itemCount: widget.audioFiles.length,
              itemBuilder: (context, index) {
                return _buildMusicTile(widget.audioFiles[index]);
              },
            ),
    );
  }

  Widget _buildMusicTile(FileSystemEntity file) {
    String fileName = file.path.split('/').last; // Extract file name
    ImageProvider image = const AssetImage('assets/music.png'); // Default music icon
    bool isPlaying = false; // Track if the song is playing
    AudioPlayer audioPlayer = AudioPlayer();

    return StatefulBuilder(
      builder: (context, setState) {
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          color: Colors.purple[100], // Lavender color for the card background
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
            leading: ClipOval(
              child: Image(image: image, width: 50, height: 50, fit: BoxFit.cover),
            ),
            title: Text(
              fileName,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.deepPurple, // Lavender theme color
              ),
              overflow: TextOverflow.ellipsis, // Add ellipsis for long titles
              maxLines: 1, // Limit to a single line
            ),
            trailing: IconButton(
              icon: Icon(isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled, color: Colors.deepPurple),
              iconSize: 30,
              onPressed: () async {
                if (isPlaying) {
                  await audioPlayer.pause();
                } else {
                  await audioPlayer.play(DeviceFileSource(file.path));
                }
                setState(() {
                  isPlaying = !isPlaying;
                });
              },
            ),
          ),
        );
      },
    );
  }
}
