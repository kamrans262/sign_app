import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/features/quotes/domain/quote_review_models.dart';

void main() {
  test('VAT and deposit percentages round-trip through review edit text', () {
    for (final basisPoints in <int>[0, 5, 100, 125, 800, 810, 825, 1000, 10000]) {
      final display = quotePercentText(basisPoints);
      expect(parseQuoteMinorUnits(display), basisPoints,
          reason: 'Rate $basisPoints basis points must survive opening and saving Edit Details.');
    }
    expect(quotePercentText(810), '8.1');
    expect(quotePercentText(825), '8.25');
    expect(quotePercentText(800), '8');
    expect(quotePercentText(10000), '100');
  });

  test('fractional VAT calculation remains in integer minor currency units', () {
    expect(percentOfMinor(10000, 810), 810);
    expect(percentOfMinor(10000, 825), 825);
    expect(percentOfMinor(1999, 810), 162);
  });
  test('approved quote deposit and remaining never replace grand total', () {
    final quote = QuoteReviewDraft(
      id:'m7-balance', clientName:'Client', date:DateTime(2026,11,3),
      currency:'CHF', vatBasisPoints:2000, depositBasisPoints:3000,
      terms:'Terms', items:[
        QuoteReviewWorkItem(id:'brick',title:'Bricks',description:'Exterior repair',
          dimensions:'3 m x 4 m',quantity:'4',unitPrice:'150.00'),
      ],
    );
    expect(quote.subtotalMinor,60000);
    expect(quote.vatMinor,12000);
    expect(quote.totalMinor,72000);
    expect(quote.depositMinor,21600);
    expect(quote.remainingAfterDepositMinor,50400);
    expect(quote.totalMinor,72000); // Deposit is not removed from total.
    expect(quoteWorkItemDocumentText(quote.items.single),
      'Bricks\nExterior repair\nDimensions: 3 m x 4 m');
  });

}
