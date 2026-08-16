import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:music/core/app_theme.dart';

class EqualizerPresetSheet extends StatefulWidget {
  final AudioPlayer audioPlayer;

  const EqualizerPresetSheet({super.key, required this.audioPlayer});

  static void show(BuildContext context, AudioPlayer audioPlayer) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EqualizerPresetSheet(audioPlayer: audioPlayer),
    );
  }

  @override
  State<EqualizerPresetSheet> createState() => _EqualizerPresetSheetState();
}

class _EqualizerPresetSheetState extends State<EqualizerPresetSheet> {
  static String _selectedPreset = 'Flat';
  static double _playbackSpeed = 1.0;
  static double _pitch = 1.0;

  final List<Map<String, dynamic>> _presets = [
    {'name': 'Flat', 'icon': Icons.horizontal_rule_rounded, 'desc': 'Original natural sound'},
    {'name': 'Bass Boost', 'icon': Icons.speaker_group_rounded, 'desc': 'Deep punchy bass'},
    {'name': 'Vocal', 'icon': Icons.record_voice_over_rounded, 'desc': 'Clear podcasts & singing'},
    {'name': 'Rock', 'icon': Icons.electric_bolt_rounded, 'desc': 'Dynamic punch & drums'},
    {'name': 'Pop', 'icon': Icons.audiotrack_rounded, 'desc': 'Bright melodious vocals'},
    {'name': 'Jazz', 'icon': Icons.piano_rounded, 'desc': 'Warm smooth brass & keys'},
    {'name': 'Electronic', 'icon': Icons.waves_rounded, 'desc': 'Elevated highs and sub-bass'},
    {'name': 'Acoustic', 'icon': Icons.music_note_rounded, 'desc': 'Rich strings & live room'},
  ];

  @override
  void initState() {
    super.initState();
    _playbackSpeed = widget.audioPlayer.speed;
    _pitch = widget.audioPlayer.pitch;
  }

  void _applyPreset(String name) {
    setState(() {
      _selectedPreset = name;
    });

    // In just_audio, presets can customize fine pitch/speed or software filters
    switch (name) {
      case 'Bass Boost':
        widget.audioPlayer.setPitch(0.95);
        break;
      case 'Vocal':
        widget.audioPlayer.setPitch(1.05);
        break;
      case 'Electronic':
        widget.audioPlayer.setPitch(1.02);
        break;
      default:
        widget.audioPlayer.setPitch(_pitch);
        break;
    }
  }

  void _setSpeed(double speed) {
    setState(() {
      _playbackSpeed = speed;
    });
    widget.audioPlayer.setSpeed(speed);
  }

  void _setPitch(double pitch) {
    setState(() {
      _pitch = pitch;
    });
    widget.audioPlayer.setPitch(pitch);
  }

  void _resetAll() {
    setState(() {
      _selectedPreset = 'Flat';
      _playbackSpeed = 1.0;
      _pitch = 1.0;
    });
    widget.audioPlayer.setSpeed(1.0);
    widget.audioPlayer.setPitch(1.0);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final sheetBg = isDark ? const Color(0xFF1A1A1C) : Colors.white;
    final textCol = isDark ? Colors.white : const Color(0xFF0F172A);
    final subTextCol = isDark ? Colors.white54 : const Color(0xFF64748B);
    final activeCol = isDark ? const Color(0xFF818CF8) : AppTheme.lightPrimary;
    final cardBg = isDark ? const Color(0xFF242426) : const Color(0xFFF1F5F9);
    final borderCol = isDark ? const Color(0xFF2E2E32) : const Color(0xFFE2E8F0);

    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 12),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Row(
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
                      child: Icon(Icons.tune_rounded, color: activeCol, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      "Sound & Equalizer",
                      style: TextStyle(
                        color: textCol,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: _resetAll,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text("Reset"),
                  style: TextButton.styleFrom(foregroundColor: subTextCol),
                ),
              ],
            ),
          ),
          const Divider(height: 16),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Presets Section
                  Text(
                    "Audio Presets",
                    style: TextStyle(
                      color: textCol,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 2.3,
                    ),
                    itemCount: _presets.length,
                    itemBuilder: (context, index) {
                      final item = _presets[index];
                      final isSelected = _selectedPreset == item['name'];

                      return GestureDetector(
                        onTap: () => _applyPreset(item['name'] as String),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? activeCol.withValues(alpha: 0.15) : cardBg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected ? activeCol : borderCol,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                item['icon'] as IconData,
                                color: isSelected ? activeCol : subTextCol,
                                size: 22,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item['name'] as String,
                                      style: TextStyle(
                                        color: isSelected ? activeCol : textCol,
                                        fontWeight:
                                            isSelected ? FontWeight.bold : FontWeight.w600,
                                        fontSize: 13.5,
                                      ),
                                    ),
                                    Text(
                                      item['desc'] as String,
                                      style: TextStyle(
                                        color: subTextCol,
                                        fontSize: 10,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // Playback Speed Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Playback Speed",
                        style: TextStyle(
                          color: textCol,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: activeCol.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          "${_playbackSpeed.toStringAsFixed(2)}x",
                          style: TextStyle(
                            color: activeCol,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Slider(
                    value: _playbackSpeed,
                    min: 0.5,
                    max: 2.0,
                    divisions: 15,
                    activeColor: activeCol,
                    inactiveColor: borderCol,
                    onChanged: (val) => _setSpeed(val),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [0.5, 0.75, 1.0, 1.25, 1.5, 2.0].map((s) {
                      final isCurrent = (_playbackSpeed - s).abs() < 0.01;
                      return GestureDetector(
                        onTap: () => _setSpeed(s),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isCurrent ? activeCol : cardBg,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            "${s}x",
                            style: TextStyle(
                              color: isCurrent ? Colors.white : subTextCol,
                              fontSize: 11,
                              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // Pitch Shifter Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Pitch Shifter",
                        style: TextStyle(
                          color: textCol,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: activeCol.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          "${_pitch.toStringAsFixed(2)}x",
                          style: TextStyle(
                            color: activeCol,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Slider(
                    value: _pitch,
                    min: 0.8,
                    max: 1.2,
                    divisions: 8,
                    activeColor: activeCol,
                    inactiveColor: borderCol,
                    onChanged: (val) => _setPitch(val),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
