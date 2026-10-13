import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Recording uses amplitude; processing uses a separate, non-microphone animation.
class Sign2DigitalAudioWaveform extends StatefulWidget {
  const Sign2DigitalAudioWaveform({
    super.key,
    required this.animating,
    this.processing = false,
    this.amplitude = 0.35,
  });

  final bool animating;
  final bool processing;
  final double amplitude;

  @override
  State<Sign2DigitalAudioWaveform> createState() => _WaveformState();
}

class _WaveformState extends State<Sign2DigitalAudioWaveform>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  );

  @override
  void initState() {
    super.initState();
    if (widget.animating) _controller.repeat();
  }

  @override
  void didUpdateWidget(Sign2DigitalAudioWaveform oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animating != oldWidget.animating) {
      if (widget.animating) {
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
    return RepaintBoundary(
      child: SizedBox(
        height: 30,
        width: 200,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return CustomPaint(
              painter: _BarsPainter(
                phase: _controller.value,
                intensity: widget.processing ? 0.65 : widget.amplitude,
                animating: widget.animating,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _BarsPainter extends CustomPainter {
  const _BarsPainter({
    required this.phase,
    required this.intensity,
    required this.animating,
  });

  final double phase;
  final double intensity;
  final bool animating;

  @override
  void paint(Canvas canvas, Size size) {
    const count = 41;
    final step = size.width / count;
    for (var index = 0; index < count; index++) {
      final edge = (index - (count - 1) / 2).abs() / ((count - 1) / 2);
      final wave = (math.sin(index * 1.73 + phase * math.pi * 2) + 1) / 2;
      final shape = (math.sin(index * .78) + 1) / 2;
      final level = animating ? (0.24 + .76 * wave) : (0.24 + .50 * shape);
      final height =
          (3.5 +
                  25 *
                      (0.25 + intensity * .75) *
                      (0.32 + .68 * level) *
                      (1 - edge * .4))
              .clamp(3.5, 29.0);
      final paint = Paint()
        ..color = AppColors.primary.withAlpha(
          edge > .8
              ? 43
              : edge > .65
              ? 89
              : 255,
        )
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round;
      final x = (index + .5) * step;
      canvas.drawLine(
        Offset(x, (size.height - height) / 2),
        Offset(x, (size.height + height) / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_BarsPainter oldDelegate) =>
      oldDelegate.phase != phase ||
      oldDelegate.intensity != intensity ||
      oldDelegate.animating != animating;
}
