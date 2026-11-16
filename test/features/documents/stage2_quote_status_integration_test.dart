import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/features/documents/domain/document_record.dart';
import 'package:sign2digital/features/documents/presentation/screens/document_details_screen.dart';
import 'package:sign2digital/features/documents/presentation/screens/documents_screen.dart';
import 'package:sign2digital/features/quotes/domain/quote_review_models.dart';

QuoteReviewDraft _quote() => QuoteReviewDraft(
  id: 'local-approved-42',
  clientName: 'Approved Customer',
  clientEmail: 'customer@example.test',
  quoteNumber: 'Q-42',
  date: DateTime.utc(2026, 11, 12),
  terms: 'Approved customer terms',
  approvedLocally: true,
  items: [
    QuoteReviewWorkItem(
      id: 'item-42', title: 'Approved repair', quantity: '1',
      unitPrice: '120.00', description: 'Repair',
    ),
  ],
);

DocumentRecord _original({List<DocumentRecord> related = const [],
    String status = 'approved', QuoteReviewDraft? quote}) => DocumentRecord(
  id: 'quote-42', category: DocumentCategory.quotes,
  title: 'Quote Q-42', number: 'Q-42',
  project: 'Job 9', jobId: '9', customer: 'Approved Customer',
  timestamp: DateTime.utc(2026, 11, 12), status: status,
  quote: quote ?? _quote(), verifiedSignedPdfAvailable: true,
  related: related,
);

DocumentRecord _signed() => DocumentRecord(
  id: 'signed-8', category: DocumentCategory.quotes,
  title: 'Signed Quote Q-42', number: 'Q-42',
  project: 'Job 9', jobId: '9', customer: 'Approved Customer',
  timestamp: DateTime.utc(2026, 11, 12), status: 'signed',
  verifiedSignedPdfAvailable: true,
);

class _Catalog implements DocumentRepository {
  const _Catalog(this.items);
  final List<DocumentRecord> items;
  @override
  Future<List<DocumentRecord>> listDocuments() async => items;
}

