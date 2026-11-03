import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/quote_review_models.dart';
import 'sign2digital_document_items_table.dart';

/// Quote Preview document sections reused without a second invoice design.
class Sign2DigitalFinancialDocumentSections {
  const Sign2DigitalFinancialDocumentSections({
    required this.document,
    this.documentTitle = 'Quote',
    this.dateLabel = 'Valid Until:',
    this.showSignature = true,
  });

  final QuoteReviewDraft document;
  final String documentTitle, dateLabel;
  final bool showSignature;

  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  static String _date(DateTime? value) => value == null
      ? 'Not specified'
      : '${value.day} ${_months[value.month - 1]} ${value.year}';

  TextStyle _text(double size, {
    Color color = AppColors.dark,
    FontWeight weight = FontWeight.w500,
  }) => TextStyle(
    fontFamily: 'Inter', fontSize: size, fontWeight: weight,
    color: color, letterSpacing: -0.3,
  );

  Widget _card({required Widget child, EdgeInsets padding = EdgeInsets.zero}) =>
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.lightBorder),
          borderRadius: BorderRadius.circular(10),
        ),
        padding: padding,
        child: child,
      );

  // A shared label column keeps both dates in the same vertical value column.
  // Right-aligned labels preserve a small, identical gap after each label.
  Widget _dateLine(String label, String value) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(width: 72, child: Text(label, textAlign: TextAlign.right,
        softWrap: false, maxLines: 1,
        style: _text(12, weight: FontWeight.w600))),
      const SizedBox(width: 6),
      Expanded(child: Text(value,
        style: _text(12, color: AppColors.placeholder))),
    ],
  );

  Widget _billingSection() => LayoutBuilder(
    builder: (context, constraints) {
      final billTo = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Bill To:', style: _text(14, weight: FontWeight.w600)),
          const SizedBox(height: 9),
          for (final value in [
            document.clientName, document.billingAddress,
            document.clientEmail, document.clientPhone,
          ]) if (value.trim().isNotEmpty) ...[
            Text(value, style: _text(12, color: AppColors.placeholder)),
            const SizedBox(height: 5),
          ],
        ],
      );
      final dates = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _dateLine('Date:', _date(document.date)),
          const SizedBox(height: 9),
          _dateLine(dateLabel, _date(document.validUntil)),
        ],
      );
      if (constraints.maxWidth < 340) {
        return Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [billTo, const SizedBox(height: 15), dates]);
      }
      // Keep the right edge of the dates aligned with the Quote number above.
      // A compact right-hand column moves the dates right on portrait phones,
      // while the bill-to details retain the remaining available space.
      final dateWidth = constraints.maxWidth < 420
          ? constraints.maxWidth * .46 : 185.0;
      return Row(crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: billTo),
          const SizedBox(width: 12),
          SizedBox(key: const Key('quote-preview-date-block'),
            width: dateWidth, child: dates),
        ]);
    },
  );

  Widget invoiceOrQuoteDocument() => _card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 25, 20, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(child: Image.asset(
                'assets/header_logo.png', width: 132, height: 43,
                key: const Key('quote-preview-logo'),
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => Text('Company logo unavailable',
                  style: _text(10, color: AppColors.placeholder)),
              )),
              const SizedBox(width: 8),
              Flexible(child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(documentTitle,
                    key: const Key('quote-preview-document-title'),
                    style: _text(18, weight: FontWeight.bold)),
                  const SizedBox(height: 9),
                  Text(document.quoteNumber.isEmpty
                      ? 'Unnumbered draft' : document.quoteNumber,
                    textAlign: TextAlign.right,
                    style: _text(12, color: AppColors.placeholder)),
                ],
              )),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          child: _billingSection(),
        ),
        Sign2DigitalDocumentItemsTable(
          key: const Key('quote-preview-items-table'),
          items: [
            for (final item in document.items)
              Sign2DigitalDocumentTableLine(
                description: quoteWorkItemDocumentText(item),
                quantity: item.quantity.isEmpty ? '—' : item.quantity,
                unitPrice: quoteMoney(item.priceMinor, document.currency),
                total: quoteMoney(item.totalMinor, document.currency),
              ),
          ],
        ),
        if (!document.allItemPricesValid)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Text('Pricing incomplete — missing values are not zero.',
              style: _text(11, color: const Color(0xFFE6A23C))),
          ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.only(right: 20),
          child: Align(
            alignment: Alignment.centerRight,
            child: FractionallySizedBox(
              widthFactor: .75,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Sign2DigitalDocumentAmountRow(
                    label: 'Subtotal',
                    value: quoteMoney(document.subtotalMinor, document.currency)),
                  Sign2DigitalDocumentAmountRow(
                    label: 'Tax (${quotePercentText(document.vatBasisPoints)}%)',
                    value: quoteMoney(document.vatMinor, document.currency)),
                  Sign2DigitalDocumentAmountRow(
                    label: 'Total',
                    value: quoteMoney(document.totalMinor, document.currency),
                    highlight: true),
                  Sign2DigitalDocumentAmountRow(
                    label: 'Deposit due (${quotePercentText(document.depositBasisPoints)}%)',
                    value: quoteMoney(document.depositMinor, document.currency)),
                  Sign2DigitalDocumentAmountRow(
                    label: 'Remaining after deposit',
                    value: quoteMoney(document.remainingAfterDepositMinor,
                        document.currency)),
                ],
              ),
            ),
          ),
        ),
        if (!showSignature)
          const SizedBox(height: 25)
        else ...[
          const SizedBox(height: 80),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 25),
            child: Row(
              children: [
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
              ],
            ),
          ),
        ],
      ],
    ),
  );

  Widget _paymentField(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: _text(10)),
        Text(value, softWrap: true,
          style: _text(10, color: AppColors.placeholder)),
      ],
    ),
  );

  Widget paymentDetails() {
    final payment = document.payment;
    final payload = document.isDemo
        ? null : payment?.swissQrBillPayload(
            currency: document.currency,
            amountMinor: document.totalMinor);
    return _card(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Payment Details',
            style: _text(14, weight: FontWeight.w600)),
          const SizedBox(height: 5),
          Text(payload == null ? 'Payment QR unavailable' : 'Scan to Pay',
            style: _text(12)),
          const SizedBox(height: 20),
          if (payload == null) ...[
            Text('A valid Swiss payment account, payee address and payable '
              'amount are needed to display a payment QR.',
              style: _text(12, color: AppColors.placeholder)),
            const SizedBox(height: 12),
            if (payment != null && payment.iban.trim().isNotEmpty)
              _paymentField('Account / payable to', payment.iban),
            if (payment != null && payment.accountHolder.trim().isNotEmpty)
              _paymentField('Company Name', payment.accountHolder),
            _paymentField('Payable amount',
              quoteMoney(document.totalMinor, document.currency)),
            _paymentField('Currency', document.currency),
          ] else Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 92, height: 92,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(20),
                  borderRadius: BorderRadius.circular(10)),
                child: QrImageView(
                  data: payload, size: 76, version: QrVersions.auto),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _paymentField('Account / payable to', payment!.iban),
                  _paymentField('Company Name', payment.accountHolder),
                  _paymentField('Payable amount',
                    quoteMoney(document.totalMinor, document.currency)),
                  _paymentField('Currency', document.currency),
                ],
              )),
            ],
          ),
        ],
      ),
    );
  }

  Widget terms() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('General Terms & Conditions',
        style: _text(15, weight: FontWeight.w600)),
      const SizedBox(height: 15),
      Text(document.terms.trim().isEmpty
            ? 'No terms and conditions have been provided.'
            : document.terms,
        style: _text(14, color: AppColors.placeholder)),
    ],
  );
}
