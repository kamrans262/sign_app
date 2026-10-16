import 'package:file_picker/file_picker.dart';
import '../../quotes/domain/quote_review_models.dart' show parseQuoteMinorUnits;

/// Local-only Flutter draft. No server delivery, signature, or audit event.
class AddendumDraft {
  const AddendumDraft({
    required this.id,
    this.number = '',
    this.title = '',
    this.description = '',
    this.effectiveDate,
    this.linkedDocumentId,
    this.logo,
    this.isCreatedLocally = false,
    this.additionalWork = '',
    this.quantity = '',
    this.unitPrice = '',
    this.vatBasisPoints = 0,
    this.linkedDocumentNumber,
    this.linkedJobId,
    this.linkedClientId,
  });

  final String id;
  final String number;
  final String title;
  final String description;
  final DateTime? effectiveDate;
  final String? linkedDocumentId;
  final PlatformFile? logo;
  final bool isCreatedLocally;
  /// Optional for non-financial changes; fully validated if any work is added.
  final String additionalWork;
  final String quantity;
  final String unitPrice;
  final int vatBasisPoints;
  /// Exact reference captured when created, not inferred from a customer name.
  final String? linkedDocumentNumber;
  final String? linkedJobId;
  final String? linkedClientId;

  bool get hasPricedWork => additionalWork.trim().isNotEmpty ||
      quantity.trim().isNotEmpty || unitPrice.trim().isNotEmpty;

  int? get subtotalMinor {
    if (!hasPricedWork) return 0;
    final count = int.tryParse(quantity.trim());
    final unit = parseQuoteMinorUnits(unitPrice);
    if (additionalWork.trim().isEmpty || count == null ||
        count < 1 || count > 100000 || unit == null || unit <= 0) return null;
    return count * unit;
  }

  int? get vatMinor {
    final subtotal = subtotalMinor;
    if (subtotal == null || vatBasisPoints < 0 || vatBasisPoints > 10000) {
      return null;
    }
    return (subtotal * vatBasisPoints + 5000) ~/ 10000;
  }

  int? get totalMinor {
    final subtotal = subtotalMinor;
    final vat = vatMinor;
    return subtotal == null || vat == null ? null : subtotal + vat;
  }

  AddendumDraft copyWith({
    String? number, String? title, String? description,
    String? additionalWork, String? quantity, String? unitPrice,
    int? vatBasisPoints,
    String? linkedDocumentNumber, String? linkedJobId,
    String? linkedClientId,
    DateTime? effectiveDate, String? linkedDocumentId,
    PlatformFile? logo, bool? isCreatedLocally,
    bool removeLinkedDocument = false, bool removeLogo = false,
  }) => AddendumDraft(
    id: id,
    number: number ?? this.number,
    title: title ?? this.title,
    description: description ?? this.description,
    effectiveDate: effectiveDate ?? this.effectiveDate,
    linkedDocumentId: removeLinkedDocument ? null : linkedDocumentId ?? this.linkedDocumentId,
    logo: removeLogo ? null : logo ?? this.logo,
    isCreatedLocally: isCreatedLocally ?? this.isCreatedLocally,
    additionalWork: additionalWork ?? this.additionalWork,
    quantity: quantity ?? this.quantity,
    unitPrice: unitPrice ?? this.unitPrice,
    vatBasisPoints: vatBasisPoints ?? this.vatBasisPoints,
    linkedDocumentNumber: linkedDocumentNumber ?? this.linkedDocumentNumber,
    linkedJobId: linkedJobId ?? this.linkedJobId,
    linkedClientId: linkedClientId ?? this.linkedClientId,
  );

  List<String> get validationIssues => [
    if (number.trim().isEmpty) 'Addendum number is required.',
    if (title.trim().isEmpty) 'Title is required.',
    if (description.trim().isEmpty) 'Description is required.',
    if (effectiveDate == null) 'Effective date is required.',
    if (linkedDocumentId == null || linkedDocumentId!.isEmpty)
      'Select a linked document.',
    if (vatBasisPoints < 0 || vatBasisPoints > 10000)
      'VAT must be between 0% and 100%.',
    if (hasPricedWork && additionalWork.trim().isEmpty)
      'Describe the additional work.',
    if (hasPricedWork && (int.tryParse(quantity.trim()) == null ||
        int.parse(quantity.trim()) < 1 || int.parse(quantity.trim()) > 100000))
      'Quantity must be a whole number between 1 and 100000.',
    if (hasPricedWork && (parseQuoteMinorUnits(unitPrice) == null ||
        parseQuoteMinorUnits(unitPrice)! <= 0))
      'Enter a valid positive unit price.',
  ];
}

class AddendumDraftSession {
  AddendumDraftSession._();

  static final Map<String, AddendumDraft> _drafts = {};
  static final Map<String, AddendumDraft> _created = {};

  static AddendumDraft? load(String id) => _drafts[id] ?? _created[id];
  static Iterable<AddendumDraft> get created => _created.values;
  static Iterable<AddendumDraft> get savedDrafts => _drafts.values;

  static void save(AddendumDraft draft) {
    _drafts[draft.id] = draft;
  }

  static bool isNumberUsed(String number, {String? exceptId}) =>
      _created.values.any((item) => item.id != exceptId &&
          item.number.toLowerCase() == number.trim().toLowerCase());

  static void create(AddendumDraft draft) {
    if (draft.validationIssues.isNotEmpty) {
      throw StateError(draft.validationIssues.first);
    }
    if (isNumberUsed(draft.number, exceptId: draft.id)) {
      throw StateError('This addendum number is already used.');
    }
    _created[draft.id] = draft.copyWith(isCreatedLocally: true);
    _drafts.remove(draft.id);
  }

  static void clear() { _drafts.clear(); _created.clear(); }
}
