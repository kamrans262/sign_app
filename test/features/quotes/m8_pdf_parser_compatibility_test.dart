import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/features/quotes/domain/quote_review_models.dart';
import 'package:sign2digital/features/quotes/services/quote_pdf_service.dart';

void main() {
  testWidgets('M8 approval PDF is classic xref PDF 1.4 for the FPDI importer',
      (tester) async {
    final quote = QuoteReviewDraft(
      id: 'm8-fpdi-source', jobId: 'job-9',
      quoteNumber: 'Q-2026-000099',
      clientName: 'External Signing Customer',
      clientEmail: 'signer@example.test',
      billingAddress: 'Example Street',
      date: DateTime.utc(2026, 11, 4),
      validUntil: DateTime.utc(2026, 12, 4),
      currency: 'CHF',
      vatBasisPoints: 810,
      depositBasisPoints: 3000,
      terms: 'Payment in 30 days and customer signing consent.',
      items: [
        QuoteReviewWorkItem(
          id: '1', title: 'Repair electrical system',
          description: 'Materials and labour',
          quantity: '2', unitPrice: '125.00',
        ),
      ],
    );
    final bytes = await const Sign2DigitalQuotePdfBuilder().build(quote);
    expect(bytes.length, inInclusiveRange(1000, 5 * 1024 * 1024));
    final header = latin1.decode(bytes.take(8).toList());
    expect(header, '%PDF-1.4');
    final body = latin1.decode(bytes);
    expect(RegExp(r'(?m)^xref\\s*\\r?$').hasMatch(body), isTrue,
        reason: 'FPDI free requires a classic cross-reference table.');
    expect(body.contains('/Type /XRef'), isFalse,
        reason: 'Compressed xref streams break the free FPDI parser.');
    expect(body.contains('%%EOF'), isTrue);
  });
}
