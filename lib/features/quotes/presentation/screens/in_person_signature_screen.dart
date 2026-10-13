import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sign2digital_header.dart';
import '../../../../core/widgets/sign2digital_info_banner.dart';
import '../../../../core/widgets/sign2digital_primary_button.dart';
import '../../domain/quote_review_models.dart';
import '../../domain/quote_signature_draft.dart';
import '../widgets/sign2digital_quote_summary_card.dart';
import '../widgets/sign2digital_signature_consent.dart';
import '../widgets/sign2digital_signature_draw_canvas.dart';
import '../widgets/sign2digital_signature_tabs.dart';
import 'document_signed_success_screen.dart';

/// UI capture only. A caller-owned trusted service must confirm the submitted
/// document/signers before this page can show real signing success.
class InPersonSignatureScreen extends StatefulWidget {
  const InPersonSignatureScreen({
    super.key,
    required this.quote,
    required this.projectName,
    required this.documentId,
    required this.customerSignerId,
    required this.businessSignerId,
    this.customerTabLabel = 'Costumer Signature',
    this.onSubmit,
  });

  final QuoteReviewDraft quote;
  final String projectName;
  final String documentId;
  final String customerSignerId;
  final String businessSignerId;
  final String customerTabLabel;

  /// Return confirmation data only after the required authorized submission.
  /// A clearly marked demo may return fixture data for manual UI testing.
  final Future<QuoteSignedDisplayData?> Function(
    QuoteInPersonSignatureSubmission draft,
  )? onSubmit;

  @override
  State<InPersonSignatureScreen> createState() => _InPersonSignatureScreenState();
}

class _InPersonSignatureScreenState extends State<InPersonSignatureScreen> {
  static const _border = AppColors.lightBorder;
  static const _canvasColor = Color(0x1A8A9AA8);
  late final String _customerKey;
  late final String _businessKey;
  late final QuoteSignatureLocalDraft _customer;
  late final QuoteSignatureLocalDraft _business;
  int _selected = 0;
  bool _submitting = false;
  bool _completed = false;

  QuoteSignatureLocalDraft get _active =>
      _selected == 0 ? _customer : _business;

  @override
  void initState() {
    super.initState();
    _customerKey = QuoteSignatureDraftSession.key(
      widget.quote.id,
      widget.documentId,
      'in-person-customer:${widget.customerSignerId}',
    );
    _businessKey = QuoteSignatureDraftSession.key(
      widget.quote.id,
      widget.documentId,
      'in-person-business:${widget.businessSignerId}',
    );
    _customer = QuoteSignatureDraftSession.retrieve(_customerKey) ??
        QuoteSignatureLocalDraft();
    _business = QuoteSignatureDraftSession.retrieve(_businessKey) ??
        QuoteSignatureLocalDraft();
  }

  void _saveDrafts() {
    QuoteSignatureDraftSession.save(_customerKey, _customer);
    QuoteSignatureDraftSession.save(_businessKey, _business);
  }

  @override
  void dispose() {
    if (!_completed) _saveDrafts();
    super.dispose();
  }

