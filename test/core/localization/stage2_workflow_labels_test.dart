import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/core/localization/app_strings.dart';

void main() {
  test('financial, signing and security copy has four-language coverage', () {
    for (final (code, signature, security) in [
      ('en', 'Business Signature Added!', 'Recovery Codes'),
      ('fr', 'Signature de l’entreprise ajoutée !', 'Codes de secours'),
      ('de', 'Firmensignatur hinzugefügt!', 'Wiederherstellungscodes'),
      ('it', 'Firma aziendale aggiunta!', 'Codici di recupero'),
    ]) {
      final strings = AppStrings(Locale(code));
      expect(strings.tr('Business Signature Added!'), signature);
      expect(strings.tr('Recovery Codes'), security);
      final email = strings.format('New email: {email}',
          {'email': 'client+{name}@example.com'});
      expect(email, contains('client+{name}@example.com'));
      expect(strings.tr('INV-2026-123'), 'INV-2026-123');
    }
  });
}
