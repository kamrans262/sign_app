import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sign2digital_header.dart';
import '../../../../core/widgets/sign2digital_info_banner.dart';
import '../../../../core/widgets/sign2digital_outlined_container.dart';
import '../../../../core/widgets/sign2digital_primary_button.dart';
import '../../domain/quote_review_models.dart';
import 'document_signed_success_screen.dart';

/// In-person dual-signature UI prototype. Captured strokes remain in memory.
/// No customer identity verification, audit record, or signed PDF is produced.
class InPersonSignatureScreen extends StatefulWidget {
  const InPersonSignatureScreen({
    super.key,
    required this.quote,
    required this.projectName,
  });

  final QuoteReviewDraft quote;
  final String projectName;

  @override
  State<InPersonSignatureScreen> createState() =>
      _InPersonSignatureScreenState();
}

class _InPersonSignatureScreenState extends State<InPersonSignatureScreen> {
  static const _border = AppColors.lightBorder;
  static const _surface = Color(0xFFF3F4F6);

  // Separate normalized drawing points for each party. Changing tabs never
  // clears the other person's locally captured drawing.
  final List<List<List<Offset>>> _strokes = [
    <List<Offset>>[],
    <List<Offset>>[],
  ];
  int _selectedSigner = 0;

  Offset _normalized(Offset point, Size size) => Offset(
    (point.dx / size.width).clamp(0.0, 1.0).toDouble(),
    (point.dy / size.height).clamp(0.0, 1.0).toDouble(),
  );

  void _start(Offset point, Size size) {
    setState(() {
      _strokes[_selectedSigner].add([_normalized(point, size)]);
    });
  }

  void _update(Offset point, Size size) {
    if (_strokes[_selectedSigner].isEmpty) return;
    setState(() {
      _strokes[_selectedSigner].last.add(_normalized(point, size));
    });
  }

  void _clear() {
    setState(() => _strokes[_selectedSigner].clear());
  }

  void _notify(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  void _confirm() {
    if (_strokes.any((group) => !group.any((stroke) =>
        stroke.length > 1 &&
        (stroke.first - stroke.last).distance > 0.003))) {
      _notify('Please draw both the customer and your signatures.');
      return;
    }
    if (!widget.quote.isDemo) {
      _notify('In-person signing requires a trusted signing service. '
          'This screen is UI-only.');
      return;
    }

    Navigator.of(context).push<void>(MaterialPageRoute<void>(
      builder: (_) => DocumentSignedSuccessScreen(
        data: QuoteSignedDisplayData(
          documentId: 'ui-demo-in-person-document',
          quoteNumber: widget.quote.quoteNumber,
          projectName: widget.projectName,
          signerName: widget.quote.clientName,
          // Fixed visual fixture, not a signing-event timestamp.
          signedAt: DateTime(2026, 8, 23, 22),
          demoOnly: true,
        ),
        onClose: () {
          Navigator.of(context).pop();
          Navigator.of(context).pop();
        },
      ),
    ));
  }

  Widget _quoteCard() => Sign2DigitalOutlinedContainer(
    padding: const EdgeInsets.all(20),
    child: Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFFE3ECF0),
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.description_outlined,
            color: AppColors.dark,
            size: 23,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Quote # ${widget.quote.quoteNumber}',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.3,
                  color: AppColors.dark,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                widget.projectName,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.placeholder,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _tabs() => SizedBox(
    width: double.infinity,
    child: Stack(
      children: [
        const Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Divider(
            height: 1,
            thickness: 1,
            color: _border,
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < 2; index++) ...[
              if (index > 0) const SizedBox(width: 30),
              InkWell(
                key: Key('in-person-tab-$index'),
                onTap: () => setState(() => _selectedSigner = index),
                child: Container(
                  padding: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: index == _selectedSigner
                            ? AppColors.primary
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Text(
                    index == 0 ? 'Customer Signature' : 'Your Signature',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.3,
                      color: index == _selectedSigner
                          ? AppColors.primary
                          : AppColors.placeholder,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    ),
  );

  Widget _canvas() => Container(
    height: 250,
    decoration: BoxDecoration(
      color: _surface,
      border: Border.all(color: _border),
      borderRadius: BorderRadius.circular(10),
    ),
    clipBehavior: Clip.antiAlias,
    child: Stack(
      children: [
        Positioned.fill(
          bottom: 50,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = Size(
                constraints.maxWidth,
                constraints.maxHeight,
              );
              return RawGestureDetector(
                key: const Key('in-person-draw-canvas'),
                behavior: HitTestBehavior.opaque,
                gestures: <Type, GestureRecognizerFactory>{
                  EagerGestureRecognizer:
                      GestureRecognizerFactoryWithHandlers<
                          EagerGestureRecognizer>(
                    () => EagerGestureRecognizer(),
                    (instance) {},
                  ),
                },
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (event) =>
                      _start(event.localPosition, size),
                  onPointerMove: (event) =>
                      _update(event.localPosition, size),
                  child: CustomPaint(
                    painter: _InPersonStrokePainter(
                      _strokes[_selectedSigner],
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              );
            },
          ),
        ),
        Positioned(
          bottom: 8,
          right: 10,
          child: TextButton.icon(
            key: const Key('in-person-clear'),
            onPressed: _clear,
            icon: SvgPicture.asset(
              'assets/icons_2/arrow-reset.svg',
              width: 20,
              height: 20,
              colorFilter: const ColorFilter.mode(
                AppColors.primary, BlendMode.srcIn,
              ),
            ),
            label: const Text(
              'Clear',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: SafeArea(
      child: Column(
        children: [
          Sign2DigitalHeader(
            title: 'In-Person Signature',
            onBack: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, viewport) => SingleChildScrollView(
                key: const Key('in-person-signature-scroll'),
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 36),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: viewport.maxHeight - 36,
                      ),
                      child: IntrinsicHeight(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _quoteCard(),
                            const SizedBox(height: 20),
                            _tabs(),
                            const SizedBox(height: 25),
                            _canvas(),
                            const SizedBox(height: 20),
                            const Sign2DigitalInfoBanner(
                              iconAsset: 'assets/icons_2/fingerprint.svg',
                              verticalPadding: 10,
                              textColor: AppColors.placeholder,
                              message:
                                  'By signing you confirm that you have agreed '
                                  'to our terms & conditions and services.',
                            ),
                            const Spacer(),
                            const SizedBox(height: 30),
                            Sign2DigitalPrimaryButton(
                              label: 'Confirm Signature',
                              onPressed: _confirm,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _InPersonStrokePainter extends CustomPainter {
  const _InPersonStrokePainter(this.strokes);

  final List<List<Offset>> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.dark
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      if (stroke.length < 2) continue;
      final start = stroke.first;
      final path = Path()
        ..moveTo(start.dx * size.width, start.dy * size.height);
      for (final point in stroke.skip(1)) {
        path.lineTo(point.dx * size.width, point.dy * size.height);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _InPersonStrokePainter oldDelegate) => true;
}
