import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:intl/intl.dart';

import '../../../core/localization/app_language_controller.dart';
import '../../../core/localization/app_strings.dart';

/// Static PDF copy only. Never pass user text, numbers or signature data.
abstract final class QuotePdfLocale {
  static String selectedCode() => AppLanguageController.shared
      .effectiveLocale(PlatformDispatcher.instance.locales).languageCode;

  static const _extras = <String, Map<String, String>>{
    'Project:': {'fr':'Projet :','de':'Projekt:','it':'Progetto:'},
    'Status:': {'fr':'Statut :','de':'Status:','it':'Stato:'},
    'No itemized lines recorded': {'fr':'Aucun poste enregistré','de':'Keine Positionen erfasst','it':'Nessuna voce registrata'},
    'Deposit paid': {'fr':'Acompte payé','de':'Anzahlung bezahlt','it':'Acconto pagato'},
    'Received via recorded payments': {'fr':'Paiements enregistrés reçus','de':'Erfasste Zahlungen eingegangen','it':'Pagamenti registrati ricevuti'},
    'Amount due': {'fr':'Montant dû','de':'Offener Betrag','it':'Importo dovuto'},
    'Original document': {'fr':'Document original','de':'Ursprüngliches Dokument','it':'Documento originale'},
    'Original reference': {'fr':'Référence d’origine','de':'Ursprüngliche Referenz','it':'Riferimento originale'},
    'Addendum reference': {'fr':'Référence de l’avenant','de':'Nachtragsreferenz','it':'Riferimento addendum'},
    'Effective date': {'fr':'Date d’effet','de':'Wirksamkeitsdatum','it':'Data di efficacia'},
    'Change description': {'fr':'Description de la modification','de':'Beschreibung der Änderung','it':'Descrizione modifica'},
    'Additional work': {'fr':'Travaux supplémentaires','de':'Zusatzarbeiten','it':'Lavori aggiuntivi'},
    'Unit price': {'fr':'Prix unitaire','de':'Stückpreis','it':'Prezzo unitario'},
    'Additional work subtotal': {'fr':'Sous-total des travaux supplémentaires','de':'Zwischensumme Zusatzarbeiten','it':'Subtotale lavori aggiuntivi'},
    'Addendum total': {'fr':'Total de l’avenant','de':'Nachtragssumme','it':'Totale addendum'},
    'UNSIGNED - customer approval and signature not confirmed': {
      'fr':'NON SIGNÉ - approbation et signature du client non confirmées',
      'de':'NICHT UNTERSCHRIEBEN - Kundenfreigabe und Unterschrift nicht bestätigt',
      'it':'NON FIRMATO - approvazione e firma del cliente non confermate',
    },
    'A validated Swiss payee address, IBAN and amount are required for a scannable payment QR.': {
      'fr':'Une adresse suisse valide, un IBAN et un montant sont nécessaires pour afficher le QR de paiement.',
      'de':'Für einen Zahlungs-QR sind eine gültige Schweizer Empfängeradresse, IBAN und ein Betrag erforderlich.',
      'it':'Per un QR di pagamento serve un indirizzo svizzero valido, un IBAN e un importo.',
    },
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
