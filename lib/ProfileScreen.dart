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
  final Function() onPlay;
  final Function() onPause;
  final Function() onNext;
  final Function() onPrevious;
  final Function(int) playTrack;
  final Function(int) onTabTapped;

  const ProfileScreen({
    super.key,
    required this.audioFiles,
    required this.audioPlayer,
    required this.currentlyPlayingIndex,
    required this.duration,
    required this.position,
    required this.isPlaying,
    required this.onPlay,
    required this.onPause,
    required this.onNext,
    required this.onPrevious,
    required this.playTrack,
    required this.onTabTapped,
  });

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  double sliderValue = 0;
  bool showBottomSheet = false;

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
      backgroundColor: const Color(0xFF121212),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(
          bottom: 20.0,
          top: 12.0,
        ),
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            _buildProfileHeader(),
            const SizedBox(height: 16),
            _buildDeveloperInfo(),
            const SizedBox(height: 16),
            _buildAboutApp(),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(20.0),
          border: Border.all(
            color: const Color(0xFF2C2C2E),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white24,
                    width: 1.5,
                  ),
                ),
                child: const CircleAvatar(
                  radius: 46.0,
                  backgroundImage: AssetImage('assets/profile.png'),
                ),
              ),
              const SizedBox(height: 14.0),
              const Text(
                "Developer's Profile",
                style: TextStyle(
                  fontSize: 21.0,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4.0),
              const Text(
                "Pocketo Play Creator",
                style: TextStyle(
                  fontSize: 13.0,
                  color: Colors.white54,
                ),
              ),
              const SizedBox(height: 16),
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
                  backgroundColor: const Color(0xFF2C2C2E),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.0),
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24.0, vertical: 12.0),
                ),
                child: const Text(
                  'Contact Developer',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14.0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSocialIcon(IconData icon, String platform) {
    return GestureDetector(
      onTap: () => _showDialog(platform),
      child: Container(
        padding: const EdgeInsets.all(12.0),
        decoration: const BoxDecoration(
          color: Color(0xFF282828),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: Colors.white70,
          size: 22.0,
        ),
      ),
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
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(20.0),
          border: Border.all(
            color: const Color(0xFF2C2C2E),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Developer Information",
                style: TextStyle(
                  fontSize: 17.0,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Divider(color: Color(0xFF282828), height: 20),
              _buildInfoRow(Icons.person_rounded, "Navin Kumar Verma"),
              _buildInfoRow(Icons.email_rounded, "Kumarnavinverma7@gmail.com"),
              _buildInfoRow(Icons.description_rounded,
                  "Flutter Developer with a passion for elegant applications."),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14.0,
                color: Colors.white70,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutApp() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(20.0),
          border: Border.all(
            color: const Color(0xFF2C2C2E),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "About this App",
                style: TextStyle(
                  fontSize: 17.0,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Divider(color: Color(0xFF282828), height: 20),
              _buildInfoRow(Icons.apps_rounded, "App Name: Pocketo Play"),
              _buildInfoRow(Icons.verified_rounded, "Version: 1.0.0"),
              _buildInfoRow(Icons.description_rounded,
                  "This app allows you to play audio files and manage playback with a sleek UI."),
            ],
          ),
        ),
      ),
    );
  }



  Future<void> _launchUrl(Uri url) async {
    if (!await launchUrl(url)) {
      throw Exception('Could not launch $url');
    }
  }
}
