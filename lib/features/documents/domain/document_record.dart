import '../../quotes/domain/quote_review_models.dart';

/// Local UI record; status is not evidence that a remote signing service ran.
enum DocumentCategory { quotes, contacts, reports, addends }

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
