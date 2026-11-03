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
}
