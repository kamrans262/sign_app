import '../../quotes/data/quote_ui_demo_data.dart';
import '../../quotes/domain/quote_review_models.dart';
import 'phase4_document_records.dart';
import '../../quotes/data/signed_quote_file_store.dart';
import '../domain/document_record.dart';
import '../domain/addendum_draft.dart';

/// Five independent fictional records for the Documents layout preview.
/// "Signed" is a visual fixture only: no verified PDF or audit record exists.
class DemoDocumentRepository implements DocumentRepository {
  const DemoDocumentRepository();

  @override
  Future<List<DocumentRecord>> listDocuments() async {
    List<SavedSignedQuoteFile> signed = const [];
    try {
      signed = await SignedQuoteFileStore.shared.list();
    } catch (_) {
      // The existing demo records remain usable without local filesystem access.
    }
    return [
      ...phase4DocumentRecords(
        savedQuotes: QuoteReviewSessionStore.savedDrafts,
        signedFiles: signed,
      ),
      ...List<DocumentRecord>.generate(5, (index) {
        final source = QuoteUiDemoData.quote();
        final id = 'documents-figma-quote-${index + 1}';
        final quote = QuoteReviewDraft(
          id: id,
          clientId: source.clientId,
          clientName: 'Jean dupont',
          quoteNumber: 'Q-12800',
          date: DateTime(2026, 8, 23),
          validUntil: source.validUntil,
          currency: source.currency,
          vatBasisPoints: source.vatBasisPoints,
          depositBasisPoints: source.depositBasisPoints,
          billingAddress: source.billingAddress,
          clientEmail: source.clientEmail,
          clientPhone: source.clientPhone,
          terms: source.terms,
          items: source.items.map((item) => item.copy()).toList(),
          isDemo: true,
          approvedLocally: true,
        );
        return DocumentRecord(
          id: id,
          category: DocumentCategory.quotes,
          number: quote.quoteNumber,
          title: 'Quote ${quote.quoteNumber}',
          project: 'Kitchen renovation',
          customer: quote.clientName,
          timestamp: DateTime(2026, 8, 23, 22),
          status: 'Signed',
          quote: quote,
          demoOnly: true,
          createdBy: 'Jean Dupont',
          createdAt: DateTime(2026, 8, 12, 9),
          updatedAt: DateTime(2026, 8, 12, 11, 15),
          validUntil: quote.validUntil,
          // Figma-only sample activity: NEVER trusted delivery/audit evidence.
          history: [
            DocumentHistoryEvent(
              id: '$id-signed', documentId: id,
              type: DocumentHistoryType.signed,
              occurredAt: DateTime(2026, 8, 12, 11, 15),
              actorName: 'Jean Dupont', actorEmail: 'jean.dupont@example.com',
              description: 'Sample signing activity (UI demo only)',
            ),
            DocumentHistoryEvent(
              id: '$id-viewed', documentId: id,
              type: DocumentHistoryType.viewed,
              occurredAt: DateTime(2026, 8, 12, 11),
              actorName: 'Jean Dupont', actorEmail: 'jean.dupont@example.com',
              description: 'Sample recipient view (UI demo only)',
            ),
            DocumentHistoryEvent(
              id: '$id-email', documentId: id,
              type: DocumentHistoryType.emailOpened,
              occurredAt: DateTime(2026, 8, 12, 10, 45),
              actorEmail: 'jean.dupont@example.com',
              description: 'Sample email open (UI demo only)',
            ),
            DocumentHistoryEvent(
              id: '$id-sent', documentId: id,
              type: DocumentHistoryType.sent,
              occurredAt: DateTime(2026, 8, 12, 10, 15),
              actorEmail: 'jean.dupont@example.com',
              description: 'Sample delivery (UI demo only)',
            ),
            DocumentHistoryEvent(
              id: '$id-created', documentId: id,
              type: DocumentHistoryType.created,
              occurredAt: DateTime(2026, 8, 12, 9),
              actorName: 'Jean Dupont',
              description: 'Fictional quote created for the UI preview',
            ),
          ],
        );
      }),
      ...AddendumDraftSession.savedDrafts.map((draft) => DocumentRecord(
        id: draft.id,
        category: DocumentCategory.addends,
        number: draft.number.isEmpty ? 'Unnumbered draft' : draft.number,
        title: draft.title.isEmpty ? 'Addendum draft' : 'Addendum ${draft.number}',
        project: draft.title.isEmpty ? 'Incomplete addendum' : draft.title,
        customer: '',
        timestamp: DateTime.now(),
        status: 'Draft',
        demoOnly: true,
        addendumDraftId: draft.id,
      )),
      ...AddendumDraftSession.created.map((draft) => DocumentRecord(
        id: draft.id,
        category: DocumentCategory.addends,
        number: draft.number,
        title: 'Addendum ${draft.number}',
        project: draft.title,
        customer: '',
        timestamp: DateTime.now(),
        status: 'Draft',
        demoOnly: true,
        validUntil: draft.effectiveDate,
      )),
    ];
  }
}
