import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/features/quotes/domain/quote_review_models.dart';
import 'package:sign2digital/features/quotes/services/quote_pdf_service.dart';

void main() {
  testWidgets('M7 quote PDF exports a complete deposit and item-details example',
      (tester) async {
    final quote = QuoteReviewDraft(
      id: 'm7-export-smoke',
      clientName: 'Flutter Db',
      quoteNumber: 'M6-TEST-003',
      billingAddress: 'Sample Street 47',
      clientEmail: 'customer@example.test',
      date: DateTime(2026, 11, 3),
      validUntil: DateTime(2026, 11, 28),
      currency: 'CHF',
      vatBasisPoints: 2000,
      depositBasisPoints: 3000,
      terms: 'Payment in 30 days.',
      items: [
        QuoteReviewWorkItem(
          id: 'bricks', title: 'Bricks',
          description: 'Exterior repair', dimensions: '3 m x 4 m',
          quantity: '4', unitPrice: '150.00',
        ),
      ],
    );
    expect(quote.depositMinor, 21600);
    expect(quote.remainingAfterDepositMinor, 50400);
    final bytes = await const Sign2DigitalQuotePdfBuilder().build(quote);
    expect(bytes.length, greaterThan(1000));
    expect(bytes.take(5), equals([0x25, 0x50, 0x44, 0x46, 0x2d]));
  });
}
