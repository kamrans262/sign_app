import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/core/widgets/sign2digital_bottom_navigation_bar.dart';
import 'package:sign2digital/features/clients/presentation/screens/clients_screen.dart';
import 'package:sign2digital/features/documents/data/demo_document_repository.dart';
import 'package:sign2digital/features/documents/domain/document_record.dart';
import 'package:sign2digital/features/documents/presentation/screens/documents_screen.dart';
import 'package:sign2digital/features/documents/presentation/screens/document_details_screen.dart';
import 'package:sign2digital/features/quotes/presentation/widgets/sign2digital_quote_summary_card.dart';

class _DocumentSource implements DocumentRepository {
  _DocumentSource(this.load);
  final Future<List<DocumentRecord>> Function() load;
  @override
  Future<List<DocumentRecord>> listDocuments() => load();
}

void main() {
  test('five independent UI fixtures preserve the selected quote IDs',
      () async {
    final records = await const DemoDocumentRepository().listDocuments();
    expect(records, hasLength(5));
    expect(records.map((record) => record.id).toSet(), hasLength(5));
    expect(records.every((record) => record.demoOnly), isTrue);
    expect(records.every((record) => record.quote?.id == record.id), isTrue);
    expect(records.every((record) => !record.verifiedSignedPdfAvailable), isTrue);
    expect(records.first.matches('kitchen'), isTrue);
    expect(records.first.matches('jean'), isTrue);
    expect(records.first.matches('Q-12800'), isTrue);
    expect(records.first.matches('reports'), isFalse);
  });

  testWidgets('Documents tab uses existing header, cards and navigation',
      (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: ClientsScreen()));
    await tester.tap(find.byKey(const Key('dashboard-tab-3')));
    await tester.pumpAndSettle();

    expect(find.text('Search documents'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Quotes'), findsOneWidget);
    expect(find.text('Contacts'), findsOneWidget);
    expect(find.text('Reports'), findsOneWidget);
    expect(find.text('Addends'), findsOneWidget);
    expect(find.byType(Sign2DigitalQuoteSummaryCard), findsNWidgets(5));
    expect(find.byKey(const Key('documents-scroll')), findsOneWidget);
    final tabs = tester.widget<Sign2DigitalBottomNavigationBar>(
      find.byType(Sign2DigitalBottomNavigationBar),
    );
    expect(tabs.selectedIndex, 3);
    expect(tester.takeException(), isNull);
  });

  testWidgets('search and category filters retain their selected state',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: DocumentsScreen()),
    ));
    await tester.pumpAndSettle();
    // SliverList.builder lazily mounts only visible cards at 800x600.
    // Verify the actual fifth record by scrolling to it.
    expect(find.byType(Sign2DigitalQuoteSummaryCard), findsWidgets);
    await tester.scrollUntilVisible(
      find.byKey(const Key('document-card-documents-figma-quote-5')),
      150,
      scrollable: find.descendant(
        of: find.byKey(const Key('documents-scroll')),
        matching: find.byType(Scrollable),
      ).first,
    );
    expect(
      find.byKey(const Key('document-card-documents-figma-quote-5')),
      findsOneWidget,
    );
    await tester.ensureVisible(find.byKey(const Key('clients-search-input')));
    await tester.pump();

    await tester.tap(find.byKey(const Key('details-tab-2')));
    await tester.pumpAndSettle();
    expect(find.text('No documents in this category'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('clients-search-input')), 'unmatched',
    );
    await tester.pump();
    expect(find.text('No documents match your search'), findsOneWidget);

    await tester.tap(find.byKey(const Key('details-tab-1')));
    await tester.pumpAndSettle();
    expect(find.text('No documents match your search'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('clients-search-input')), 'Jean',
    );
    await tester.pumpAndSettle();
    expect(find.byType(Sign2DigitalQuoteSummaryCard), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('selected demo document opens the corresponding quote preview',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: DocumentsScreen()),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('document-card-documents-figma-quote-1')));
    await tester.pumpAndSettle();
    expect(find.byType(DocumentDetailsScreen), findsOneWidget);
    final details = tester.widget<DocumentDetailsScreen>(
      find.byType(DocumentDetailsScreen),
    );
    expect(details.documentId, 'documents-figma-quote-1');
    expect(details.document!.number, 'Q-12800');
    expect(details.document!.demoOnly, isTrue);
    expect(find.text('Document Information'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('loading, error, retry and empty dataset states',
      (tester) async {
    final first = Completer<List<DocumentRecord>>();
    var loads = 0;
    final repo = _DocumentSource(() {
      loads++;
      if (loads == 1) return first.future;
      return Future.value(<DocumentRecord>[]);
    });
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: DocumentsScreen(repository: repo)),
    ));
    expect(find.byKey(const Key('documents-loading')), findsOneWidget);
    first.completeError(StateError('offline'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('documents-retry')), findsOneWidget);
    await tester.tap(find.byKey(const Key('documents-retry')));
    await tester.pumpAndSettle();
    expect(find.text('No documents yet'), findsOneWidget);
    expect(loads, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('320px and landscape document layouts do not overflow',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final size in [
      const Size(320, 650),
      const Size(720, 390),
      const Size(1024, 768),
    ]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: DocumentsScreen()),
      ));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('documents-scroll')), findsOneWidget);
      expect(tester.takeException(), isNull, reason: '$size');
    }
  });
}
