import 'package:file_picker/file_picker.dart';

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
  });

  final String id;
  final String number;
  final String title;
  final String description;
  final DateTime? effectiveDate;
  final String? linkedDocumentId;
  final PlatformFile? logo;
  final bool isCreatedLocally;

  AddendumDraft copyWith({
    String? number, String? title, String? description,
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
  );

  List<String> get validationIssues => [
    if (number.trim().isEmpty) 'Addendum number is required.',
    if (title.trim().isEmpty) 'Title is required.',
    if (description.trim().isEmpty) 'Description is required.',
    if (effectiveDate == null) 'Effective date is required.',
    if (linkedDocumentId == null || linkedDocumentId!.isEmpty)
      'Select a linked document.',
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
