import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/features/documents/data/demo_document_repository.dart';
import 'package:sign2digital/features/documents/data/document_activity_session.dart';
import 'package:sign2digital/features/documents/data/phase4_document_records.dart';
import 'package:sign2digital/features/documents/domain/document_browse_options.dart';
import 'package:sign2digital/features/documents/domain/document_record.dart';
import 'package:sign2digital/features/documents/presentation/screens/document_details_screen.dart';
import 'package:sign2digital/features/documents/presentation/screens/documents_screen.dart';
import 'package:sign2digital/features/quotes/data/signed_quote_file_store.dart';
import 'package:sign2digital/features/quotes/domain/quote_document_tracking.dart';
import 'package:sign2digital/features/quotes/domain/quote_review_models.dart';
import 'package:sign2digital/features/quotes/domain/quote_tracking_home_session.dart';

QuoteReviewDraft _quote({bool approved = false}) => QuoteReviewDraft(
  id: 'quote-phase4', clientId: 'client-4', jobId: 'job-4',
  quoteNumber: 'Q-PH4', clientName: 'Alpha Customer',
  clientEmail: 'alpha@example.com',
  date: DateTime(2026, 10, 16),
  terms: 'Payment in 30 days',
  items: [
    QuoteReviewWorkItem(
      id: 'item-1', title: 'Repair', description: 'Roof repairs',
      quantity: '1', unitPrice: '200.00',
    ),
  ],
  approvedLocally: approved,
);

SavedSignedQuoteFile _signedFile() => SavedSignedQuoteFile(
  documentId: 'signed-phase4',
  quoteId: 'quote-phase4',
  quoteNumber: 'Q-PH4',
  jobId: 'job-4',
  signedAt: DateTime(2026, 10, 17),
  fileName: 'signed-phase4.pdf',
);

DocumentRecord _record(String id, String name, DateTime time,
    {String status = 'Draft', DocumentCategory category = DocumentCategory.quotes,
     QuoteReviewDraft? quote}) => DocumentRecord(
  id: id,
  category: category,
  number: 'Q-$id',
  title: name,
  project: 'job-4',
  customer: 'Alpha Customer',
  timestamp: time,
  status: status,
  quote: quote,
);

class _DocumentSource implements DocumentRepository {
  _DocumentSource(this.data);
  final List<DocumentRecord> data;
  @override
  Future<List<DocumentRecord>> listDocuments() async => data;
}

