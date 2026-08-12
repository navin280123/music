import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:music/AppSettings.dart';
import 'package:music/AppTheme.dart';
import 'package:music/ArtworkHelper.dart';
import 'package:music/CastService.dart';
import 'package:music/CastSheet.dart';
import 'package:music/EqualizerPresetSheet.dart';
import 'package:music/MediaCacheService.dart';
import 'package:music/ProfileScreen.dart';
import 'package:music/SleepTimerService.dart';

class SettingsScreen extends StatefulWidget {
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
  final Future<void> Function()? onRescan;

  const SettingsScreen({
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
    this.onRescan,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isRescanning = false;

  Future<void> _handleRescan() async {
    if (_isRescanning) return;

    setState(() {
      _isRescanning = true;
    });

    try {
      if (widget.onRescan != null) {
        await widget.onRescan!();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Library updated! ${widget.audioFiles.length} audio tracks found.",
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error scanning library: $e"),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRescanning = false;
        });
      }
    }
  }

  void _handleClearCache() {
    ArtworkHelper.clearCache();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.cleaning_services_rounded, color: Colors.white, size: 20),
            SizedBox(width: 10),
            Text("Artwork memory cache cleared successfully."),
          ],
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final scaffoldBg = isDark ? AppTheme.darkScaffold : AppTheme.lightScaffold;

    return ListenableBuilder(
      listenable: AppSettings.instance,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: scaffoldBg,
          body: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 30.0, top: 12.0),
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                _buildHeaderCard(context),
                const SizedBox(height: 16),
                _buildSoundAndTimerSettings(context),
                const SizedBox(height: 16),
                _buildThemeSettings(context),
                const SizedBox(height: 16),
                _buildPlaybackSettings(context),
                const SizedBox(height: 16),
                _buildLibrarySettings(context),
                const SizedBox(height: 16),
                _buildAboutCard(context),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSoundAndTimerSettings(BuildContext context) {
    final cardBg = AppTheme.cardBg(context);
    final borderCol = AppTheme.border(context);
    final titleCol = AppTheme.textPrimaryColor(context);

    return ListenableBuilder(
      listenable: SleepTimerService.instance,
      builder: (context, _) {
        final timer = SleepTimerService.instance;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20.0),
              border: Border.all(color: borderCol, width: 1),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Audio Enhancements & Timer",
                    style: TextStyle(
                      fontSize: 16.0,
                      fontWeight: FontWeight.bold,
                      color: titleCol,
                    ),
                  ),
                  Divider(color: borderCol, height: 20),
                  _buildActionTile(
                    context: context,
                    icon: Icons.tune_rounded,
                    title: "Sound & Equalizer Presets",
                    subtitle: "Adjust playback speed, pitch, and audio profiles",
                    trailingText: "Configure",
                    onTap: () {
                      EqualizerPresetSheet.show(context, widget.audioPlayer);
                    },
                  ),
                  Divider(color: borderCol, height: 12),
                  _buildActionTile(
                    context: context,
                    icon: Icons.bedtime_rounded,
                    title: "Sleep Timer",
                    subtitle: timer.isActive
                        ? "Active (${timer.formattedRemainingTime} remaining)"
                        : "Turn off playback automatically with gentle fade",
                    trailingText: timer.isActive ? "Active" : "Set Timer",
                    onTap: () {
                      _showSleepTimerDialog(context);
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showSleepTimerDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = AppTheme.isDark(context);
        final sheetBg = isDark ? const Color(0xFF1E1E20) : Colors.white;
        final textCol = isDark ? Colors.white : const Color(0xFF0F172A);
        final subTextCol = isDark ? Colors.white54 : const Color(0xFF64748B);
        final activeCol = isDark ? const Color(0xFF818CF8) : AppTheme.lightPrimary;

        return ListenableBuilder(
          listenable: SleepTimerService.instance,
          builder: (context, _) {
            final timerService = SleepTimerService.instance;

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: sheetBg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: activeCol.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.bedtime_rounded, color: activeCol, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Sleep Timer",
                                style: TextStyle(
                                  color: textCol,
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                timerService.isActive
                                    ? "Active: ${timerService.formattedRemainingTime}"
                                    : "Stops playback with gentle fade-out",
                                style: TextStyle(
                                  color: timerService.isActive ? activeCol : subTextCol,
                                  fontSize: 12,
                                  fontWeight: timerService.isActive
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (timerService.isActive)
                        TextButton(
                          onPressed: () {
                            timerService.cancelTimer(widget.audioPlayer);
                            Navigator.pop(context);
                          },
                          child: const Text("Turn Off", style: TextStyle(color: Colors.redAccent)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [15, 30, 45, 60].map((mins) {
                      return ElevatedButton(
                        onPressed: () {
                          timerService.startTimer(mins, widget.audioPlayer);
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Sleep timer set for $mins minutes"),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark ? const Color(0xFF28282A) : const Color(0xFFF1F5F9),
                          foregroundColor: textCol,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text("$mins min"),
                      );
                    }).toList()
                      ..add(
                        ElevatedButton(
                          onPressed: () {
                            timerService.setEndOfTrackMode(widget.audioPlayer);
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Sleep timer will stop at the end of this track"),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: activeCol.withValues(alpha: 0.2),
                            foregroundColor: activeCol,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text("End of Track"),
                        ),
                      ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHeaderCard(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final cardBg = AppTheme.cardBg(context);
    final borderCol = AppTheme.border(context);
    final titleCol = AppTheme.textPrimaryColor(context);
    final subTextCol = AppTheme.textSecondaryColor(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Container(
        padding: const EdgeInsets.all(18.0),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20.0),
          border: Border.all(
            color: borderCol,
            width: 1,
          ),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF282828)
                    : const Color(0xFFEEF2FF),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.settings_rounded,
                color: isDark ? Colors.white : AppTheme.lightPrimary,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "App Settings",
                    style: TextStyle(
                      fontSize: 18.0,
                      fontWeight: FontWeight.bold,
                      color: titleCol,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "Customize playback, theme & preferences",
                    style: TextStyle(
                      fontSize: 12.5,
                      color: subTextCol,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeSettings(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final cardBg = AppTheme.cardBg(context);
    final borderCol = AppTheme.border(context);
    final titleCol = AppTheme.textPrimaryColor(context);
    final subTextCol = AppTheme.textSecondaryColor(context);
    final currentMode = AppSettings.instance.themeMode;

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
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.palette_rounded,
                    size: 20,
                    color: isDark ? Colors.white70 : AppTheme.lightPrimary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "Appearance & Theme",
                    style: TextStyle(
                      fontSize: 16.0,
                      fontWeight: FontWeight.bold,
                      color: titleCol,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                "Choose how Pocketo Play looks to you",
                style: TextStyle(
                  fontSize: 12.0,
                  color: subTextCol,
                ),
              ),
              Divider(color: borderCol, height: 20),
              Row(
                children: [
                  Expanded(
                    child: _buildThemeOption(
                      context: context,
                      title: "Light",
                      mode: ThemeMode.light,
                      icon: Icons.light_mode_rounded,
                      isSelected: currentMode == ThemeMode.light,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildThemeOption(
                      context: context,
                      title: "Dark",
                      mode: ThemeMode.dark,
                      icon: Icons.dark_mode_rounded,
                      isSelected: currentMode == ThemeMode.dark,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildThemeOption(
                      context: context,
                      title: "System",
                      mode: ThemeMode.system,
                      icon: Icons.brightness_auto_rounded,
                      isSelected: currentMode == ThemeMode.system,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThemeOption({
    required BuildContext context,
    required String title,
    required ThemeMode mode,
    required IconData icon,
    required bool isSelected,
  }) {
    final isDark = AppTheme.isDark(context);
    final activeBg = isDark
        ? const Color(0xFF323236)
        : const Color(0xFFEEF2FF);
    final inactiveBg = isDark
        ? const Color(0xFF242426)
        : const Color(0xFFF8FAFC);
    final activeBorder = isDark
        ? Colors.white54
        : AppTheme.lightPrimary;
    final inactiveBorder = AppTheme.border(context);
    final textCol = isSelected
        ? (isDark ? Colors.white : AppTheme.lightPrimary)
        : AppTheme.textSecondaryColor(context);

    return InkWell(
      onTap: () {
        AppSettings.instance.setThemeMode(mode);
      },
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 8.0),
        decoration: BoxDecoration(
          color: isSelected ? activeBg : inactiveBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? activeBorder : inactiveBorder,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 24,
              color: isSelected
                  ? (isDark ? Colors.white : AppTheme.lightPrimary)
                  : AppTheme.textSecondaryColor(context),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: textCol,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaybackSettings(BuildContext context) {
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
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Playback Settings",
                style: TextStyle(
                  fontSize: 16.0,
                  fontWeight: FontWeight.bold,
                  color: titleCol,
                ),
              ),
              Divider(color: borderCol, height: 20),
              _buildSwitchTile(
                context: context,
                icon: Icons.skip_next_rounded,
                title: "Auto-play Next Track",
                subtitle: "Automatically play next track when song finishes",
                value: AppSettings.instance.autoPlayNext,
                onChanged: (val) {
                  AppSettings.instance.setAutoPlayNext(val);
                },
              ),
              Divider(color: borderCol, height: 12),
              _buildSwitchTile(
                context: context,
                icon: Icons.equalizer_rounded,
                title: "High Quality Audio Output",
                subtitle: "Enable enhanced audio decoding & volume boost",
                value: AppSettings.instance.highQualityAudio,
                onChanged: (val) {
                  AppSettings.instance.setHighQualityAudio(val);
                },
              ),
              Divider(color: borderCol, height: 12),
              _buildSwitchTile(
                context: context,
                icon: Icons.screen_lock_portrait_rounded,
                title: "Keep Screen Active",
                subtitle: "Prevent screen timeout while on full player",
                value: AppSettings.instance.keepScreenOn,
                onChanged: (val) {
                  AppSettings.instance.setKeepScreenOn(val);
                },
              ),
              Divider(color: borderCol, height: 12),
              ListenableBuilder(
                listenable: CastService.instance,
                builder: (context, _) {
                  final isCast = CastService.instance.isConnected;
                  return _buildActionTile(
                    context: context,
                    icon: isCast
                        ? Icons.cast_connected_rounded
                        : Icons.cast_rounded,
                    title: "Cast & Network Streaming",
                    subtitle: isCast
                        ? "Streaming to ${CastService.instance.connectedDeviceName}"
                        : "Stream to Chromecast, Smart TVs & Google Nest",
                    trailingText: isCast ? "Connected" : "Cast",
                    onTap: () {
                      String? trackPath;
                      String? trackTitle;
                      if (widget.currentlyPlayingIndex != null &&
                          widget.currentlyPlayingIndex! >= 0 &&
                          widget.currentlyPlayingIndex! <
                              widget.audioFiles.length) {
                        final item =
                            widget.audioFiles[widget.currentlyPlayingIndex!];
                        trackPath = item is File ? item.path : item.toString();
                        trackTitle =
                            trackPath.split(Platform.pathSeparator).last;
                      }
                      CastSheet.show(
                        context,
                        currentTrackPath: trackPath,
                        currentTrackTitle: trackTitle,
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLibrarySettings(BuildContext context) {
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
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Library & Audio Scanning",
                style: TextStyle(
                  fontSize: 16.0,
                  fontWeight: FontWeight.bold,
                  color: titleCol,
                ),
              ),
              Divider(color: borderCol, height: 20),
              _buildActionTile(
                context: context,
                icon: Icons.library_music_rounded,
                title: "Music Library",
                subtitle:
                    "${widget.audioFiles.length} music tracks loaded${MediaCacheService.instance.voiceMessagesCount > 0 ? " • ${MediaCacheService.instance.voiceMessagesCount} voice notes ${AppSettings.instance.includeVoiceMessages ? "included" : "filtered"}" : ""}",
                trailingText: "Cached",
                onTap: null,
              ),
              Divider(color: borderCol, height: 12),
              _buildSwitchTile(
                context: context,
                icon: Icons.record_voice_over_rounded,
                title: "Include Voice Notes & Recordings",
                subtitle:
                    "Include WhatsApp voice notes, call recordings, and voice memos in your music library. (Disabled by default for clean music experience)",
                value: AppSettings.instance.includeVoiceMessages,
                onChanged: (val) async {
                  await AppSettings.instance.setIncludeVoiceMessages(val);
                  if (widget.onRescan != null) {
                    await widget.onRescan!();
                  }
                },
              ),
              Divider(color: borderCol, height: 12),
              _buildActionTile(
                context: context,
                icon: Icons.refresh_rounded,
                title: "Rescan Audio Files",
                subtitle: "Refresh local media library and storage paths",
                trailingText: _isRescanning ? "Scanning..." : "Refresh",
                isLoading: _isRescanning,
                onTap: _handleRescan,
              ),
              Divider(color: borderCol, height: 12),
              _buildActionTile(
                context: context,
                icon: Icons.cleaning_services_rounded,
                title: "Clear Artwork Cache",
                subtitle: "Free up memory by resetting cached album covers",
                trailingText: "Clear",
                onTap: _handleClearCache,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAboutCard(BuildContext context) {
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
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "About Application",
                style: TextStyle(
                  fontSize: 16.0,
                  fontWeight: FontWeight.bold,
                  color: titleCol,
                ),
              ),
              Divider(color: borderCol, height: 20),
              _buildActionTile(
                context: context,
                icon: Icons.person_pin_rounded,
                title: "Developer Profile",
                subtitle: "Navin Kumar Verma • App Developer",
                trailingText: "Profile",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProfileScreen(
                        audioFiles: widget.audioFiles,
                        audioPlayer: widget.audioPlayer,
                        currentlyPlayingIndex: widget.currentlyPlayingIndex,
                        duration: widget.duration,
                        position: widget.position,
                        isPlaying: widget.isPlaying,
                        onPlay: widget.onPlay,
                        onPause: widget.onPause,
                        onNext: widget.onNext,
                        onPrevious: widget.onPrevious,
                        playTrack: widget.playTrack,
                        onTabTapped: widget.onTabTapped,
                      ),
                    ),
                  );
                },
              ),
              Divider(color: borderCol, height: 12),
              _buildActionTile(
                context: context,
                icon: Icons.apps_rounded,
                title: "App Version",
                subtitle: "Pocketo Play (Build 1.0.0+1)",
                trailingText: "v1.0.0",
                onTap: null,
              ),
              Divider(color: borderCol, height: 12),
              _buildActionTile(
                context: context,
                icon: Icons.verified_user_rounded,
                title: "Privacy & Licenses",
                subtitle: "Open source software licenses",
                trailingText: "View",
                onTap: () {
                  showLicensePage(
                    context: context,
                    applicationName: 'Pocketo Play',
                    applicationVersion: '1.0.0',
                    applicationIcon: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset(
                          'assets/appicon.png',
                          width: 48,
                          height: 48,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final isDark = AppTheme.isDark(context);
    final iconCol = AppTheme.iconCol(context);
    final titleCol = AppTheme.textPrimaryColor(context);
    final subTextCol = AppTheme.textSecondaryColor(context);

    return Row(
      children: [
        Icon(icon, color: iconCol, size: 22),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: titleCol,
                  fontWeight: FontWeight.w600,
                  fontSize: 14.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: subTextCol,
                  fontSize: 12.0,
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: Colors.white,
          activeTrackColor:
              isDark ? const Color(0xFF3A3A3C) : AppTheme.lightPrimary,
          inactiveTrackColor:
              isDark ? const Color(0xFF282828) : const Color(0xFFE2E8F0),
        ),
      ],
    );
  }

  Widget _buildActionTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required String trailingText,
    required VoidCallback? onTap,
    bool isLoading = false,
  }) {
    final isDark = AppTheme.isDark(context);
    final iconCol = AppTheme.iconCol(context);
    final titleCol = AppTheme.textPrimaryColor(context);
    final subTextCol = AppTheme.textSecondaryColor(context);
    final badgeBg =
        isDark ? const Color(0xFF282828) : const Color(0xFFEEF2FF);
    final badgeText =
        isDark ? Colors.white70 : AppTheme.lightPrimary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0),
        child: Row(
          children: [
            Icon(icon, color: iconCol, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: titleCol,
                      fontWeight: FontWeight.w600,
                      fontSize: 14.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: subTextCol,
                      fontSize: 12.0,
                    ),
                  ),
                ],
              ),
            ),
            if (isLoading)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  trailingText,
                  style: TextStyle(
                    color: badgeText,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
