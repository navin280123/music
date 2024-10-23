import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
class HomeScreen extends StatefulWidget {
  final List<dynamic> audioFiles; // Receive audio files

  const HomeScreen({super.key, required this.audioFiles});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  AudioPlayer _audioPlayer = AudioPlayer();
  int? _currentlyPlayingIndex;

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

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
                return _buildMusicTile(widget.audioFiles[index], index);
              },
            ),
    );
  }

  Widget _buildMusicTile(FileSystemEntity file, int index) {
    String fileName = file.path.split('/').last; // Extract file name
    ImageProvider image = const AssetImage('assets/music.png'); // Default music icon
    bool isPlaying = _currentlyPlayingIndex == index;

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
              await _audioPlayer.pause();
              setState(() {
                _currentlyPlayingIndex = null;
              });
              // Remove notification when paused
              _removeNotification();
            } else {
              if (_currentlyPlayingIndex != null) {
                await _audioPlayer.stop();
              }
              await _audioPlayer.play(DeviceFileSource(file.path));
              setState(() {
                _currentlyPlayingIndex = index;
              });
              // Show notification when playing
              _showNotification(fileName);
            }
          },
        ),
      ),
    );
  }

  void _showNotification(String fileName) {
    

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

    void _showNotification(String fileName) async {
      const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
        'your_channel_id',
        'your_channel_name',
        channelDescription: 'your_channel_description',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: false,
      );
      const NotificationDetails platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);
      await flutterLocalNotificationsPlugin.show(
        0,
        'Now Playing',
        fileName,
        platformChannelSpecifics,
        payload: 'item x',
      );
    }

    @override
    void initState() {
      super.initState();
      const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('app_icon');
      const InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
      flutterLocalNotificationsPlugin.initialize(initializationSettings);
    }
  }

  void _removeNotification() {
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    flutterLocalNotificationsPlugin.cancel(0);
  }
}
