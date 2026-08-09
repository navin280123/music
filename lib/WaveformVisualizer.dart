import 'dart:math' as math;
import 'package:flutter/material.dart';

class WaveformVisualizer extends StatefulWidget {
  final bool isPlaying;
  final int barCount;
  final double height;
  final double barWidth;
  final Color? barColor;
  final Gradient? gradient;

  const WaveformVisualizer({
    super.key,
    required this.isPlaying,
    this.barCount = 18,
    this.height = 36.0,
    this.barWidth = 3.5,
    this.barColor,
    this.gradient,
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
      duration: const Duration(milliseconds: 1000),
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

              final barH = (normalizedHeight * widget.height).clamp(4.0, widget.height);

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
}
