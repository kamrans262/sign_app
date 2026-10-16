import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/features/documents/data/demo_document_repository.dart';
import 'package:sign2digital/features/documents/domain/document_record.dart';
import 'package:sign2digital/features/documents/presentation/screens/document_details_screen.dart';
import 'package:sign2digital/features/documents/presentation/widgets/sign2digital_document_history.dart';
import 'package:sign2digital/features/quotes/presentation/widgets/sign2digital_signature_action_card.dart';
import 'package:sign2digital/features/quotes/presentation/widgets/sign2digital_quote_summary_card.dart';
import 'package:sign2digital/features/clients/presentation/widgets/sign2digital_details_tabs.dart';

void main() {
  late DocumentRecord record;

  setUp(() async {
    record = (await const DemoDocumentRepository().listDocuments()).first;
  });

  Widget page({DocumentRecord? document, int initialTab = 0}) =>
      MaterialApp(home: DocumentDetailsScreen(
        documentId: (document ?? record).id,
        document: document ?? record,
        initialTab: initialTab,
      ));

  testWidgets('Details matches reference: shared header, status, actions and aligned fields',
      (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(page());
    expect(find.text('Documents'), findsOneWidget);
    expect(find.byType(Sign2DigitalQuoteSummaryCard), findsOneWidget);
    expect(find.text('Quote Q-12800'), findsOneWidget);
    expect(find.text('Kitchen renovation'), findsOneWidget);
    expect(find.text('Signed'), findsWidgets);
    expect(find.byType(Sign2DigitalSignatureActionCard), findsNWidgets(4));
    expect(find.text('View'), findsOneWidget);
    expect(find.text('Download'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
    expect(find.text('More'), findsOneWidget);
    expect(find.text('Document Information'), findsOneWidget);
    expect(find.text('Q-12800'), findsOneWidget);
    expect(find.text('Job'), findsOneWidget);
    expect(find.text('Valid Until:'), findsOneWidget);
    expect(tester.widget<Sign2DigitalSignatureActionCard>(
      find.byKey(const Key('document-action-0')),
    ).selected, isTrue);
    expect(find.byKey(const Key('document-details-scroll')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('History hides actions, orders events and exposes contextual button',
      (tester) async {
    await tester.pumpWidget(page(initialTab: 3));
    expect(find.byType(Sign2DigitalSignatureActionCard), findsNothing);
    expect(find.byType(Sign2DigitalDocumentHistory), findsOneWidget);
    expect(find.text('Document Signed'), findsOneWidget);
    expect(find.text('Viewed by Customers'), findsOneWidget);
    expect(find.text('E-mail Opened'), findsOneWidget);
    expect(find.text('Document Sent'), findsOneWidget);
    expect(find.text('Document Created'), findsOneWidget);
    expect(find.text('View Signatures'), findsOneWidget);
    expect(find.byKey(const Key('document-history-demo-notice')), findsNothing);
    expect(find.text('Audit Information'), findsNothing);
    final timeline = tester.widget<Sign2DigitalDocumentHistory>(
      find.byType(Sign2DigitalDocumentHistory),
    );
    expect(timeline.document.id, record.id);
    final viewedKey = Key('document-history-event-${record.id}-viewed');
    await tester.ensureVisible(find.byKey(viewedKey));
    await tester.pump();
    await tester.tap(find.byKey(viewedKey));
    await tester.pump();
    expect(find.text('View Signatures'), findsNothing);
    expect(find.text('View Document'), findsOneWidget);
    await tester.ensureVisible(find.byKey(
      Key('document-history-event-${record.id}-signed')));
    await tester.pump();
    await tester.tap(find.byKey(
      Key('document-history-event-${record.id}-signed')));
    await tester.pump();
    expect(find.text('View Signatures'), findsOneWidget);
    final signatureButton = find.byKey(const Key('document-view-signatures'));
    final buttonSize = tester.getSize(signatureButton);
    expect(buttonSize.width, greaterThanOrEqualTo(200));
    expect(buttonSize.height, 48);
    await tester.ensureVisible(find.text('View Signatures'));
    await tester.tap(find.text('View Signatures'));
    await tester.pump();
    expect(find.textContaining('no verified signature'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('History Sent and Created open their relevant document tabs',
      (tester) async {
    await tester.pumpWidget(page(initialTab: 3));
    final sent = find.byKey(
      Key('document-history-event-${record.id}-sent'));
    await tester.ensureVisible(sent);
    await tester.tap(sent);
    await tester.pump();
    final viewDocument = find.byKey(
      Key('document-history-action-${record.id}-sent'));
    expect(find.text('View Document'), findsOneWidget);
    await tester.ensureVisible(viewDocument);
    await tester.tap(viewDocument);
    await tester.pump();
    final tabs = tester.widget<Sign2DigitalDetailsTabs>(
      find.byType(Sign2DigitalDetailsTabs));
    expect(tabs.selectedIndex, 1);

    await tester.tap(find.byKey(const Key('details-tab-3')));
    await tester.pump();
    final created = find.byKey(
      Key('document-history-event-${record.id}-created'));
    await tester.ensureVisible(created);
    await tester.tap(created);
    await tester.pump();
    expect(find.text('View Details'), findsOneWidget);
    final viewDetails = find.byKey(
      Key('document-history-action-${record.id}-created'));
    await tester.ensureVisible(viewDetails);
    await tester.tap(viewDetails);
    await tester.pump();
    expect(tester.widget<Sign2DigitalDetailsTabs>(
      find.byType(Sign2DigitalDetailsTabs)).selectedIndex, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tabs preserve document and restore actions when leaving History',
      (tester) async {
    await tester.pumpWidget(page(initialTab: 3));
    await tester.tap(find.byKey(const Key('details-tab-0')));
    await tester.pump();
    expect(find.text('Document Information'), findsOneWidget);
    expect(find.byType(Sign2DigitalSignatureActionCard), findsNWidgets(4));
    await tester.tap(find.byKey(const Key('details-tab-2')));
    await tester.pump();
    expect(find.text('No related documents are available.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('signed production record does not display an unsigned PDF as signed',
      (tester) async {
    final production = DocumentRecord(
      id: 'prod-1',
      category: DocumentCategory.quotes,
      number: 'Q-100',
      title: 'Quote Q-100',
      project: 'Real project',
      customer: 'A. Customer',
      timestamp: DateTime(2026, 1, 1),
      status: 'Signed',
      quote: record.quote,
    );
    await tester.pumpWidget(page(document: production));
    await tester.tap(find.byKey(const Key('details-tab-1')));
    await tester.pump();
    expect(find.byKey(const Key('document-signed-pdf-unavailable')),
      findsOneWidget);
    expect(find.byKey(const Key('document-pdf-preview')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('document loader supports loading, missing, permission and retry',
      (tester) async {
    final ready = Completer<DocumentRecord?>();
    await tester.pumpWidget(MaterialApp(
      home: DocumentDetailsScreen(
        documentId: 'missing',
        loadDocument: (_) => ready.future,
      ),
    ));
    expect(find.byKey(const Key('document-details-loading')), findsOneWidget);
    ready.complete(null);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('document-details-missing')), findsOneWidget);

    await tester.pumpWidget(MaterialApp(
      home: DocumentDetailsScreen(
        key: const ValueKey('denied-case'),
        documentId: 'denied',
        loadDocument: (_) async => throw const DocumentPermissionDeniedException(),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Permission denied for this document.'), findsOneWidget);
  });

  testWidgets('phone, landscape and tablet details/history remain scrollable',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final size in [
      const Size(320, 650), const Size(375, 667),
      const Size(430, 932), const Size(720, 390),
      const Size(1024, 768),
    ]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(page());
      await tester.pump();
      expect(find.byKey(const Key('document-details-scroll')), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'Details $size');
      await tester.tap(find.byKey(const Key('details-tab-3')));
      await tester.pump();
      expect(find.byType(Sign2DigitalDocumentHistory), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(Key('document-history-event-${record.id}-signed')));
      await tester.pump();
      expect(find.text('Audit Information'), findsNothing);
      expect(tester.takeException(), isNull, reason: 'History $size');
    }
  });
}
