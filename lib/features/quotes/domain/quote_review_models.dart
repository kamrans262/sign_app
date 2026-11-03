import '../../../core/services/active_company_session.dart';
import 'quote_draft_input.dart';
import 'quote_extraction_models.dart';

/// All prices are integer minor currency units. No binary floating point money.
int? parseQuoteMinorUnits(String input) {
  final cleaned = input.trim().replaceAll(',', '').replaceAll('£', '')
      .replaceAll(r'$', '').replaceAll('€', '').replaceAll('CHF', '').trim();
  if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(cleaned)) {
    return null;
  }
  final parts = cleaned.split('.');
  final whole = int.tryParse(parts.first);
  if (whole == null || whole > 10000000000) {
    return null;
  }
  final cents = parts.length == 1 ? 0 : int.parse(parts.last.padRight(2, '0'));
  return whole * 100 + cents;
}

String quoteMoney(int? minorUnits, String currency) {
  if (minorUnits == null) {
    return '—';
  }
  final symbol = switch (currency) {
    'GBP' => '£', 'EUR' => '€', 'USD' => r'$', 'CHF' => 'CHF ', _ => '$currency ',
  };
  final raw = (minorUnits ~/ 100).toString();
  final buffer = StringBuffer();
  for (var i = 0; i < raw.length; i++) {
    if (i > 0 && (raw.length - i) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(raw[i]);
  }
  return '$symbol${buffer.toString()}.${(minorUnits % 100).toString().padLeft(2, '0')}';
}

int percentOfMinor(int minorUnits, int basisPoints) =>
    (minorUnits * basisPoints + 5000) ~/ 10000;

class QuoteReviewWorkItem {
  QuoteReviewWorkItem({
    required this.id,
    required this.title,
    required this.description,
    this.quantity = '',
    this.dimensions,
    this.unitPrice = '',
    Map<String, String>? otherFields,
    Set<String>? unresolvedOtherFields,
  }) : otherFields = otherFields ?? <String, String>{},
       unresolvedOtherFields = unresolvedOtherFields ?? <String>{};

  final String id;
  String title;
  String description;
  String quantity;
  String? dimensions; // null means not applicable, empty means missing.
  String unitPrice;
  final Map<String, String> otherFields;
  final Set<String> unresolvedOtherFields;

  int? get validQuantity {
    final amount = int.tryParse(quantity.trim());
    return amount != null && amount > 0 && amount <= 100000 ? amount : null;
  }

  int? get priceMinor => parseQuoteMinorUnits(unitPrice);
  int? get totalMinor {
    final qty = validQuantity;
    final minor = priceMinor;
    if (qty == null || minor == null) {
      return null;
    }
    return minor * qty;
  }

  QuoteReviewWorkItem copy() => QuoteReviewWorkItem(
    id: id, title: title, description: description, quantity: quantity,
    dimensions: dimensions, unitPrice: unitPrice,
    otherFields: Map<String, String>.from(otherFields),
    unresolvedOtherFields: Set<String>.from(unresolvedOtherFields),
  );
}

/// Structured payment instructions. The QR is withheld unless every required
/// Swiss QR-bill field is present and valid (no decorative QR codes).
class QuotePaymentDetails {
  QuotePaymentDetails({
    this.iban = '', this.accountHolder = '', this.street = '',
    this.buildingNumber = '', this.postalCode = '', this.city = '',
    this.country = 'CH', this.paymentReference = '',
  });

  String iban;
  String accountHolder;
  String street;
  String buildingNumber;
  String postalCode;
  String city;
  String country;
  String paymentReference;

  QuotePaymentDetails copy() => QuotePaymentDetails(
    iban: iban, accountHolder: accountHolder, street: street,
    buildingNumber: buildingNumber, postalCode: postalCode, city: city,
    country: country, paymentReference: paymentReference,
  );

  /// Swiss QR-bill v2.0, reference type NON (no structured reference).
  /// Validation is intentionally conservative: a partial account is not a QR.
  String? swissQrBillPayload({required String currency, required int? amountMinor}) {
    final account = iban.replaceAll(' ', '').toUpperCase();
    if (account.length != 21 || !RegExp(r'^(CH|LI)[0-9]{2}[A-Z0-9]{17}$').hasMatch(account)) {
      return null;
    }
    final rearranged = account.substring(4) + account.substring(0, 4);
    var mod = 0;
    for (final rune in rearranged.runes) {
      final n = rune >= 65 && rune <= 90 ? (rune - 55).toString() : String.fromCharCode(rune);
      for (final digit in n.codeUnits) {
        mod = (mod * 10 + (digit - 48)) % 97;
      }
    }
    final iid = int.tryParse(account.substring(4, 9)) ?? 0;
    if (iid >= 30000 && iid <= 31999) {
      // QR-IBAN requires a QR reference (QRR), not the NON reference type.
      return null;
    }
    if (mod != 1 || (currency != 'CHF' && currency != 'EUR') ||
        amountMinor == null || amountMinor <= 0 || amountMinor > 99999999999 ||
        accountHolder.trim().isEmpty || street.trim().isEmpty ||
        postalCode.trim().isEmpty || city.trim().isEmpty ||
        !RegExp(r'^(CH|LI)$').hasMatch(country.trim().toUpperCase()) ||
        paymentReference.trim().isNotEmpty) {
      return null;
    }
    if ([accountHolder, street, buildingNumber, postalCode, city, country]
        .any((field) => field.contains('\n') || field.contains('\r'))) {
      return null;
    }
    final rows = <String>[
      'SPC', '0200', '1', account, 'S', accountHolder.trim(), street.trim(),
      buildingNumber.trim(), postalCode.trim(), city.trim(), country.trim().toUpperCase(),
      '', '', '', '', '', '', '', // ultimate creditor (not used)
      '${amountMinor ~/ 100}.${(amountMinor % 100).toString().padLeft(2, '0')}', currency,
      '', '', '', '', '', '', '', // ultimate debtor (optional)
      'NON', '', '', 'EPD', '', '',
    ];
    return rows.join('\n');
  }
}

class QuoteReviewDraft {
  QuoteReviewDraft({
    required this.id,
    this.clientId,
    this.jobId,
    this.companyId,
    this.sourceNoteId,
    this.clientName = '',
    this.quoteNumber = '',
    required this.date,
    this.currency = 'CHF',
    this.vatBasisPoints = 0,
    this.depositBasisPoints = 0,
    required this.items,
    this.terms = '',
    this.billingAddress = '', this.clientEmail = '', this.clientPhone = '',
    this.validUntil, this.payment,
    this.isDemo = false,
    this.approvedLocally = false,
    this.serverId,
    this.sourceMethod = 'manual',
    this.serverStatus = 'draft',
  });

  final String id;
  String? clientId;
  String? jobId;
  final String? companyId;
  final String? sourceNoteId;
  String clientName;
  String quoteNumber;
  DateTime date;
  String currency;
  int vatBasisPoints;
  int depositBasisPoints;
  final List<QuoteReviewWorkItem> items;
  String terms;
  String billingAddress;
  String clientEmail;
  String clientPhone;
  DateTime? validUntil;
  QuotePaymentDetails? payment;
  final bool isDemo;
  bool approvedLocally;
  /// Server persistence ID, independent of existing Figma route ID.
  int? serverId;
  String sourceMethod;
  String serverStatus;

  /// This fixture is explicitly UI-only; its prices/tax are not AI results.
  factory QuoteReviewDraft.figmaDemo() => QuoteReviewDraft(
    id: 'figma-quote-review-demo', clientName: 'John Smith',
    quoteNumber: 'Q-2026-0043', date: DateTime(2026, 4, 24), currency: 'GBP',
    vatBasisPoints: 2000, depositBasisPoints: 3000, isDemo: true,
    items: [
      QuoteReviewWorkItem(id: 'demo-window', title: 'PVC Windows (Standard)',
        description: 'White PVC frames, standard glazing, including removal of old windows and installation',
        quantity: '1', dimensions: '1.2 m + 1.4 m', unitPrice: '765.00'),
      QuoteReviewWorkItem(id: 'demo-additional', title: 'Additional Works',
        description: 'Making good and finishing', quantity: '1'),
    ],
  );

  /// Only maps genuine source fields. Never invents a price, quote number or client name.
  factory QuoteReviewDraft.fromExtraction(
    QuotePreparationSnapshot snapshot, QuoteDraftInput? source,
  ) {
    if (snapshot.isDemo) {
      throw ArgumentError('Demo extraction must not be treated as a genuine quote.');
    }
    if (snapshot.items.isNotEmpty) {
      final location = snapshot.fields.where((f) =>
          f.id == 'ai-location' && f.value.trim().isNotEmpty);
      final notes = snapshot.fields.where((f) =>
          f.id == 'ai-notes' && f.value.trim().isNotEmpty);
      final additional = <String, String>{
        if (location.isNotEmpty) 'Location': location.first.value,
        if (notes.isNotEmpty) 'Notes': notes.first.value,
      };
      return QuoteReviewDraft(
        id: 'quote-${DateTime.now().microsecondsSinceEpoch}',
        clientId: source?.clientId,
        jobId: source?.jobId,
        companyId: source?.companyId,
        sourceNoteId: source?.sourceNoteId,
        sourceMethod: source?.method.name ?? 'manual',
        clientName: source?.clientName ?? '',
        clientEmail: source?.clientEmail ?? '',
        clientPhone: source?.clientPhone ?? '',
        billingAddress: source?.clientAddress ?? '',
        date: DateTime.now(),
        currency: snapshot.currency ?? 'CHF',
        items: [
          for (var i = 0; i < snapshot.items.length; i++)
            QuoteReviewWorkItem(
              id: 'extracted-${i + 1}',
              title: snapshot.items[i].title,
              description: snapshot.items[i].description,
              quantity: snapshot.items[i].quantity?.toString() ?? '',
              dimensions: snapshot.items[i].dimensions,
              // Never use AI-computed or invented prices.
              unitPrice: '',
              otherFields: i == 0 ? Map<String, String>.from(additional) : null,
              unresolvedOtherFields: i == 0 ? additional.keys.toSet() : null,
            ),
        ],
      );
    }
    String findField(String label) {
      for (final field in snapshot.fields) {
        if (field.label.toLowerCase() == label.toLowerCase() &&
            field.status == QuoteExtractionStatus.verified) {
          return field.value;
        }
      }
      return '';
    }
    final quantity = findField('Quantity');
    final description = findField('Installation');
    final items = findField('Items');
    final uncertain = <String, String>{};
    for (final field in snapshot.fields) {
      if (field.status == QuoteExtractionStatus.verified) {
        continue;
      }
      var name = field.label;
      if (uncertain.containsKey(name)) {
        name = '${field.label} (${field.id})';
      }
      uncertain[name] = field.value;
    }
    return QuoteReviewDraft(
      id: 'quote-${DateTime.now().microsecondsSinceEpoch}',
      clientId: source?.clientId, jobId: source?.jobId,
      companyId: source?.companyId,
      sourceNoteId: source?.sourceNoteId,
      sourceMethod: source?.method.name ?? 'manual',
      clientName: source?.clientName ?? '',
      clientEmail: source?.clientEmail ?? '',
      clientPhone: source?.clientPhone ?? '',
      billingAddress: source?.clientAddress ?? '',
      date: DateTime.now(),
      items: [QuoteReviewWorkItem(
        id: 'extracted-1', title: items, description: description,
        quantity: quantity, dimensions: findField('Dimensions').isEmpty
            ? null : findField('Dimensions'),
        otherFields: uncertain,
        unresolvedOtherFields: uncertain.keys.toSet(),
      )],
    );
  }

  int get validSubtotalMinor => items.fold<int>(
      0, (sum, item) => sum + (item.totalMinor ?? 0));
  bool get allItemPricesValid => items.isNotEmpty && items.every((item) =>
      item.title.trim().isNotEmpty && item.totalMinor != null &&
      (item.dimensions == null || item.dimensions!.trim().isNotEmpty));
  int? get subtotalMinor => allItemPricesValid ? validSubtotalMinor : null;
  int? get vatMinor => subtotalMinor == null ? null :
      percentOfMinor(subtotalMinor!, vatBasisPoints);
  int? get totalMinor => subtotalMinor == null ? null : subtotalMinor! + vatMinor!;
  /// Deposit is informational, not subtracted from grand total.
  int? get depositMinor => totalMinor == null ? null :
      percentOfMinor(totalMinor!, depositBasisPoints);

  List<String> get approvalIssues {
    final issues = <String>[];
    if (clientName.trim().isEmpty) {
      issues.add('Client is required.');
    }
    if (quoteNumber.trim().isEmpty) {
      issues.add('Quote Number is required.');
    }
    if (items.isEmpty) {
      issues.add('Add at least one work item.');
    }
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      if (item.title.trim().isEmpty) {
        issues.add('Item ${i + 1}: title is required.');
      }
      if (item.validQuantity == null) {
        issues.add('Item ${i + 1}: valid quantity required.');
      }
      if (item.priceMinor == null) {
        issues.add('Item ${i + 1}: unit price required.');
      }
      if (item.dimensions != null && item.dimensions!.trim().isEmpty) {
        issues.add('Item ${i + 1}: dimensions are missing.');
      }
      if (item.unresolvedOtherFields.isNotEmpty) {
        issues.add('Item ${i + 1}: review extracted information.');
      }
    }
    return issues;
  }

  QuoteReviewDraft copy() => QuoteReviewDraft(
    id: id, clientId: clientId, jobId: jobId,
    companyId: companyId,
    sourceNoteId: sourceNoteId, clientName: clientName,
    quoteNumber: quoteNumber, date: date, currency: currency,
    vatBasisPoints: vatBasisPoints, depositBasisPoints: depositBasisPoints,
    items: items.map((item) => item.copy()).toList(), terms: terms,
    billingAddress: billingAddress, clientEmail: clientEmail,
    clientPhone: clientPhone, validUntil: validUntil, payment: payment?.copy(),
    isDemo: isDemo, approvedLocally: approvedLocally,
    serverId: serverId, sourceMethod: sourceMethod,
    serverStatus: serverStatus,
  );
}

/// Session-only local draft state. No server or disk persistence is claimed.
abstract final class QuoteReviewSessionStore {
  static final Map<String, QuoteReviewDraft> _drafts = {};
  static bool _listeningForCompanyChanges = false;

  static void _ensureCompanyIsolation() {
    if (_listeningForCompanyChanges) return;
    _listeningForCompanyChanges = true;
    // Logout and company switching must invalidate app-session drafts.
    // A future user who shares this device must never inherit local notes.
    ActiveCompanySession.selected.addListener(clear);
  }

  static void save(QuoteReviewDraft draft) {
    _ensureCompanyIsolation();
    _drafts[draft.id] = draft.copy();
  }
  static QuoteReviewDraft? load(String id) {
    _ensureCompanyIsolation();
    return _drafts[id]?.copy();
  }
  /// Session-local saved quote snapshots. No server or disk persistence.
  static List<QuoteReviewDraft> get savedDrafts {
    _ensureCompanyIsolation();
    return List<QuoteReviewDraft>.unmodifiable(
      _drafts.values.map((draft) => draft.copy()),
    );
  }
  static void clear() => _drafts.clear();
}