void main() {
  testWidgets('approved unsigned quote has existing document status action in More',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: DocumentDetailsScreen(
        documentId: 'quote-42', document: _original(),
      ),
    ));
    expect(find.byKey(const Key('document-quote-download')), findsOneWidget);
    expect(find.byKey(const Key('document-quote-send')), findsOneWidget);
    expect(find.byKey(const Key('document-request-signature')), findsNothing);
    // Two equal-width actions remain below the existing View/More cards.
    final footer = find.byKey(const Key('document-quote-status-actions'));
    final actionCards = find.byKey(const Key('document-detail-actions'));
    expect(tester.getTopLeft(footer).dy,
        greaterThan(tester.getBottomLeft(actionCards).dy));
    final download = find.byKey(const Key('document-quote-download'));
    final send = find.byKey(const Key('document-quote-send'));
    expect((tester.getSize(download).width -
        tester.getSize(send).width).abs(), lessThanOrEqualTo(1));
    expect(
      tester.getBottomLeft(find.byType(Scaffold)).dy -
          tester.getBottomLeft(footer).dy,
      lessThanOrEqualTo(36),
      reason: 'Two equal actions must stay at the bottom of the screen.',
    );
    await tester.tap(find.byKey(const Key('document-action-3')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('document-view-document-status')), findsOneWidget);
    expect(find.byKey(const Key('document-send-quote')), findsOneWidget);
    expect(find.byKey(const Key('document-more-request-signature')),
        findsOneWidget);
    expect(find.byKey(const Key('document-view-signed-quote')), findsNothing);
    await tester.tap(find.byKey(const Key('document-view-document-status')));
    await tester.pumpAndSettle();
    expect(find.text('Signature Request'), findsOneWidget);
    expect(find.byKey(const Key('signature-timeline')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('linked signed artifact replaces quote signing actions, preserves original',
      (tester) async {
    final original = _original(related: [_signed()]);
    await tester.pumpWidget(MaterialApp(
      home: DocumentDetailsScreen(documentId: original.id, document: original),
    ));
    expect(find.byKey(const Key('document-request-signature')), findsNothing);
    expect(find.byKey(const Key('document-quote-view-signed')), findsOneWidget);
    expect(find.byKey(const Key('document-quote-download-signed')), findsOneWidget);
    expect(find.byKey(const Key('document-quote-send')), findsNothing);
    expect(find.text('Signed'), findsWidgets);
    await tester.tap(find.byKey(const Key('document-action-3')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('document-view-document-status')), findsNothing);
    expect(find.byKey(const Key('document-send-quote')), findsNothing);
    expect(find.byKey(const Key('document-more-request-signature')),
        findsNothing);
    expect(find.byKey(const Key('document-view-signed-quote')), findsOneWidget);
    await tester.tap(find.byKey(const Key('document-view-signed-quote')));
    await tester.pumpAndSettle();
    expect(find.text('Signed Quote Q-42'), findsWidgets);
    expect(find.text('Documents'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unverified related records never mark original quote signed',
      (tester) async {
    final unverified = DocumentRecord(
      id: 'signed-9', category: DocumentCategory.quotes,
      number: 'Q-42', title: 'Unverified document',
      project: 'Job 9', jobId: '9', customer: 'Approved Customer',
      timestamp: DateTime.utc(2026, 11, 12),
      status: 'signed', verifiedSignedPdfAvailable: false,
    );
    await tester.pumpWidget(MaterialApp(
      home: DocumentDetailsScreen(documentId: 'quote-42',
        document: _original(related: [unverified])),
    ));
    expect(find.byKey(const Key('document-request-signature')), findsNothing);
    expect(find.byKey(const Key('document-quote-download')), findsOneWidget);
    expect(find.byKey(const Key('document-quote-send')), findsOneWidget);
    await tester.tap(find.byKey(const Key('document-action-3')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('document-view-signed-quote')), findsNothing);
    expect(find.byKey(const Key('document-view-document-status')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('draft quote shows Edit and Approve as equal-width actions',
      (tester) async {
    final draft = _original(status:'draft',quote:(_quote()
      ..approvedLocally=false));
    await tester.pumpWidget(MaterialApp(
      home: DocumentDetailsScreen(documentId:draft.id,document:draft),
    ));
    final edit=find.byKey(const Key('document-quote-edit'));
    final approve=find.byKey(const Key('document-quote-approve'));
    expect(edit,findsOneWidget);
    expect(approve,findsOneWidget);
    expect(find.byKey(const Key('document-quote-send')),findsNothing);
    expect(find.byKey(const Key('document-quote-download')),findsNothing);
    expect((tester.getSize(edit).width -
        tester.getSize(approve).width).abs(),lessThanOrEqualTo(1));
    expect(tester.takeException(),isNull);
  });

  testWidgets('sent quote shows Download and View Status, without approval',
      (tester) async {
    final sent = _original(status:'sent');
    await tester.pumpWidget(MaterialApp(
      home: DocumentDetailsScreen(documentId:sent.id,document:sent),
    ));
    expect(find.byKey(const Key('document-quote-download')),findsOneWidget);
    expect(find.byKey(const Key('document-quote-status')),findsOneWidget);
    expect(find.byKey(const Key('document-quote-approve')),findsNothing);
    expect(find.byKey(const Key('document-quote-send')),findsNothing);
    expect(tester.takeException(),isNull);
  });

  testWidgets('quote footer stays evenly split on a narrow phone',
      (tester) async {
    tester.view.physicalSize=const Size(320,650);
    tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home:DocumentDetailsScreen(
      documentId:'quote-42',document:_original(status:'approved'),
    )));
    final left=find.byKey(const Key('document-quote-download'));
    final right=find.byKey(const Key('document-quote-send'));
    expect(left,findsOneWidget);
    expect(right,findsOneWidget);
    expect((tester.getSize(left).width-tester.getSize(right).width).abs(),
        lessThanOrEqualTo(1));
    expect(tester.takeException(),isNull);
  });

  testWidgets('Documents catalogue shows Signed only for verified related artifact',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DocumentsScreen(repository: _Catalog([_original(), _signed()])),
      ),
    ));
    await tester.pumpAndSettle();
    final quoteCard = find.byKey(const Key('document-card-quote-42'));
    expect(quoteCard, findsOneWidget);
    expect(find.descendant(of: quoteCard, matching: find.text('Signed')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