void main() {
  setUp(() {
    DocumentActivitySession.clear();
    QuoteReviewSessionStore.clear();
    QuoteTrackingHomeSession.clear();
  });
  tearDown(() {
    DocumentActivitySession.clear();
    QuoteReviewSessionStore.clear();
    QuoteTrackingHomeSession.clear();
  });

  test('real saved quotes appear alongside existing Figma records', () async {
    final quote = _quote(approved: true);
    QuoteReviewSessionStore.save(quote);
    DocumentActivitySession.approved(quote);

    final documents = await const DemoDocumentRepository().listDocuments();
    final created = documents.where((record) =>
        record.id == 'quote-phase4').toList();
    expect(created, hasLength(1));
    expect(created.single.demoOnly, isFalse);
    expect(created.single.status, 'Approved');
    expect(created.single.quote?.jobId, 'job-4');
    expect(created.single.customer, 'Alpha Customer');
    expect(created.single.version, 1);
    expect(created.single.history.any((event) =>
        event.type == DocumentHistoryType.created), isTrue);
    expect(documents.where((record) => record.demoOnly), hasLength(5));
  });

  test('only true edits change revision and signed PDFs relate to original',
      () {
    final quote = _quote(approved: true);
    DocumentActivitySession.approved(quote);
    DocumentActivitySession.approved(quote);
    expect(DocumentActivitySession.versionFor(quote.id), 1);
    quote.terms = 'Updated payment terms';
    DocumentActivitySession.approved(quote);
    expect(DocumentActivitySession.versionFor(quote.id), 2);
    DocumentActivitySession.downloaded(quote.id);
    QuoteTrackingHomeSession.rememberVerifiedTracking(QuoteDocumentTracking(
      quoteId: quote.id, requestId: 'verified-request',
      events: [
        QuoteDocumentEvent(
          id: 'delivery', type: QuoteDocumentEventType.documentSent,
          occurredAt: DateTime(2026, 10, 16),
        ),
        QuoteDocumentEvent(
          id: 'signature', type: QuoteDocumentEventType.documentSigned,
          occurredAt: DateTime(2026, 10, 17),
        ),
      ],
    ));
    final records = phase4DocumentRecords(
      savedQuotes: [quote], signedFiles: [_signedFile()],
    );
    expect(records, hasLength(2));
    final signed = records.firstWhere((r) => r.id == 'signed-phase4');
    final original = records.firstWhere((r) => r.id == 'quote-phase4');
    expect(signed.verifiedSignedPdfAvailable, isTrue);
    expect(signed.status, 'Signed');
    expect(signed.version, 2);
    expect(signed.related.single.id, original.id);
    expect(original.related.single.id, signed.id);
    expect(signed.history.where((event) =>
        event.type == DocumentHistoryType.signed), hasLength(1));
    expect(original.history.any((event) =>
        event.type == DocumentHistoryType.versionChanged), isTrue);
    expect(original.history.any((event) =>
        event.type == DocumentHistoryType.downloaded), isTrue);
    expect(original.history.any((event) =>
        event.type == DocumentHistoryType.sent), isTrue);
  });

  test('filters and sorting preserve originals and never turn demos into proof',
      () {
    final docs = [
      _record('a', 'Zulu', DateTime(2026, 10, 10)),
      _record('b', 'Alpha', DateTime(2026, 10, 12), status: 'Signed'),
      _record('c', 'Invoice', DateTime(2026, 10, 11),
        category: DocumentCategory.invoices),
    ];
    expect(browseDocuments(docs,
      type: DocumentBrowseType.signedQuotes).map((r) => r.id), ['b']);
    expect(browseDocuments(docs,
      type: DocumentBrowseType.invoices).map((r) => r.id), ['c']);
    expect(browseDocuments(docs,
      query: 'Alpha Customer').length, 3);
    expect(browseDocuments(docs,
      order: DocumentSortOrder.newestFirst).map((r) => r.id),
      ['b', 'c', 'a']);
    expect(browseDocuments(docs,
      order: DocumentSortOrder.titleAscending).map((r) => r.id),
      ['b', 'c', 'a']);
    expect(browseDocuments(docs).map((r) => r.id), ['a', 'b', 'c']);
  });

  testWidgets('Documents filter uses the existing search action, not new tabs',
      (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: DocumentsScreen(repository: _DocumentSource([
        _record('a', 'Draft Quote', DateTime(2026, 10, 10)),
        _record('b', 'Signed Quote', DateTime(2026, 10, 12),
          status: 'Signed'),
      ])),
    )));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('document-card-a')), findsOneWidget);
    expect(find.byKey(const Key('document-card-b')), findsOneWidget);
    await tester.tap(find.byTooltip('Search action'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('documents-filter-sheet')), findsOneWidget);
    await tester.tap(find.byKey(const Key('documents-filter-signedQuotes')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('document-card-a')), findsNothing);
    expect(find.byKey(const Key('document-card-b')), findsOneWidget);
    expect(find.text('Quotes'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('eligible unsiged quote can Send, but signed quote cannot',
      (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final draft = _quote(approved: true);
    await tester.pumpWidget(MaterialApp(home: DocumentDetailsScreen(
      documentId: 'quote-phase4',
      document: _record('quote-phase4', 'Quote', DateTime(2026, 10, 16),
        status: 'Approved', quote: draft),
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('document-action-3')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('document-send-quote')), findsOneWidget);
    // Dispose the previous route and bottom sheet before inspecting a
    // different document, so no state from the first detail page is reused.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pumpWidget(MaterialApp(home: DocumentDetailsScreen(
      documentId: 'quote-phase4',
      document: _record('quote-phase4', 'Quote', DateTime(2026, 10, 16),
        status: 'Signed', quote: draft),
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('document-action-3')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('document-send-quote')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