  void _notice(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  Offset _normal(Offset point, Size size) => Offset(
    (point.dx / size.width).clamp(0.0, 1.0).toDouble(),
    (point.dy / size.height).clamp(0.0, 1.0).toDouble(),
  );

  void _start(Offset position, Size size) {
    if (_submitting) return;
    setState(() => _active.strokes.add([_normal(position, size)]));
  }

  void _update(Offset position, Size size) {
    if (_submitting || _active.strokes.isEmpty) return;
    setState(() => _active.strokes.last.add(_normal(position, size)));
  }

  void _clear() {
    if (_submitting) return;
    setState(() => _active.strokes.clear());
    _saveDrafts();
  }

  bool _hasSignature(QuoteSignatureLocalDraft draft) =>
      draft.strokes.any((stroke) =>
        stroke.length > 2 ||
        (stroke.length > 1 && (stroke.first - stroke.last).distance > 0.003));

  List<List<Offset>> _copyStrokes(QuoteSignatureLocalDraft draft) =>
      List<List<Offset>>.unmodifiable(
        draft.strokes.map((stroke) => List<Offset>.unmodifiable(stroke)),
      );

  Future<void> _confirm() async {
    if (_submitting) return;
    if (!_hasSignature(_active)) {
      _notice('Please draw a signature before confirming.');
      return;
    }
    if (!_hasSignature(_customer) || !_hasSignature(_business)) {
      setState(() => _selected = _hasSignature(_customer) ? 1 : 0);
      _saveDrafts();
      _notice('Please add the other required signature.');
      return;
    }
    if (widget.documentId.trim().isEmpty ||
        widget.customerSignerId.trim().isEmpty ||
        widget.businessSignerId.trim().isEmpty ||
        widget.customerSignerId == widget.businessSignerId ||
        widget.quote.terms.trim().isEmpty) {
      _notice('Valid document, separate signer IDs, and terms are required.');
      return;
    }
    if (widget.onSubmit == null) {
      _saveDrafts();
      _notice('Signature drafts saved locally. A signing service is not connected.');
      return;
    }
    setState(() => _submitting = true);
    try {
      final accepted =
          await showSign2DigitalSignatureConsent(context, widget.quote.terms);
      if (!mounted || !accepted) return;
      final submission = QuoteInPersonSignatureSubmission(
        quoteId: widget.quote.id,
        documentId: widget.documentId,
        customerSignerId: widget.customerSignerId,
        businessSignerId: widget.businessSignerId,
        customerStrokes: _copyStrokes(_customer),
        businessStrokes: _copyStrokes(_business),
        capturedAt: DateTime.now().toUtc(),
        consentAccepted: true,
      );
      final result = await widget.onSubmit!(submission);
      if (!mounted) return;
      if (result == null || result.documentId != widget.documentId ||
          result.quoteNumber != widget.quote.quoteNumber ||
          (result.demoOnly && !widget.quote.isDemo)) {
        _notice('Signing was not confirmed. Your drafts were preserved.');
        return;
      }
      _completed = true;
      QuoteSignatureDraftSession.clear(_customerKey);
      QuoteSignatureDraftSession.clear(_businessKey);
      Navigator.of(context).pushReplacement<void, void>(
        MaterialPageRoute<void>(
          builder: (_) => DocumentSignedSuccessScreen(data: result),
        ),
      );
    } catch (_) {
      _notice('Could not confirm signing. Your drafts were preserved.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _canvas() => Container(
    key: const Key('in-person-signature-panel'),
    height: 258,
    decoration: BoxDecoration(
      color: _canvasColor,
      border: Border.all(color: _border),
      borderRadius: BorderRadius.circular(10),
    ),
    clipBehavior: Clip.antiAlias,
    child: Stack(
      children: [
        Positioned.fill(
          bottom: 55,
          child: Sign2DigitalSignatureDrawCanvas(
            key: const Key('in-person-draw-canvas'),
            strokes: _active.strokes,
            onStart: _start,
            onUpdate: _update,
            onEnd: _saveDrafts,
          ),
        ),
        Sign2DigitalSignatureClearButton(
          key: const Key('in-person-clear'),
          onPressed: _clear,
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
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Sign2DigitalQuoteSummaryCard(
                                quoteNumber: widget.quote.quoteNumber,
                                projectName: widget.projectName,
                                subtitleGap: 3,
                              ),
                              const SizedBox(height: 20),
                              Sign2DigitalSignatureTabs(
                                keyPrefix: 'in-person-tab',
                                labels: [widget.customerTabLabel, 'Your Signature'],
                                ids: const ['customer', 'business'],
                                selectedIndex: _selected,
                                onSelected: (index) {
                                  if (_submitting) return;
                                  _saveDrafts();
                                  setState(() => _selected = index);
                                },
                              ),
                              const SizedBox(height: 25),
                              _canvas(),
                              const SizedBox(height: 20),
                              const Sign2DigitalInfoBanner(
                                iconAsset: 'assets/icons_2/fingerprint.svg',
                                verticalPadding: 10,
                                iconSize: 24,
                                iconGap: 10,
                                fontSize: 14,
                                textColor: AppColors.placeholder,
                                message: 'By signing you confirmed that you '
                                    'have agreed to our terms of conditions and services',
                              ),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 40),
                            child: Sign2DigitalPrimaryButton(
                              label: 'Confirm Signature',
                              onPressed: _confirm,
                              loading: _submitting,
                            ),
                          ),
                        ],
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
