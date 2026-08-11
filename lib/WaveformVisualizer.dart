import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Animation style for the visualizer.
enum VisualizerStyle {
  /// Classic bouncy waveform bars (used in mini player).
  wave,

  /// More bars with gradient coloring (used in full player).
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
      duration: const Duration(milliseconds: 900),
    );

    if (widget.isPlaying) {
      _controller.repeat();
    }
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
      return _buildSpectrum();
    }
    return _buildWave();
  }

  // ---- Classic wave mode (mini player) ----
  Widget _buildWave() {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final progress = _controller.value;
        return SizedBox(
          height: widget.height,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(widget.barCount, (index) {
              final phase = (index / widget.barCount) * 2 * math.pi;
              final sinVal = widget.isPlaying
                  ? (math.sin(progress * 2 * math.pi * 1.5 + phase) +
                          math.sin(progress * 2 * math.pi * 2.2 + phase * 2)) /
                      2
                  : 0.0;

              final normalizedHeight = widget.isPlaying
                  ? 0.2 + 0.8 * ((sinVal + 1) / 2).clamp(0.0, 1.0)
                  : 0.15 + (0.1 * math.sin(phase).abs());

              final barH =
                  (normalizedHeight * widget.height).clamp(4.0, widget.height);

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 2.0),
                width: widget.barWidth,
                height: barH,
                decoration: BoxDecoration(
                  color: widget.gradient == null
                      ? (widget.barColor ?? Theme.of(context).primaryColor)
                      : null,
                  gradient: widget.gradient,
                  borderRadius: BorderRadius.circular(widget.barWidth),
                ),
              );
            }),
          ),
        );
      },
    );
  }

  // ---- Enhanced spectrum mode (full player) ----
  Widget _buildSpectrum() {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        final bars = widget.barCount;

        return SizedBox(
          height: widget.height,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(bars, (i) {
              final fraction = i / bars;

              // Simulate a multi-frequency spectrum response
              double barHeight;
              if (widget.isPlaying) {
                final freq1 = math.sin(t * math.pi * 2 * 1.3 + fraction * math.pi * 3.5);
                final freq2 = math.sin(t * math.pi * 2 * 2.1 + fraction * math.pi * 6.0);
                final freq3 = math.sin(t * math.pi * 2 * 3.7 + fraction * math.pi * 1.5);
                // Shape: bass-heavy (low i = taller)
                final shapeFactor = math.exp(-fraction * 1.5) * 0.6 + 0.4;
                final raw = ((freq1 + freq2 * 0.5 + freq3 * 0.25) / 1.75 + 1) / 2;
                barHeight = (raw * shapeFactor).clamp(0.08, 1.0) * widget.height;
              } else {
                // Idle: tiny static bars
                barHeight = (0.08 + 0.06 * math.sin(fraction * math.pi * 4).abs()) *
                    widget.height;
              }

              // Color gradient: blue -> purple -> pink across bars
              final colorT = fraction;
              final barColor = Color.lerp(
                const Color(0xFF38BDF8), // cyan-blue
                const Color(0xFFA855F7), // purple
                colorT,
              )!;
              final accentColor = Color.lerp(
                const Color(0xFFA855F7),
                const Color(0xFFF43F5E), // rose
                (colorT - 0.5).clamp(0.0, 1.0) * 2,
              )!;
              final finalColor = colorT < 0.5 ? barColor : accentColor;

              return Container(
                margin: EdgeInsets.symmetric(horizontal: widget.barWidth * 0.3),
                width: widget.barWidth,
                height: barHeight.clamp(3.0, widget.height),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      finalColor,
                      finalColor.withValues(alpha: 0.4),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(widget.barWidth),
                  boxShadow: widget.isPlaying
                      ? [
                          BoxShadow(
                            color: finalColor.withValues(alpha: 0.3),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
              );
            }),
          ),
        );
      },
    );
  }
}
