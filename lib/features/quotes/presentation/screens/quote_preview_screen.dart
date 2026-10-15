import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../widgets/sign2digital_financial_document_sections.dart';
import '../../../../core/widgets/sign2digital_header.dart';
import '../../domain/quote_document_tracking.dart';
import '../../domain/quote_review_models.dart';
import '../../../clients/presentation/widgets/sign2digital_status_badge.dart';
import '../../services/quote_pdf_service.dart';
import 'send_quote_screen.dart';

/// Mobile representation of the same structured quote sent to the PDF builder.
/// A locally validated quote is not represented as server-approved or delivered.
class QuotePreviewScreen extends StatefulWidget {
  const QuotePreviewScreen({
    super.key,
    required this.quote,
    this.customerView = false,
    this.documentTitle = 'Quote',
    this.description,
    this.tracking,
    this.onReviewAndSign,
    this.demoReviewEnabled = false,
    this.onInPersonSign,
  });

  final QuoteReviewDraft quote;

  /// Customer mode reuses the same billing, work item, payment and terms UI.
  /// Business Quote Preview retains its original layout by default.
  final bool customerView;
  final String documentTitle;
  final String? description;
  final QuoteDocumentTracking? tracking;
  final Future<void> Function(QuoteReviewDraft quote)? onReviewAndSign;
  /// Enable a local signing UI demonstration only for explicitly demo quotes.
  final bool demoReviewEnabled;
  /// Optional owner-initiated flow; supplied only by a connected signing route.
  final VoidCallback? onInPersonSign;

  @override
  State<QuotePreviewScreen> createState() => _QuotePreviewScreenState();
}

class _QuotePreviewScreenState extends State<QuotePreviewScreen> {
  bool _busy = false;
  late final QuoteReviewDraft _quote = widget.quote.copy();
  static const _border = AppColors.lightBorder;

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  QuoteDocumentTracking? get _matchingTracking =>
      widget.tracking?.quoteId == _quote.id ? widget.tracking : null;

  String get _customerStatus {
    final tracking = _matchingTracking;
    if (tracking == null) return 'Not sent';
    if (tracking.completed) return 'Completed';
    if (tracking.signed) return 'Signed';
    if (tracking.viewed) return 'Viewed by Customer';
    if (tracking.requestIsActive) return 'Sent for signature';
    if (tracking.sent) return 'Document sent';
    return 'Not sent';
  }

