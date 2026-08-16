import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:music/core/app_theme.dart';
import 'package:music/services/sleep_timer_service.dart';

class SleepTimerSheet {
  static void show(
    BuildContext context,
    AudioPlayer audioPlayer, {
    Color? accentColor,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _SleepTimerSheetContent(
        audioPlayer: audioPlayer,
        accentColor: accentColor,
      ),
    );
  }
}

class _SleepTimerSheetContent extends StatefulWidget {
  final AudioPlayer audioPlayer;
  final Color? accentColor;

  const _SleepTimerSheetContent({
    required this.audioPlayer,
    this.accentColor,
  });

  @override
  State<_SleepTimerSheetContent> createState() =>
      _SleepTimerSheetContentState();
}

class _SleepTimerSheetContentState extends State<_SleepTimerSheetContent> {
  bool _isCustomMode = false;
  int _customMinutes = 25;
  late final TextEditingController _customController;

  @override
  void initState() {
    super.initState();
    _customController = TextEditingController(text: '$_customMinutes');
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  void _applyTimer(int minutes) {
    if (minutes <= 0) return;
    SleepTimerService.instance.startTimer(minutes, widget.audioPlayer);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Sleep timer set for $minutes minute${minutes == 1 ? '' : 's'}"),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _applyEndOfTrack() {
    SleepTimerService.instance.setEndOfTrackMode(widget.audioPlayer);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Sleep timer will stop at the end of this track"),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _formatCustomDuration(int minutes) {
    if (minutes < 60) {
      return "$minutes min";
    }
    final hrs = minutes ~/ 60;
    final mins = minutes % 60;
    if (mins == 0) {
      return "$hrs hr${hrs > 1 ? 's' : ''}";
    }
    return "$hrs hr${hrs > 1 ? 's' : ''} $mins min";
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final sheetBg = isDark ? const Color(0xFF1E1E20) : Colors.white;
    final textCol = isDark ? Colors.white : const Color(0xFF0F172A);
    final subTextCol = isDark ? Colors.white54 : const Color(0xFF64748B);
    final activeCol = widget.accentColor ??
        (isDark ? const Color(0xFF818CF8) : AppTheme.lightPrimary);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      padding: EdgeInsets.only(bottom: bottomInset),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: sheetBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.1),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: ListenableBuilder(
          listenable: SleepTimerService.instance,
          builder: (context, _) {
            final timerService = SleepTimerService.instance;

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top drag pill
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Header Row
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
                          child: Icon(
                            Icons.bedtime_rounded,
                            color: activeCol,
                            size: 22,
                          ),
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
                                color: timerService.isActive
                                    ? activeCol
                                    : subTextCol,
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
                      TextButton.icon(
                        onPressed: () {
                          timerService.cancelTimer(widget.audioPlayer);
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Sleep timer turned off"),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        icon: const Icon(Icons.power_settings_new_rounded,
                            color: Colors.redAccent, size: 16),
                        label: const Text(
                          "Turn Off",
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),

                // Quick preset buttons & Custom view
                if (!_isCustomMode) ...[
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      ...[15, 30, 45, 60, 90].map((mins) {
                        return ElevatedButton(
                          onPressed: () => _applyTimer(mins),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDark
                                ? const Color(0xFF28282A)
                                : const Color(0xFFF1F5F9),
                            foregroundColor: textCol,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            "$mins min",
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        );
                      }),
                      ElevatedButton.icon(
                        onPressed: _applyEndOfTrack,
                        icon: const Icon(Icons.skip_next_rounded, size: 16),
                        label: const Text(
                          "End of Track",
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: activeCol.withValues(alpha: 0.15),
                          foregroundColor: activeCol,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _isCustomMode = true;
                          });
                        },
                        icon: const Icon(Icons.tune_rounded, size: 16),
                        label: const Text(
                          "Custom Time",
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark
                              ? const Color(0xFF333338)
                              : const Color(0xFFE2E8F0),
                          foregroundColor: textCol,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: activeCol.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  // Custom Time Selection View
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF28282C)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: activeCol.withValues(alpha: 0.25),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Set Custom Duration",
                              style: TextStyle(
                                color: textCol,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              _formatCustomDuration(_customMinutes),
                              style: TextStyle(
                                color: activeCol,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Stepper + Text input Row
                        Row(
                          children: [
                            IconButton.filledTonal(
                              onPressed: _customMinutes > 1
                                  ? () {
                                      setState(() {
                                        _customMinutes = (_customMinutes - 5)
                                            .clamp(1, 720);
                                        _customController.text =
                                            '$_customMinutes';
                                      });
                                    }
                                  : null,
                              icon: const Icon(Icons.remove_rounded),
                              style: IconButton.styleFrom(
                                backgroundColor: isDark
                                    ? const Color(0xFF38383E)
                                    : const Color(0xFFE2E8F0),
                                foregroundColor: textCol,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _customController,
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: textCol,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                                decoration: InputDecoration(
                                  suffixText: 'mins',
                                  suffixStyle: TextStyle(
                                    color: subTextCol,
                                    fontSize: 13,
                                  ),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                  filled: true,
                                  fillColor: isDark
                                      ? const Color(0xFF1E1E20)
                                      : Colors.white,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: isDark
                                          ? Colors.white24
                                          : Colors.grey.shade300,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide:
                                        BorderSide(color: activeCol, width: 2),
                                  ),
                                ),
                                onChanged: (val) {
                                  final parsed = int.tryParse(val.trim());
                                  if (parsed != null && parsed > 0) {
                                    setState(() {
                                      _customMinutes = parsed.clamp(1, 720);
                                    });
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filledTonal(
                              onPressed: _customMinutes < 720
                                  ? () {
                                      setState(() {
                                        _customMinutes = (_customMinutes + 5)
                                            .clamp(1, 720);
                                        _customController.text =
                                            '$_customMinutes';
                                      });
                                    }
                                  : null,
                              icon: const Icon(Icons.add_rounded),
                              style: IconButton.styleFrom(
                                backgroundColor: isDark
                                    ? const Color(0xFF38383E)
                                    : const Color(0xFFE2E8F0),
                                foregroundColor: textCol,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Quick delta pills
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              ...[-15, -10, -5, 5, 10, 15, 30, 60].map((delta) {
                                final isPos = delta > 0;
                                return Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 3),
                                  child: ActionChip(
                                    label: Text(
                                      isPos ? "+$delta m" : "$delta m",
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: isPos ? activeCol : subTextCol,
                                      ),
                                    ),
                                    padding: EdgeInsets.zero,
                                    visualDensity: VisualDensity.compact,
                                    backgroundColor: isDark
                                        ? const Color(0xFF1E1E20)
                                        : Colors.white,
                                    side: BorderSide(
                                      color: isDark
                                          ? Colors.white12
                                          : Colors.grey.shade300,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _customMinutes = (_customMinutes + delta)
                                            .clamp(1, 720);
                                        _customController.text =
                                            '$_customMinutes';
                                      });
                                    },
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Action Buttons: Back / Cancel / Set Timer
                        Row(
                          children: [
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _isCustomMode = false;
                                });
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: subTextCol,
                              ),
                              child: const Text("Presets"),
                            ),
                            const Spacer(),
                            ElevatedButton(
                              onPressed: () => _applyTimer(_customMinutes),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: activeCol,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 2,
                              ),
                              child: Text(
                                "Start ($_customMinutes min)",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
              ],
            );
          },
        ),
      ),
    );
  }
}
