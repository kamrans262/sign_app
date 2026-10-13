import '../../quotes/domain/quote_review_models.dart';

/// Local UI record; status is not evidence that a remote signing service ran.
enum DocumentCategory { quotes, contacts, reports, addends }

/// A documented event linked to a particular document. Production callers
/// must supply only verified source events; UI-only fixtures stay in demo mode.
enum DocumentHistoryType { created, sent, emailOpened, viewed, signed }

class DocumentHistoryEvent {
  const DocumentHistoryEvent({
    required this.id,
    required this.documentId,
    required this.type,
    required this.occurredAt,
    this.actorName,
    this.actorEmail,
    this.description,
    this.signatureReference,
  });

  final String id;
  final String documentId;
  final DocumentHistoryType type;
  final DateTime occurredAt;
  final String? actorName;
  final String? actorEmail;
  final String? description;
  final String? signatureReference;

  String get title => switch (type) {
    DocumentHistoryType.created => 'Document Created',
    DocumentHistoryType.sent => 'Document Sent',
    DocumentHistoryType.emailOpened => 'E-mail Opened',
    DocumentHistoryType.viewed => 'Viewed by Customers',
    DocumentHistoryType.signed => 'Document Signed',
  };
}

class DocumentPermissionDeniedException implements Exception {
  const DocumentPermissionDeniedException();
}

class DocumentRecord {
  const DocumentRecord({
    required this.id,
    required this.category,
    required this.number,
    required this.title,
    required this.project,
    required this.customer,
    required this.timestamp,
    required this.status,
    this.quote,
    this.demoOnly = false,
    this.verifiedSignedPdfAvailable = false,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
    this.validUntil,
    this.history = const [],
    this.related = const [],
    this.addendumDraftId,
  });

  final String id;
  final DocumentCategory category;
  final String number;
  final String title;
  final String project;
  final String customer;
  final DateTime timestamp;
  final String status;
  final QuoteReviewDraft? quote;
  final bool demoOnly;
  final bool verifiedSignedPdfAvailable;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? validUntil;
  final List<DocumentHistoryEvent> history;
  final List<DocumentRecord> related;
  /// Session-local editable addendum entry, not a server document.
  final String? addendumDraftId;

  bool matches(String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return true;
    return [
      id, number, title, project, customer,
      category.name, status, quote?.jobId ?? '',
    ].any((field) => field.toLowerCase().contains(needle));
  }
}

abstract class DocumentRepository {
  Future<List<DocumentRecord>> listDocuments();
}
