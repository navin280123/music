import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:music/core/app_theme.dart';

class ABLooperService extends ChangeNotifier {
  static final ABLooperService _instance = ABLooperService._internal();
  static ABLooperService get instance => _instance;

  ABLooperService._internal();

  Duration? _pointA;
  Duration? _pointB;
  bool _isEnabled = false;
  StreamSubscription<Duration>? _subscription;

  Duration? get pointA => _pointA;
  Duration? get pointB => _pointB;
  bool get isEnabled => _isEnabled;

  void attachAudioPlayer(AudioPlayer audioPlayer) {
    _subscription?.cancel();
    _subscription = audioPlayer.positionStream.listen((pos) {
      if (_isEnabled && _pointA != null && _pointB != null) {
        if (pos >= _pointB!) {
          audioPlayer.seek(_pointA!);
        }
      }
    });
  }

  void setPointA(Duration position) {
    _pointA = position;
    if (_pointB != null && _pointB! <= _pointA!) {
      _pointB = null;
    }
    notifyListeners();
  }

  void setPointB(Duration position) {
    if (_pointA == null || position > _pointA!) {
      _pointB = position;
      _isEnabled = true;
      notifyListeners();
    }
  }

  void toggleEnabled() {
    if (_pointA != null && _pointB != null) {
      _isEnabled = !_isEnabled;
      notifyListeners();
    }
  }

  void clear() {
    _pointA = null;
    _pointB = null;
    _isEnabled = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

class ABLooperSheet extends StatelessWidget {
  final AudioPlayer audioPlayer;
  final Duration currentPosition;

  const ABLooperSheet({
    super.key,
    required this.audioPlayer,
    required this.currentPosition,
  });

  static void show(BuildContext context, AudioPlayer audioPlayer, Duration currentPosition) {
    ABLooperService.instance.attachAudioPlayer(audioPlayer);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => ABLooperSheet(
        audioPlayer: audioPlayer,
        currentPosition: currentPosition,
      ),
    );
  }

  String _formatDuration(Duration? d) {
    if (d == null) return "--:--";
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
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

    return ListenableBuilder(
      listenable: ABLooperService.instance,
      builder: (context, _) {
        final looper = ABLooperService.instance;

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
                        child: Icon(Icons.repeat_on_rounded, color: activeCol, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "A-B Looper (Practice Mode)",
                            style: TextStyle(
                              color: textCol,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            "Loop any specific section of the track",
                            style: TextStyle(color: subTextCol, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (looper.pointA != null || looper.pointB != null)
                    IconButton(
                      icon: Icon(Icons.clear_rounded, color: subTextCol),
                      onPressed: () => looper.clear(),
                      tooltip: "Clear Loop",
                    ),
                ],
              ),
              const SizedBox(height: 20),

              // Point A & Point B status cards
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: looper.pointA != null ? activeCol : borderCol,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text("Point A (Start)", style: TextStyle(color: subTextCol, fontSize: 12)),
                          const SizedBox(height: 6),
                          Text(
                            _formatDuration(looper.pointA),
                            style: TextStyle(
                              color: textCol,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton(
                            onPressed: () {
                              looper.setPointA(audioPlayer.position);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: activeCol,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text("Set Point A", style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: looper.pointB != null ? activeCol : borderCol,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text("Point B (End)", style: TextStyle(color: subTextCol, fontSize: 12)),
                          const SizedBox(height: 6),
                          Text(
                            _formatDuration(looper.pointB),
                            style: TextStyle(
                              color: textCol,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton(
                            onPressed: () {
                              looper.setPointB(audioPlayer.position);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: activeCol,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text("Set Point B", style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Active Loop toggle
              if (looper.pointA != null && looper.pointB != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: looper.isEnabled
                        ? activeCol.withValues(alpha: 0.15)
                        : cardBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: looper.isEnabled ? activeCol : borderCol,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            looper.isEnabled ? Icons.repeat_on_rounded : Icons.repeat_rounded,
                            color: looper.isEnabled ? activeCol : subTextCol,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            looper.isEnabled ? "Loop Active" : "Loop Disabled",
                            style: TextStyle(
                              color: looper.isEnabled ? activeCol : textCol,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Switch(
                        value: looper.isEnabled,
                        activeThumbColor: Colors.white,
                        activeTrackColor: activeCol,
                        inactiveTrackColor: isDark ? const Color(0xFF3F3F46) : const Color(0xFFE2E8F0),
                        inactiveThumbColor: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF64748B),
                        onChanged: (_) => looper.toggleEnabled(),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }
}
