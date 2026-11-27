import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/features/quotes/services/quote_pdf_locale.dart';

void main() {
  test('quotation PDF labels and dates use all supported languages', () {
    for (final code in ['en','fr','de','it']) {
      expect(QuotePdfLocale.tr('Quote',code),isNotEmpty);
      expect(QuotePdfLocale.tr('Deposit due',code),isNotEmpty);
      expect(QuotePdfLocale.tr('Customer Signature',code),isNotEmpty);
      expect(QuotePdfLocale.tr('INV-001',code),'INV-001');
    }
    final value = DateTime(2026, 11, 28);
    expect(QuotePdfLocale.date(value,'de'),'28.11.2026');
    expect(QuotePdfLocale.date(value,'fr'),'28/11/2026');
  });
}
