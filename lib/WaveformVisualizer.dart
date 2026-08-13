import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Animation style for the visualizer.
enum VisualizerStyle {
  /// Classic bouncy waveform bars (used in mini player).
  wave,

  /// Canvas-rendered spectrum with gradient coloring (used in full player).
  spectrum,
}

class WaveformVisualizer extends StatefulWidget {
  final bool isPlaying;
  final int barCount;
  final double height;
  final double barWidth;
  final Color? barColor;
  final Gradient? gradient;
  final VisualizerStyle style;

  const WaveformVisualizer({
    super.key,
    required this.isPlaying,
    this.barCount = 18,
    this.height = 36.0,
    this.barWidth = 3.5,
    this.barColor,
    this.gradient,
    this.style = VisualizerStyle.wave,
  });

  @override
  State<WaveformVisualizer> createState() => _WaveformVisualizerState();
}

class _WaveformVisualizerState extends State<WaveformVisualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    if (widget.isPlaying) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant WaveformVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.style == VisualizerStyle.spectrum) {
      return _buildSpectrum(context);
    }
    return _buildWave(context);
  }

  // ── Classic wave (mini player) — stays widget-based, only 4 bars ──────────
  Widget _buildWave(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return SizedBox(
          height: widget.height,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(widget.barCount, (i) {
              final phase = (i / widget.barCount) * 2 * math.pi;
              final sinVal = widget.isPlaying
                  ? (math.sin(t * 2 * math.pi * 1.5 + phase) +
                          math.sin(t * 2 * math.pi * 2.2 + phase * 2)) /
                      2
                  : 0.0;
              final norm = widget.isPlaying
                  ? 0.2 + 0.8 * ((sinVal + 1) / 2).clamp(0.0, 1.0)
                  : 0.15 + 0.1 * math.sin(phase).abs();
              final barH = (norm * widget.height).clamp(4.0, widget.height);

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 2.0),
                width: widget.barWidth,
                height: barH,
                decoration: BoxDecoration(
                  color: widget.barColor ?? Theme.of(context).primaryColor,
                  borderRadius: BorderRadius.circular(widget.barWidth),
                ),
              );
            }),
          ),
        );
      },
    );
  }

  // ── Canvas-rendered spectrum (full player) — zero widget rebuilds ─────────
  Widget _buildSpectrum(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return SizedBox(
          height: widget.height,
          width: double.infinity,
          child: CustomPaint(
            painter: _SpectrumPainter(
              t: _controller.value,
              barCount: widget.barCount,
              barWidth: widget.barWidth,
              isPlaying: widget.isPlaying,
            ),
          ),
        );
      },
    );
  }
}

/// Paints the spectrum visualizer directly on canvas.
/// No widget tree, no layout passes — just raw canvas calls.
class _SpectrumPainter extends CustomPainter {
  final double t;
  final int barCount;
  final double barWidth;
  final bool isPlaying;

  // Pre-built color list — computed once per instance
  late final List<Color> _barColors;

  _SpectrumPainter({
    required this.t,
    required this.barCount,
    required this.barWidth,
    required this.isPlaying,
  }) {
    _barColors = List.generate(barCount, (i) {
      final frac = i / (barCount - 1);
      if (frac < 0.5) {
        return Color.lerp(
          const Color(0xFF38BDF8), // cyan-sky
          const Color(0xFFA855F7), // purple
          frac * 2,
        )!;
      } else {
        return Color.lerp(
          const Color(0xFFA855F7), // purple
          const Color(0xFFF43F5E), // rose
          (frac - 0.5) * 2,
        )!;
      }
    });
  }

  @override
  void paint(Canvas canvas, Size size) {
    final totalBarWidth = barWidth;
    final gap = (size.width - barCount * totalBarWidth) / (barCount + 1);
    final paint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < barCount; i++) {
      final fraction = i / barCount;
      double barHeight;

      if (isPlaying) {
        // Multi-harmonic spectrum simulation with non-harmonic prime frequencies
        final f1 = math.sin(t * math.pi * 2 * 1.37 + fraction * 4.1);
        final f2 = math.cos(t * math.pi * 2 * 2.83 - fraction * 7.3);
        final f3 = math.sin(t * math.pi * 2 * 0.59 + fraction * 2.7);
        final f4 = math.sin(t * math.pi * 2 * 4.19 + fraction * 11.2);

        // Bass-heavy shaping (lower-frequency/bass bars are taller)
        final shape = math.exp(-fraction * 1.4) * 0.65 + 0.35;
        final raw = ((f1 + f2 * 0.6 + f3 * 0.4 + f4 * 0.25) / 2.25 + 1) / 2;
        barHeight = (raw * shape).clamp(0.08, 1.0) * size.height;
      } else {
        barHeight =
            (0.08 + 0.06 * math.sin(fraction * math.pi * 4).abs()) * size.height;
      }

      barHeight = barHeight.clamp(3.0, size.height);

      final left = gap + i * (totalBarWidth + gap);
      final top = size.height - barHeight;
      final rect = RRect.fromLTRBR(
        left,
        top,
        left + totalBarWidth,
        size.height,
        Radius.circular(totalBarWidth / 2),
      );

      // Simple flat color — no gradient per-bar, no shadow
      // The color list gives visual richness without per-frame allocation
      paint.color = _barColors[i].withValues(
        alpha: isPlaying ? 0.85 + 0.15 * (barHeight / size.height) : 0.4,
      );

      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(_SpectrumPainter old) =>
      old.t != t || old.isPlaying != isPlaying;
}
