import '../../quotes/data/quote_ui_demo_data.dart';
import '../../quotes/domain/quote_review_models.dart';
import '../domain/document_record.dart';

/// Five independent fictional records for the Documents layout preview.
/// "Signed" is a visual fixture only: no verified PDF or audit record exists.
class DemoDocumentRepository implements DocumentRepository {
  const DemoDocumentRepository();

  @override
  Future<List<DocumentRecord>> listDocuments() async =>
      List<DocumentRecord>.generate(5, (index) {
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
        );
      });
}