  Future<void> _reviewAndSign() async {
    final tracking = _matchingTracking;
    if (_quote.isDemo && !widget.demoReviewEnabled) {
      _message('Figma demo: electronic signing is not available.');
      return;
    }
    if (!(widget.demoReviewEnabled && _quote.isDemo) &&
        (tracking == null || tracking.requestId == null ||
        tracking.usableUrl(DateTime.now()) == null || !tracking.sent ||
        tracking.signed || tracking.completed)) {
      _message('A valid, active signature request is required to sign.');
      return;
    }
    if (widget.onReviewAndSign == null) {
      _message('The electronic signature workflow is not connected yet.');
      return;
    }
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onReviewAndSign!(_quote.copy());
    } catch (error) {
      _message('Could not open signing workflow: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _customerHeading() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(children: [
        Expanded(child: Text(
          'Quote ${_quote.quoteNumber.trim().isEmpty ? '—' : _quote.quoteNumber}',
          key: const Key('customer-document-quote-number'),
          style: _text(24, weight: FontWeight.bold),
          softWrap: true,
        )),
        const SizedBox(width: 20),
        Flexible(child: Sign2DigitalStatusBadge(status: _customerStatus)),
      ]),
      if (widget.description != null && widget.description!.trim().isNotEmpty) ...[
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.only(left: 20),
          child: Text(widget.description!.trim(),
            key: const Key('customer-document-description'),
            style: _text(14, color: AppColors.secondaryText)),
        ),
      ],
      const SizedBox(height: 20),
    ],
  );

  Widget _customerAction() => SizedBox(
    width: double.infinity,
    height: 48,
    child: FilledButton(
      key: const Key('customer-document-review-sign'),
      onPressed: _busy ? null : _reviewAndSign,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10)),
      ),
      child: Text('Review and Sign', style: _text(16, color: Colors.white)),
    ),
  );

  String get _filename {
    final number = _quote.quoteNumber.trim().isEmpty ? 'draft' : _quote.quoteNumber;
    final sanitized = number.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    return 'Sign2Digital_Quote_$sanitized.pdf';
  }

  Future<void> _downloadPdf() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final bytes = await const Sign2DigitalQuotePdfBuilder().build(_quote);
      final path = await FilePicker.saveFile(
        dialogTitle: 'Save Quote PDF', fileName: _filename,
        type: FileType.custom, allowedExtensions: ['pdf'], bytes: bytes,
      );
      if (path != null) _message('PDF saved to the selected location.');
    } catch (error) {
      _message('Could not save PDF: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _sendToCustomer() {
    if (_busy) return;
    if (!_quote.approvedLocally || _quote.approvalIssues.isNotEmpty) {
      _message('Complete and validate the quote in Review Quote before sharing.');
      return;
    }
    Navigator.of(context).push<void>(MaterialPageRoute<void>(
      builder: (_) => SendQuoteScreen(quote: _quote.copy()),
    ));
  }

  TextStyle _text(double size, {Color color = AppColors.dark,
      FontWeight weight = FontWeight.w500}) => TextStyle(
    fontFamily: 'Inter', fontSize: size, fontWeight: weight, color: color,
    letterSpacing: -0.3,
  );

  Sign2DigitalFinancialDocumentSections get _sections =>
      Sign2DigitalFinancialDocumentSections(
        document: _quote,
        documentTitle: widget.customerView ? widget.documentTitle : 'Quote',
        showSignature: !widget.customerView,
      );

  Widget _quoteDocument() => _sections.invoiceOrQuoteDocument();
  Widget _paymentDetails() => _sections.paymentDetails();
  Widget _terms() => _sections.terms();

  Widget _actions() => LayoutBuilder(builder: (context, constraints) {
    final save = SizedBox(height: 48, child: OutlinedButton(
      key: const Key('quote-preview-download'),
      onPressed: _busy ? null : _downloadPdf,
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: AppColors.primary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
      child: Text('Download PDF', textAlign: TextAlign.center,
        style: _text(16, color: AppColors.primary)),
    ));
    final send = SizedBox(height: 48, child: FilledButton(
      key: const Key('quote-preview-share'),
      onPressed: _busy ? null : _sendToCustomer,
      style: FilledButton.styleFrom(backgroundColor: AppColors.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
      child: Text('Send to Customer', textAlign: TextAlign.center,
        style: _text(16, color: Colors.white)),
    ));
    if (constraints.maxWidth < 350) {
      return Column(children: [
        SizedBox(width: double.infinity, child: save),
        const SizedBox(height: 10),
        SizedBox(width: double.infinity, child: send),
      ]);
    }
    return Row(children: [Expanded(child: save), const SizedBox(width: 10),
      Expanded(child: send)]);
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: SafeArea(child: Column(children: [
      Sign2DigitalHeader(title: widget.customerView ? 'Create Quote' : 'Quote Preview',
          onBack: () => Navigator.of(context).maybePop()),
      Expanded(child: SingleChildScrollView(
        key: const Key('quote-preview-scroll'),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
        child: Center(child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_quote.isDemo) Padding(
                padding: const EdgeInsets.only(bottom: 15),
                child: Text('FIGMA DEMO — no AI quote or server approval has occurred.',
                  style: _text(12, color: const Color(0xFFE6A23C)))),
              if (widget.customerView) _customerHeading(),
              _quoteDocument(),
              const SizedBox(height: 20),
              _paymentDetails(),
              const SizedBox(height: 20),
              _terms(),
              const SizedBox(height: 60),
              if (widget.customerView) _customerAction() else _actions(),
              if (!widget.customerView && widget.onInPersonSign != null) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    key: const Key('quote-preview-in-person-sign'),
                    onPressed: widget.onInPersonSign,
                    icon: const Icon(Icons.draw_outlined),
                    label: const Text('In-Person Signature'),
                  ),
                ),
              ],
            ]),
        )),
      )),
    ])),
  );
}
