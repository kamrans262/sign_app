import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/features/clients/presentation/screens/more_screen.dart';
import 'package:sign2digital/features/documents/domain/document_record.dart';
import 'package:sign2digital/features/documents/presentation/screens/ai_documents_screen.dart';
import 'package:sign2digital/features/documents/presentation/screens/generate_ai_document_screen.dart';

class _Repository implements DocumentRepository {
  _Repository(this.items, {this.fail = false});
  final List<DocumentRecord> items;
  final bool fail;

  @override
  Future<List<DocumentRecord>> listDocuments() async {
    if (fail) { throw StateError('Document loading unavailable'); }
    return items;
  }
}

DocumentRecord _generated(int index) => DocumentRecord(
  id: 'ai-document-test-$index',
  category: DocumentCategory.reports,
  number: 'AI-2026-$index',
  title: 'Generated Document $index',
  project: 'Riverside Villa',
  customer: 'Jean Dupont',
  timestamp: DateTime(2026, 8, 12 + index),
  status: 'Generated',
);

Future<void> _screen(WidgetTester tester, {
  DocumentRepository? repository,
}) async {
  await tester.pumpWidget(MaterialApp(
    home: AiDocumentsScreen(
      key: ValueKey(repository), repository: repository),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('More menu opens AI Documents using existing dashboard',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MoreScreen()));
    await tester.tap(find.byKey(const Key('open-ai-documents')));
    await tester.pumpAndSettle();
    expect(find.byType(AiDocumentsScreen), findsOneWidget);
    expect(find.text('Generate Document'), findsOneWidget);
    expect(find.text('Summarize Document'), findsOneWidget);
    expect(find.text('Translate Document'), findsOneWidget);
    expect(find.byKey(const Key('ai-documents-create')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Demo examples are UI-only and See all opens full listing',
      (tester) async {
    await _screen(tester);
    expect(find.text('Recent AI Documents'), findsOneWidget);
    expect(find.byKey(const Key('ai-document-card-ai-document-figma-1')),
      findsWidgets);
    await tester.tap(find.byKey(const Key('ai-documents-see-all')));
    await tester.pumpAndSettle();
    expect(find.text('All AI Documents'), findsOneWidget);
    expect(find.text('Recent AI Documents'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Injected repository supports dynamic cards and empty states',
      (tester) async {
    await _screen(tester, repository: _Repository([
      _generated(1), _generated(2),
    ]));
    expect(find.text('Generated Document 2'), findsOneWidget);
    expect(find.text('Generated Document 1'), findsOneWidget);
    await _screen(tester, repository: _Repository([]));
    expect(find.byKey(const Key('ai-documents-empty')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Generate action and FAB open the new AI Document form',
      (tester) async {
    await _screen(tester);
    await tester.tap(find.byKey(const Key('ai-documents-generate')));
    await tester.pumpAndSettle();
    expect(find.byType(GenerateAiDocumentScreen), findsOneWidget);
    expect(find.text('AI Document'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ai-documents-create')));
    await tester.pumpAndSettle();
    expect(find.byType(GenerateAiDocumentScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Summarize selection never invents an AI output',
      (tester) async {
    await _screen(tester, repository: _Repository([_generated(1)]));
    await tester.tap(find.byKey(const Key('ai-documents-summarize')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(
      const Key('ai-documents-select-ai-document-test-1')));
    await tester.pumpAndSettle();
    expect(find.textContaining('not connected yet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(768, 1024),
  ]) {
    testWidgets('AI Documents fits on $size without overflow', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _screen(tester);
      final scroll = find.byKey(const Key('ai-documents-scroll'));
      await tester.drag(scroll, const Offset(0, -600));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$size');
    });
  }
}
