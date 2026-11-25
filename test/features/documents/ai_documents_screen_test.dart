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


Future<void> _reach(WidgetTester tester, String id, {bool up = false}) async {
  final target = find.byKey(Key(id));
  if (target.evaluate().isNotEmpty) {
    await tester.ensureVisible(target);
  } else {
    await tester.scrollUntilVisible(target, up ? -130 : 130,
      scrollable: find.byType(Scrollable).first);
  }
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
    expect(find.text('Summarize Document'), findsNothing);
    expect(find.text('Translate Document'), findsNothing);
    expect(find.byKey(const Key('ai-documents-create')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Only repository records appear; See all preserves them',
      (tester) async {
    await _screen(tester, repository: _Repository([_generated(1)]));
    expect(find.text('Recent AI Documents'), findsOneWidget);
    await _reach(tester, 'ai-document-card-ai-document-test-1');
    expect(find.byKey(const Key('ai-document-card-ai-document-test-1')),
      findsOneWidget);
    expect(find.textContaining('AI-DEMO'), findsNothing);
    await _reach(tester, 'ai-documents-see-all', up: true);
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
    await _reach(tester, 'ai-document-card-ai-document-test-2');
    expect(find.text('Generated Document 2'), findsOneWidget);
    await _reach(tester, 'ai-document-card-ai-document-test-1', up: true);
    expect(find.text('Generated Document 1'), findsOneWidget);
    await _screen(tester, repository: _Repository([]));
    await _reach(tester, 'ai-documents-empty');
    expect(find.byKey(const Key('ai-documents-empty')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Unauthenticated generation cannot create fictional documents',
      (tester) async {
    await _screen(tester, repository: _Repository([]));
    await tester.tap(find.byKey(const Key('ai-documents-generate')));
    await tester.pumpAndSettle();
    expect(find.byType(GenerateAiDocumentScreen), findsNothing);
    expect(find.textContaining('Sign in to generate'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Unconnected summarize and translate buttons are absent',
      (tester) async {
    await _screen(tester, repository: _Repository([_generated(1)]));
    expect(find.byKey(const Key('ai-documents-summarize')), findsNothing);
    expect(find.byKey(const Key('ai-documents-translate')), findsNothing);
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
      await _screen(tester, repository: _Repository([]));
      final scroll = find.byKey(const Key('ai-documents-scroll'));
      await tester.drag(scroll, const Offset(0, -600));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$size');
    });
  }
}
