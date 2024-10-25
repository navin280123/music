// Profile tab content

import 'package:audioplayers/audioplayers.dart';
import 'package:audioplayers/src/audioplayer.dart' as audioplayers;
import 'package:flutter/material.dart';

class ProfileScreen extends StatefulWidget {
  final List<dynamic> audioFiles;
  final AudioPlayer audioPlayer;
  const ProfileScreen(
      {super.key, required this.audioFiles, required this.audioPlayer});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Profile Screen'),
      ),
      body: Center(
        child: Text(widget.audioPlayer.playerId.toString()),
      ),
    );
  }
}
