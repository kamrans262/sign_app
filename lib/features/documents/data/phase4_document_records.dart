import '../../quotes/data/signed_quote_file_store.dart';
import '../../quotes/domain/quote_document_tracking.dart';
import '../../quotes/domain/quote_review_models.dart';
import '../../quotes/domain/quote_tracking_home_session.dart';
import 'document_activity_session.dart';
import '../domain/document_record.dart';

/// Joins existing app-session quote records, authenticated signing activity,
/// and signed PDFs returned by the service. No fabricated audit entries.
List<DocumentRecord> phase4DocumentRecords({
  required List<QuoteReviewDraft> savedQuotes,
  required List<SavedSignedQuoteFile> signedFiles,
}) {
  final liveQuotes = savedQuotes.where((q) => !q.isDemo).toList();
  final quoteById = {for (final quote in liveQuotes) quote.id: quote};
  final signedByQuote = <String, SavedSignedQuoteFile>{
    for (final file in signedFiles) file.quoteId: file,
  };

  final builder = _Phase4RecordBuilder(quoteById, signedByQuote);

  return [
    for (final file in signedFiles) builder.signedRecord(file, linkOriginal: true),
    for (final quote in liveQuotes) builder.quoteRecord(quote, linkSigned: true),
  ];
}

/// Named methods are visible throughout this class, allowing the original
/// quote and signed-PDF builders to reference each other in either order.
/// The link flags stop recursion after one related-document level.
class _Phase4RecordBuilder {
  _Phase4RecordBuilder(this.quoteById, this.signedByQuote);

  final Map<String, QuoteReviewDraft> quoteById;
  final Map<String, SavedSignedQuoteFile> signedByQuote;

  List<DocumentHistoryEvent> history(String quoteId, String recordId,
      {bool includeSigned = true}) {
    final result = <DocumentHistoryEvent>[
      for (final event in DocumentActivitySession.forDocument(quoteId))
        DocumentHistoryEvent(
          id: '${recordId}-local-${event.id}',
          documentId: recordId,
          type: event.type,
          occurredAt: event.occurredAt,
          actorName: event.actorName,
          actorEmail: event.actorEmail,
          description: event.description,
          signatureReference: event.signatureReference,
        ),
      if (recordId != quoteId)
        ...DocumentActivitySession.forDocument(recordId),
    ];
    final tracking = QuoteTrackingHomeSession.trackingFor(quoteId);
    if (tracking != null) {
      for (final event in tracking.events) {
        final type = switch (event.type) {
          QuoteDocumentEventType.quoteCreated => DocumentHistoryType.created,
          QuoteDocumentEventType.documentSent => DocumentHistoryType.sent,
          QuoteDocumentEventType.documentViewed => DocumentHistoryType.viewed,
          QuoteDocumentEventType.documentSigned => DocumentHistoryType.signed,
          _ => null,
        };
        if (type == null || (!includeSigned && type == DocumentHistoryType.signed)) {
          continue;
        }
        result.add(DocumentHistoryEvent(
          id: '${recordId}-server-${event.id}',
          documentId: recordId,
          type: type,
          occurredAt: event.occurredAt,
          description: 'Reported by the connected document service',
          signatureReference: type == DocumentHistoryType.signed
              ? tracking.requestId : null,
        ));
      }
    }
    return result;
  }

  DocumentRecord quoteRecord(QuoteReviewDraft quote,
      {bool linkSigned = false}) {
    final signed = signedByQuote[quote.id];
    final tracking = QuoteTrackingHomeSession.trackingFor(quote.id);
    final events = history(quote.id, quote.id);
    final firstCreated = [
      for (final event in events)
        if (event.type == DocumentHistoryType.created) event.occurredAt,
    ];
    return DocumentRecord(
      id: quote.id, category: DocumentCategory.quotes,
      number: quote.quoteNumber.trim().isEmpty
          ? 'Unnumbered draft' : quote.quoteNumber,
      title: quote.quoteNumber.trim().isEmpty
          ? 'Quote Draft' : 'Quote ${quote.quoteNumber}',
      project: quote.jobId ?? 'Not linked to a job',
      customer: quote.clientName,
      timestamp: firstCreated.isEmpty ? quote.date : firstCreated.last,
      status: signed != null || tracking?.signed == true
          ? 'Signed'
          : tracking?.viewed == true
              ? 'Viewed'
              : tracking?.sent == true ||
                  events.any((e) => e.type == DocumentHistoryType.sent)
                  ? 'Sent'
                  : quote.approvedLocally ? 'Approved' : 'Draft',
      quote: quote.copy(),
      verifiedSignedPdfAvailable: signed != null,
      createdAt: firstCreated.isEmpty ? null : firstCreated.last,
      updatedAt: events.isEmpty
          ? null
          : events.map((e) => e.occurredAt).reduce(
              (a, b) => a.isAfter(b) ? a : b),
      validUntil: quote.validUntil,
      version: DocumentActivitySession.versionFor(quote.id),
      history: events,
      related: linkSigned && signed != null
          ? [signedRecord(signed, linkOriginal: false)] : const [],
    );
  }

  DocumentRecord signedRecord(SavedSignedQuoteFile file,
      {bool linkOriginal = false}) {
    final quote = quoteById[file.quoteId];
    final events = history(file.quoteId, file.documentId,
        includeSigned: false);
    events.add(DocumentHistoryEvent(
      id: 'verified-signed-${file.documentId}',
      documentId: file.documentId,
      type: DocumentHistoryType.signed,
      occurredAt: file.signedAt,
      signatureReference: file.documentId,
    ));
    return DocumentRecord(
      id: file.documentId, category: DocumentCategory.quotes,
      number: file.quoteNumber,
      title: 'Signed Quote ${file.quoteNumber}',
      project: file.jobId,
      customer: quote?.clientName ?? '',
      timestamp: file.signedAt,
      status: 'Signed', quote: quote?.copy(),
      verifiedSignedPdfAvailable: true,
      attachmentNames: [file.fileName],
      version: DocumentActivitySession.versionFor(file.quoteId),
      updatedAt: file.signedAt,
      createdAt: quote?.date,
      validUntil: quote?.validUntil,
      history: events,
      related: linkOriginal && quote != null
          ? [quoteRecord(quote, linkSigned: false)] : const [],
    );
  }

}
