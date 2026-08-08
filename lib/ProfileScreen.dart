import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:music/AppTheme.dart';
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
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final scaffoldBg = isDark ? AppTheme.darkScaffold : AppTheme.lightScaffold;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        title: Text(
          "Developer Profile",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimaryColor(context),
          ),
        ),
        centerTitle: true,
        backgroundColor: AppTheme.headerBg(context),
        iconTheme: IconThemeData(color: AppTheme.textPrimaryColor(context)),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(
          bottom: 24.0,
          top: 12.0,
        ),
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            _buildProfileHeader(context),
            const SizedBox(height: 16),
            _buildDeveloperInfo(context),
            const SizedBox(height: 16),
            _buildAboutApp(context),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final cardBg = AppTheme.cardBg(context);
    final borderCol = AppTheme.border(context);
    final titleCol = AppTheme.textPrimaryColor(context);
    final subTextCol = AppTheme.textSecondaryColor(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20.0),
          border: Border.all(
            color: borderCol,
            width: 1,
          ),
          boxShadow: isDark
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark ? Colors.white24 : AppTheme.lightPrimary.withValues(alpha: 0.4),
                    width: 2.0,
                  ),
                ),
                child: const CircleAvatar(
                  radius: 46.0,
                  backgroundImage: AssetImage('assets/profile.png'),
                ),
              ),
              const SizedBox(height: 14.0),
              Text(
                "Navin Kumar Verma",
                style: TextStyle(
                  fontSize: 21.0,
                  fontWeight: FontWeight.bold,
                  color: titleCol,
                ),
              ),
              const SizedBox(height: 4.0),
              Text(
                "Pocketo Play Creator",
                style: TextStyle(
                  fontSize: 13.0,
                  color: subTextCol,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildSocialIcon(context, Icons.facebook, "Facebook"),
                  _buildSocialIcon(context, Icons.camera_alt, "Instagram"),
                  _buildSocialIcon(context, Icons.code_rounded, "GitHub"),
                  _buildSocialIcon(context, Icons.work_rounded, "LinkedIn"),
                ],
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  final Uri emailLaunchUri = Uri(
                    scheme: 'mailto',
                    path: 'Kumarnavinverma7@gmail.com',
                    query: 'subject=App Feedback&body=Hello Navin,',
                  );

                  _launchUrl(emailLaunchUri);
                },
                icon: const Icon(Icons.email_outlined, size: 18),
                label: const Text('Contact Developer'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark
                      ? const Color(0xFF2C2C2E)
                      : AppTheme.lightPrimary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.0),
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24.0, vertical: 12.0),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSocialIcon(
      BuildContext context, IconData icon, String platform) {
    final isDark = AppTheme.isDark(context);
    final btnBg = isDark ? const Color(0xFF282828) : const Color(0xFFF1F5F9);
    final iconCol =
        isDark ? Colors.white70 : const Color(0xFF334155);

    return InkWell(
      onTap: () => _openPlatformUrl(platform),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: btnBg,
          shape: BoxShape.circle,
          border: Border.all(color: AppTheme.border(context)),
        ),
        child: Icon(
          icon,
          color: iconCol,
          size: 22.0,
        ),
      ),
    );
  }

  void _openPlatformUrl(String platform) async {
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
        url = "https://github.com/navin280123";
    }

    try {
      await _launchUrl(Uri.parse(url));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Could not open $platform link")),
        );
      }
    }
  }

  Widget _buildDeveloperInfo(BuildContext context) {
    final cardBg = AppTheme.cardBg(context);
    final borderCol = AppTheme.border(context);
    final titleCol = AppTheme.textPrimaryColor(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20.0),
          border: Border.all(
            color: borderCol,
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Developer Information",
                style: TextStyle(
                  fontSize: 17.0,
                  fontWeight: FontWeight.bold,
                  color: titleCol,
                ),
              ),
              Divider(color: borderCol, height: 20),
              _buildInfoRow(context, Icons.person_rounded, "Navin Kumar Verma"),
              _buildInfoRow(
                  context, Icons.email_rounded, "Kumarnavinverma7@gmail.com"),
              _buildInfoRow(context, Icons.description_rounded,
                  "Flutter Developer passionate about crafting clean and responsive audio applications."),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, IconData icon, String text) {
    final isDark = AppTheme.isDark(context);
    final iconCol =
        isDark ? Colors.white70 : const Color(0xFF475569);
    final textCol = AppTheme.textSecondaryColor(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconCol, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14.0,
                color: textCol,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutApp(BuildContext context) {
    final cardBg = AppTheme.cardBg(context);
    final borderCol = AppTheme.border(context);
    final titleCol = AppTheme.textPrimaryColor(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20.0),
          border: Border.all(
            color: borderCol,
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "About this App",
                style: TextStyle(
                  fontSize: 17.0,
                  fontWeight: FontWeight.bold,
                  color: titleCol,
                ),
              ),
              Divider(color: borderCol, height: 20),
              _buildInfoRow(
                  context, Icons.apps_rounded, "App Name: Pocketo Play"),
              _buildInfoRow(context, Icons.verified_rounded, "Version: 1.0.0"),
              _buildInfoRow(context, Icons.music_note_rounded,
                  "Local audio playback with background audio service, metadata extraction, search, and theme personalization."),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _launchUrl(Uri url) async {
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }
}
