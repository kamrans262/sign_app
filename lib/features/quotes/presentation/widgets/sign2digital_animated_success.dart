import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Animates for exactly two seconds, then remains in the completed frame.
class Sign2DigitalAnimatedSuccess extends StatefulWidget {
  const Sign2DigitalAnimatedSuccess({super.key});

  @override
  State<Sign2DigitalAnimatedSuccess> createState() =>
      _Sign2DigitalAnimatedSuccessState();
}

class _Sign2DigitalAnimatedSuccessState
    extends State<Sign2DigitalAnimatedSuccess>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this, duration: const Duration(seconds: 2),
  );
  bool _started = false;
  static const _dots = <(Offset, Color)>[
    (Offset(110, 3), Color(0xFFB5EBF0)),
    (Offset(43, 25), Color(0xFFB87ADE)),
    (Offset(196, 27), Color(0xFFFF7BBE)),
    (Offset(247, 49), Color(0xFFFF8B58)),
    (Offset(22, 90), Color(0xFFFF8B58)),
    (Offset(255, 120), Color(0xFFB5EBF0)),
    (Offset(0, 147), Color(0xFFB87ADE)),
    (Offset(63, 160), Color(0xFF619CB1)),
    (Offset(224, 166), Color(0xFFF8D575)),
    (Offset(270, 150), Color(0xFFFF7BBE)),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.of(context).disableAnimations) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    key: const Key('signed-success-animation'),
    width: 280,
    height: 185,
    child: AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final progress = _controller.value;
        final settle = Curves.easeOutCubic.transform(progress);
        final wander = math.sin(progress * math.pi * 3) *
            math.sin(math.pi * progress) * 5;
        final scale = 0.83 + 0.17 * Curves.easeOutBack.transform(
          (progress * 2.5).clamp(0.0, 1.0).toDouble(),
        );
        return Stack(
          children: [
            for (var i = 0; i < _dots.length; i++)
              Positioned(
                left: _dots[i].$1.dx +
                    (1 - settle) * (140 - _dots[i].$1.dx) * 0.18 +
                    wander * (i.isEven ? 1 : -1),
                top: _dots[i].$1.dy +
                    (1 - settle) * (90 - _dots[i].$1.dy) * 0.18 +
                    wander * (i % 3 == 0 ? 0.7 : -0.7),
                child: Container(
                  width: 6, height: 6,
                  decoration: BoxDecoration(
                    color: _dots[i].$2, shape: BoxShape.circle,
                  ),
                ),
              ),
            Positioned(
              left: 80, top: 32,
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: 120, height: 120,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF1F8F2), shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Container(
                    width: 84, height: 84,
                    decoration: const BoxDecoration(
                      color: Color(0xFF2C9B3D), shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded, color: Colors.white, size: 56,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}
