import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/app_colors.dart';

typedef SignatureStrokePointCallback = void Function(Offset position, Size size);

/// The same normalized, eager-pointer drawing surface on both signing screens.
/// Callers own the stroke lists and draft lifecycle.
class Sign2DigitalSignatureDrawCanvas extends StatelessWidget {
  const Sign2DigitalSignatureDrawCanvas({
    super.key,
    required this.strokes,
    required this.onStart,
    required this.onUpdate,
    this.onEnd,
    this.captureKey,
  });

  final List<List<Offset>> strokes;
  final SignatureStrokePointCallback onStart;
  final SignatureStrokePointCallback onUpdate;
  final VoidCallback? onEnd;
  final Key? captureKey;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = Size(constraints.maxWidth, constraints.maxHeight);
      return RawGestureDetector(
        behavior: HitTestBehavior.opaque,
        gestures: <Type, GestureRecognizerFactory>{
          EagerGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<EagerGestureRecognizer>(
            () => EagerGestureRecognizer(),
            (instance) {},
          ),
        },
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (event) => onStart(event.localPosition, size),
          onPointerMove: (event) => onUpdate(event.localPosition, size),
          onPointerUp: (_) => onEnd?.call(),
          onPointerCancel: (_) => onEnd?.call(),
          child: RepaintBoundary(
            key: captureKey,
            child: CustomPaint(
              painter: _SignatureStrokePainter(strokes),
              child: const SizedBox.expand(),
            ),
          ),
        ),
      );
    },
  );
}

class Sign2DigitalSignatureClearButton extends StatelessWidget {
  const Sign2DigitalSignatureClearButton({
    super.key,
    required this.onPressed,
  });

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.bottomRight,
    child: Padding(
      padding: const EdgeInsets.all(15),
      child: TextButton.icon(
        onPressed: onPressed,
        icon: SvgPicture.asset(
          'assets/icons_2/arrow-reset.svg',
          width: 20,
          height: 20,
          colorFilter: const ColorFilter.mode(
            AppColors.primary,
            BlendMode.srcIn,
          ),
        ),
        label: const Text(
          'Clear',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w500,
            fontSize: 16,
            letterSpacing: -0.3,
            color: AppColors.primary,
          ),
        ),
      ),
    ),
  );
}

class _SignatureStrokePainter extends CustomPainter {
  const _SignatureStrokePainter(this.strokes);
  final List<List<Offset>> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.dark
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;

    for (final stroke in strokes) {
      if (stroke.length < 2) continue;
      final first = _scaled(stroke.first, size);
      final path = Path()..moveTo(first.dx, first.dy);
      for (var i = 1; i < stroke.length - 1; i++) {
        final current = _scaled(stroke[i], size);
        final next = _scaled(stroke[i + 1], size);
        path.quadraticBezierTo(
          current.dx,
          current.dy,
          (current.dx + next.dx) / 2,
          (current.dy + next.dy) / 2,
        );
      }
      final last = _scaled(stroke.last, size);
      path.lineTo(last.dx, last.dy);
      canvas.drawPath(path, paint);
    }
  }

  Offset _scaled(Offset point, Size size) =>
      Offset(point.dx * size.width, point.dy * size.height);

  @override
  bool shouldRepaint(covariant _SignatureStrokePainter oldDelegate) => true;
}
