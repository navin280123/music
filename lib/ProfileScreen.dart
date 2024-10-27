import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:url_launcher/url_launcher.dart';

class ProfileScreen extends StatefulWidget {
  final List<dynamic> audioFiles;
  final AudioPlayer audioPlayer;
  final int? currentlyPlayingIndex;
  final Duration duration;
  final Duration position;
  final bool isPlaying;
  final Function(int, String, bool, bool) onPlayOrPause;
  final bool isRepeat;

  const ProfileScreen({
    super.key,
    required this.audioFiles,
    required this.audioPlayer,
    required this.currentlyPlayingIndex,
    required this.duration,
    required this.position,
    required this.isPlaying,
    required this.onPlayOrPause,
    required this.isRepeat,
  });

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  double sliderValue = 0;
  bool showBottomSheet = true;

  @override
  void initState() {
    super.initState();
    widget.audioPlayer.positionStream.listen((position) {
      setState(() {
        sliderValue = position.inSeconds.toDouble();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.deepPurple,
      body: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: widget.isPlaying ? 80.0 : 0.0),
        child: Column(
          children: [
            _buildProfileHeader(),
            const SizedBox(height: 20),
            _buildDeveloperInfo(),
            _buildAboutApp(),
          ],
        ),
      ),
      bottomSheet: widget.isPlaying ? _buildNowPlayingBar() : null,
    );
  }

  Widget _buildProfileHeader() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Card(
            elevation: 6.0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15.0),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20.0),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 50.0,
                    backgroundImage: AssetImage('assets/profile.png'),
                  ),
                  const SizedBox(height: 12.0),
                  const Text(
                    "Developer's Profile",
                    style: TextStyle(
                      fontSize: 24.0,
                      fontWeight: FontWeight.w700,
                      color: Colors.deepPurple,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildSocialIcon(Icons.facebook, "Facebook"),
                      _buildSocialIcon(Icons.camera_alt, "Instagram"),
                      _buildSocialIcon(Icons.code, "GitHub"),
                      _buildSocialIcon(Icons.work, "LinkedIn"),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      final Uri emailLaunchUri = Uri(
                        scheme: 'mailto',
                        path: 'Kumarnavinverma7@gmail.com',
                        query: 'subject=App Feedback&body=Hello Navin,',
                      );

                      _launchUrl(emailLaunchUri);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20.0),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 25.0, vertical: 12.0),
                      child: const Text(
                        'Contact Developer',
                        style: TextStyle(fontSize: 16.0, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSocialIcon(IconData icon, String label) {
    return Column(
      children: [
        IconButton(
          icon: Icon(icon, color: Colors.deepPurple, size: 30),
          onPressed: () => _showDialog(label),
        ),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  void _showDialog(String platform) async {
    String url;
    switch (platform) {
      case "Facebook":
        url = "https://www.facebook.com/navin2801";
        break;
      case "Instagram":
        url = "https://www.instagram.com/navin.2801";
        break;
      case "GitHub":
        url = "https://github.com/navin280123";
        break;
      case "LinkedIn":
        url = "https://www.linkedin.com/in/navin-kumar-verma";
        break;
      default:
        url = "https://www.example.com";
    }

    await _launchUrl(Uri.parse(url));
  }

  Widget _buildDeveloperInfo() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Card(
        elevation: 6.0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15.0),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Developer Information",
                style: TextStyle(
                  fontSize: 20.0,
                  fontWeight: FontWeight.w700,
                  color: Colors.deepPurple,
                ),
              ),
              const Divider(color: Colors.deepPurpleAccent),
              const SizedBox(height: 8),
              _buildInfoRow(Icons.person, "Navin Kumar Verma"),
              _buildInfoRow(Icons.email, "Kumarnavinverma7@gmail.com"),
              _buildInfoRow(Icons.description,
                  "Flutter Developer with a passion for elegant applications."),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.deepPurple),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 16.0))),
        ],
      ),
    );
  }

  Widget _buildAboutApp() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Card(
        elevation: 6.0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15.0),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "About this App",
                style: TextStyle(
                  fontSize: 20.0,
                  fontWeight: FontWeight.w700,
                  color: Colors.deepPurple,
                ),
              ),
              const Divider(color: Colors.deepPurpleAccent),
              const SizedBox(height: 8),
              _buildInfoRow(Icons.apps, "App Name: Audio Player"),
              _buildInfoRow(Icons.verified, "Version: 1.0.0"),
              _buildInfoRow(Icons.description,
                  "This app allows you to play audio files and manage playback with a sleek UI."),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNowPlayingBar() {
    String currentSong =
        widget.audioFiles[widget.currentlyPlayingIndex!].path.split('/').last;

    return GestureDetector(
      onVerticalDragEnd: (details) {
        if (details.primaryVelocity! > 0) {
          onDownSwipe();
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.deepPurpleAccent,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20.0),
            topRight: Radius.circular(20.0),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        height: 70.0,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    currentSong,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16.0,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4.0),
                  Text(
                    "${_formatDuration(widget.position)} / ${_formatDuration(widget.duration)}",
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 12.0),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.skip_previous,
                color: Colors.white,
                size: 20.0,
              ),
              onPressed: onPreviousSong,
            ),
            IconButton(
              icon: Icon(
                widget.isPlaying
                    ? Icons.pause_circle_filled
                    : Icons.play_circle_fill,
                color: Colors.white,
                size: 30.0,
              ),
              onPressed: () => widget.onPlayOrPause(
                  widget.currentlyPlayingIndex!,
                  widget.audioFiles[widget.currentlyPlayingIndex!].path,
                  widget.isRepeat,
                  true),
            ),
            IconButton(
              icon: Icon(
                Icons.skip_next,
                color: Colors.white,
                size: 20.0,
              ),
              onPressed: onNextSong,
            ),
          ],
        ),
      ),
    );
  }

  void onNextSong() {
    if (widget.currentlyPlayingIndex != null) {
      int nextIndex =
          (widget.currentlyPlayingIndex! + 1) % widget.audioFiles.length;
      widget.onPlayOrPause(
          nextIndex, widget.audioFiles[nextIndex].path, widget.isRepeat, true);
    }
  }

  void onPreviousSong() {
    if (widget.currentlyPlayingIndex != null) {
      int prevIndex = widget.currentlyPlayingIndex! - 1;
      if (prevIndex < 0) prevIndex = widget.audioFiles.length - 1;
      widget.onPlayOrPause(
          prevIndex, widget.audioFiles[prevIndex].path, widget.isRepeat, true);
    }
  }

  void onDownSwipe() {
    if (widget.isPlaying) {
      widget.onPlayOrPause(
          widget.currentlyPlayingIndex!,
          widget.audioFiles[widget.currentlyPlayingIndex!].path,
          widget.isRepeat,
          true);
    }
    setState(() {
      showBottomSheet = false;
    });
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

  Future<void> _launchUrl(Uri url) async {
    if (!await launchUrl(url)) {
      throw Exception('Could not launch $url');
    }
  }
}
