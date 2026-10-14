import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../widgets/sign2digital_document_items_table.dart';
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

  static String _date(DateTime? date) => date == null
      ? 'Not specified'
      : '${date.day} ${_months[date.month - 1]} ${date.year}';
  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  TextStyle _text(double size, {Color color = AppColors.dark,
      FontWeight weight = FontWeight.w500}) => TextStyle(
    fontFamily: 'Inter', fontSize: size, fontWeight: weight, color: color,
    letterSpacing: -0.3,
  );

  Widget _card({required Widget child, EdgeInsets padding = EdgeInsets.zero}) =>
      Container(decoration: BoxDecoration(color: Colors.white,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(10)),
        padding: padding, child: child);

  Widget _billingSection() => LayoutBuilder(builder: (context, constraints) {
    final billTo = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Bill To:', style: _text(14, weight: FontWeight.w600)),
      const SizedBox(height: 9),
      for (final line in [
        _quote.clientName, _quote.billingAddress,
        _quote.clientEmail, _quote.clientPhone,
      ]) if (line.trim().isNotEmpty) ...[
        Text(line, style: _text(12, color: AppColors.placeholder)),
        const SizedBox(height: 5),
      ],
    ]);
    final dates = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _dateLine('Date:', _date(_quote.date)),
      const SizedBox(height: 9),
      _dateLine('Valid Until:', _date(_quote.validUntil)),
    ]);
    if (constraints.maxWidth < 340) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [billTo, const SizedBox(height: 15), dates],
      );
    }
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: billTo), const SizedBox(width: 16),
      Expanded(child: dates),
    ]);
  });

  Widget _dateLine(String label, String value) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(width: 76, child: Text(label,
        softWrap: false, maxLines: 1,
        style: _text(12, weight: FontWeight.w600))),
      const SizedBox(width: 7),
      Expanded(child: Text(value,
        style: _text(12, color: AppColors.placeholder))),
    ],
  );

  Widget _itemsTable() => Sign2DigitalDocumentItemsTable(
    key: const Key('quote-preview-items-table'),
    items: [
      for (final item in _quote.items)
        Sign2DigitalDocumentTableLine(
          description: item.title.isEmpty ? 'Unspecified item' : item.title,
          quantity: item.quantity.isEmpty ? '—' : item.quantity,
          unitPrice: quoteMoney(item.priceMinor, _quote.currency),
          total: quoteMoney(item.totalMinor, _quote.currency),
        ),
    ],
  );

  Widget _amountRow(String label, String value, {bool total = false}) =>
      Sign2DigitalDocumentAmountRow(
        label: label, value: value, highlight: total);

  Widget _quoteDocument() => _card(child: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(padding: const EdgeInsets.fromLTRB(20, 25, 20, 0),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Flexible(child: Image.asset('assets/header_logo.png',
              key: const Key('quote-preview-logo'), width: 132, height: 43,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => Text('Company logo unavailable',
                style: _text(10, color: AppColors.placeholder)))),
            const SizedBox(width: 8),
            Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.end,
              children: [Text(widget.customerView ? widget.documentTitle : 'Quote',
                key: const Key('quote-preview-document-title'),
                style: _text(18, weight: FontWeight.bold)),
                const SizedBox(height: 9),
                Text(_quote.quoteNumber.isEmpty ? 'Unnumbered draft'
                      : _quote.quoteNumber,
                  textAlign: TextAlign.right,
                  style: _text(12, color: AppColors.placeholder))])),
          ])),
      Padding(padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        child: _billingSection()),
      _itemsTable(),
      if (!_quote.allItemPricesValid)
        Padding(padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Text('Pricing incomplete — missing values are not zero.',
            style: _text(11, color: const Color(0xFFE6A23C)))),
      const SizedBox(height: 10),
      Padding(
        padding: const EdgeInsets.only(right: 20),
        child: Align(
          alignment: Alignment.centerRight,
          child: FractionallySizedBox(
            widthFactor: 0.75,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _amountRow('Subtotal', quoteMoney(_quote.subtotalMinor, _quote.currency)),
                _amountRow('Tax (${(_quote.vatBasisPoints / 100).toStringAsFixed(0)}%)',
                    quoteMoney(_quote.vatMinor, _quote.currency)),
                _amountRow('Total', quoteMoney(_quote.totalMinor, _quote.currency),
                    total: true),
              ],
            ),
          ),
        ),
      ),
      if (widget.customerView)
        const SizedBox(height: 25)
      else ...[
        const SizedBox(height: 80),
        Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 25),
          child: Row(children: [
            for (var i = 0; i < 2; i++) ...[
              if (i > 0) const SizedBox(width: 20),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 2, color: AppColors.placeholder),
                  const SizedBox(height: 7),
                  Text(i == 0 ? 'Customer Signature' : 'Date',
                    style: _text(10, color: AppColors.placeholder)),
                ],
              )),
            ],
          ])),
      ],
    ]));

  Widget _paymentDetails() {
    final payment = _quote.payment;
    final payload = _quote.isDemo ? null : payment?.swissQrBillPayload(
      currency: _quote.currency, amountMinor: _quote.totalMinor);
    return _card(padding: const EdgeInsets.all(15), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Payment Details', style: _text(14, weight: FontWeight.w600)),
        const SizedBox(height: 5),
        Text(payload == null ? 'Payment QR unavailable' : 'Scan to Pay',
            style: _text(12)),
        const SizedBox(height: 20),
        if (payload == null)
          Text('A valid Swiss payment account, payee address and payable amount '
            'are needed to display a payment QR.',
            style: _text(12, color: AppColors.placeholder))
        else Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 92, height: 92, padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.primary.withAlpha(20),
              borderRadius: BorderRadius.circular(10)),
            child: QrImageView(data: payload, size: 76, version: QrVersions.auto)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _paymentField('Account / payable to', payment!.iban),
              _paymentField('Company Name', payment.accountHolder),
              _paymentField('Payable amount', quoteMoney(_quote.totalMinor, _quote.currency)),
              _paymentField('Currency', _quote.currency),
            ])),
        ]),
      ]));
  }

  Widget _paymentField(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: _text(10)),
      Text(value, softWrap: true,
        style: _text(10, color: AppColors.placeholder)),
    ]));

  Widget _terms() => Column(crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('General Terms & Conditions',
        style: _text(15, weight: FontWeight.w600)),
      const SizedBox(height: 15),
      Text(_quote.terms.isEmpty ? 'No terms and conditions have been provided.'
        : _quote.terms, style: _text(14, color: AppColors.placeholder)),
    ]);

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
