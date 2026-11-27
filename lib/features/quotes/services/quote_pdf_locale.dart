import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:intl/intl.dart';

import '../../../core/localization/app_language_controller.dart';
import '../../../core/localization/app_strings.dart';

/// Static PDF copy only. Never pass user text, numbers or signature data.
abstract final class QuotePdfLocale {
  static String selectedCode() => AppLanguageController.shared
      .effectiveLocale(PlatformDispatcher.instance.locales).languageCode;

  static const _extras = <String, Map<String, String>>{
    'Deposit due': {'fr': 'Acompte dû', 'de': 'Anzahlung fällig', 'it': 'Acconto dovuto'},
    'Pricing incomplete - unresolved work item prices.': {
      'fr': 'Tarification incomplète : prix des prestations manquants.',
      'de': 'Preisangaben unvollständig: Positionen ohne Preis.',
      'it': 'Prezzi incompleti: voci senza prezzo.',
    },
    'A valid Swiss payment account, address and payable amount are required before a payment QR can be displayed.': {
      'fr': "Un compte suisse valide, une adresse et un montant à payer sont nécessaires pour afficher un QR de paiement.",
      'de': 'Für den Zahlungs-QR sind ein gültiges Schweizer Konto, eine Adresse und der Zahlbetrag erforderlich.',
      'it': "Per mostrare il QR di pagamento servono un conto svizzero valido, un indirizzo e l'importo dovuto.",
    },
  };

  static String tr(String english, String localeCode) =>
      _extras[english]?[localeCode] ??
      AppStrings(Locale(localeCode)).tr(english);

  static String date(DateTime? value, String localeCode) {
    if (value == null) return tr('Not specified', localeCode);
    if (localeCode == 'de') return DateFormat('dd.MM.yyyy').format(value);
    return DateFormat('dd/MM/yyyy').format(value);
  }
}
