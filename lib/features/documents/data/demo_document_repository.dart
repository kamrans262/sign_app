import '../../quotes/data/quote_ui_demo_data.dart';
import '../../quotes/domain/quote_review_models.dart';
import 'phase4_document_records.dart';
import '../../quotes/data/signed_quote_file_store.dart';
import '../domain/document_record.dart';
import '../domain/addendum_draft.dart';
import '../domain/addendum_signature_request.dart';

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
    final originals = <DocumentRecord>[
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
    ];
    DocumentRecord? sourceFor(String? id) {
      for (final original in originals) {
        if (original.id == id) return original;
      }
      return null;
    }
    final addenda = <DocumentRecord>[
      ...AddendumDraftSession.savedDrafts.map((draft) => DocumentRecord(
        id: draft.id,
        category: DocumentCategory.addends,
        number: draft.number.isEmpty ? 'Unnumbered draft' : draft.number,
        title: draft.title.isEmpty ? 'Addendum draft' : 'Addendum ${draft.number}',
        project: sourceFor(draft.linkedDocumentId)?.project ??
            (draft.title.isEmpty ? 'Incomplete addendum' : draft.title),
        customer: sourceFor(draft.linkedDocumentId)?.customer ?? '',
        related: [if (sourceFor(draft.linkedDocumentId) != null)
          sourceFor(draft.linkedDocumentId)!],
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
        project: sourceFor(draft.linkedDocumentId)?.project ??
            draft.linkedJobId ?? draft.title,
        customer: sourceFor(draft.linkedDocumentId)?.customer ?? '',
        timestamp: DateTime.now(),
        status: AddendumSignatureRequestSession.forAddendum(draft.id)
            ?.status ?? 'Draft',
        demoOnly: sourceFor(draft.linkedDocumentId)?.demoOnly ?? false,
        addendumDraftId: draft.id,
        validUntil: draft.effectiveDate,
        related: [if (sourceFor(draft.linkedDocumentId) != null)
          sourceFor(draft.linkedDocumentId)!],
        history: [DocumentHistoryEvent(
          id: 'local-create-${draft.id}',
          documentId: draft.id,
          type: DocumentHistoryType.created,
          occurredAt: DateTime.now(),
          description: 'Addendum created in this app session; not sent or signed',
        ),
          if (AddendumSignatureRequestSession.forAddendum(draft.id)
              ?.confirmedSentAt != null)
            DocumentHistoryEvent(
              id: 'verified-request-sent-${draft.id}',
              documentId: draft.id,
              type: DocumentHistoryType.sent,
              occurredAt: AddendumSignatureRequestSession.forAddendum(draft.id)!
                  .confirmedSentAt!,
              description: 'Addendum signature request delivery '
                  'confirmed by connected service',
            ),
        ],
      )),
    ];
    // Preserve original signed documents byte-for-byte and expose addenda
    // through their existing Related tab. The addendum itself references an
    // unmodified original; no recursive object graph is created.
    return [
      for (final original in originals)
        if (addenda.any((addendum) => addendum.related.any(
            (parent) => parent.id == original.id)))
          original.withRelated([
            ...original.related,
            ...addenda.where((addendum) => addendum.related.any(
                (parent) => parent.id == original.id)),
          ])
        else
          original,
      ...addenda,
    ];
  }
}
