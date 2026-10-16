import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/features/documents/presentation/screens/document_details_screen.dart';
import 'package:sign2digital/features/documents/domain/addendum_draft.dart';
import 'package:sign2digital/features/documents/domain/document_record.dart';
import 'package:sign2digital/features/documents/presentation/screens/create_addendum_screen.dart';
import 'package:sign2digital/features/documents/services/addendum_voice_extraction_service.dart';
import 'package:sign2digital/features/jobs/services/voice_recorder_service.dart';

class _FakeRecorder implements VoiceRecorderService {
  @override
  Stream<double> get amplitude => const Stream<double>.empty();
  @override
  Future<void> start() async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> resume() async {}
  @override
  Future<String> save() async => '/fake/recorder/test.m4a';
  @override
  Future<void> cancel() async {}
  @override
  Future<void> dispose() async {}
}

class _FakeExtractor implements AddendumVoiceExtractionService {
  int calls = 0;
  @override
  Future<AddendumVoiceSuggestion> extract(String path, String key) async {
    calls++;
    expect(path, '/fake/recorder/test.m4a');
    expect(key, 'in-memory-demo-key');
    return AddendumVoiceSuggestion(
      number: 'A-0005',
      title: 'Terrace update',
      description: 'Waterproofing and new tiles',
      effectiveDate: DateTime(2026, 8, 25),
      documentReference: 'Q-12800',
    );
  }
}

/// A fixed test source avoids signed-quote filesystem access inside fake async.
/// The production repository is exercised in non-widget tests.
class _InMemoryDocumentRepository implements DocumentRepository {
  const _InMemoryDocumentRepository(this.records);

  final List<DocumentRecord> records;

  @override
  Future<List<DocumentRecord>> listDocuments() async => records;
}

List<DocumentRecord> _fixtureQuotes() => List<DocumentRecord>.generate(
  5,
  (index) => DocumentRecord(
    id: 'documents-figma-quote-${index + 1}',
    category: DocumentCategory.quotes,
    number: 'Q-12800',
    title: 'Quote Q-12800',
    project: 'Kitchen renovation',
    customer: 'Jean dupont',
    timestamp: DateTime(2026, 8, 23, 22),
    status: 'Signed',
    demoOnly: true,
  ),
);

void main() {
  setUp(AddendumDraftSession.clear);

  test('session draft is editable, validates and blocks duplicate numbers', () {
    final first = AddendumDraft(
      id: 'add-1', number: 'A-0005', title: 'Terrace',
      description: 'Extra work', effectiveDate: DateTime(2026, 8, 25),
      linkedDocumentId: 'documents-figma-quote-1',
    );
    AddendumDraftSession.save(first.copyWith(title: 'Revised terrace'));
    expect(AddendumDraftSession.load('add-1')!.title, 'Revised terrace');
    AddendumDraftSession.create(first);
    expect(AddendumDraftSession.created.length, 1);
    expect(AddendumDraftSession.isNumberUsed('a-0005'), isTrue);
    expect(AddendumDraftSession.load('add-1')!.isCreatedLocally, isTrue);
    expect(AddendumDraftSession.created.first.validationIssues, isEmpty);
    expect(() => AddendumDraftSession.create(first.copyWith(
      number: 'A-0005', title: 'Duplicate',
    ).copyWith()), returnsNormally); // Editing the same id is allowed.
    expect(() => AddendumDraftSession.create(AddendumDraft(
      id: 'second', number: 'A-0005', title: 'Second',
      description: 'Extra work', effectiveDate: DateTime(2026, 8, 25),
      linkedDocumentId: 'documents-figma-quote-1',
    )), throwsStateError);
  });

  testWidgets('addendum layout, linked quote, valid fields and draft persistence',
      (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _InMemoryDocumentRepository(_fixtureQuotes());
    final quote = repository.records.first;
    await tester.pumpWidget(MaterialApp(
      home: CreateAddendumScreen(
        repository: repository,
        draftId: 'ui-draft-1', linkedDocument: quote,
      ),
    ));
    expect(find.text('Addendum'), findsOneWidget);
    expect(find.text('Create with AI Voice'), findsOneWidget);
    expect(find.text('New'), findsOneWidget);
    expect(find.text('Link to Existing Documents'), findsOneWidget);
    expect(find.text('Quote Q-12800'), findsOneWidget);
    expect(find.text('Addendum Number'), findsOneWidget);
    expect(find.text('Title'), findsOneWidget);
    expect(find.text('Description'), findsOneWidget);
    expect(find.text('Effective Dates'), findsOneWidget);
    final inputs = find.byType(TextFormField);
    await tester.enterText(inputs.at(0), 'A-0005');
    await tester.enterText(inputs.at(1), 'Terrace works');
    await tester.enterText(inputs.at(2), 'Renovate waterproofing');
    await tester.ensureVisible(find.text('Save as Draft'));
    await tester.tap(find.text('Save as Draft'));
    await tester.pump();
    final saved = AddendumDraftSession.load('ui-draft-1')!;
    expect(saved.number, 'A-0005');
    expect(saved.linkedDocumentId, quote.id);
    expect(saved.description, 'Renovate waterproofing');
    expect(tester.takeException(), isNull);
  });

  testWidgets('invalid creation blocked, valid local create opens unsigned details',
      (tester) async {
    final repository = _InMemoryDocumentRepository(_fixtureQuotes());
    final quote = repository.records.first;
    await tester.pumpWidget(MaterialApp(home: CreateAddendumScreen(
        repository: repository,
      linkedDocument: quote, draftId: 'create-fixture',
    )));
    await tester.ensureVisible(find.text('Create Addendum'));
    await tester.tap(find.text('Create Addendum'));
    await tester.pump();
    expect(find.text('Addendum number is required.'), findsOneWidget);
    expect(AddendumDraftSession.created, isEmpty);

    AddendumDraftSession.save(AddendumDraft(
      id: 'create-fixture', number: 'A-0005', title: 'Additional works',
      description: 'Terrace waterproofing',
      effectiveDate: DateTime(2026, 8, 25),
      linkedDocumentId: quote.id,
    ));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(MaterialApp(home: CreateAddendumScreen(
        repository: repository,
      linkedDocument: quote, draftId: 'create-fixture',
    )));
    await tester.ensureVisible(find.text('Create Addendum'));
    await tester.tap(find.text('Create Addendum'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(AddendumDraftSession.created, hasLength(1));
    expect(find.byType(DocumentDetailsScreen), findsOneWidget);
    final document = tester.widget<DocumentDetailsScreen>(
      find.byType(DocumentDetailsScreen),
    ).document!;
    expect(document.category, DocumentCategory.addends);
    expect(document.status.toLowerCase(), isNot('signed'));
    expect(document.id, 'create-fixture');
    expect(tester.takeException(), isNull);
  });

  testWidgets('remove and reselect document without deleting underlying quote',
      (tester) async {
    final repository = _InMemoryDocumentRepository(_fixtureQuotes());
    final quote = repository.records.first;
    await tester.pumpWidget(MaterialApp(
      home: CreateAddendumScreen(
        repository: repository,linkedDocument: quote),
    ));
    await tester.tap(find.byKey(const Key('addendum-remove-linked-document')));
    await tester.pump();
    expect(find.byKey(const Key('addendum-linked-document')), findsNothing);
    await tester.tap(find.byKey(const Key('addendum-select-document')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(
      const Key('addendum-document-choice-documents-figma-quote-1')));
    await tester.pumpAndSettle();
    expect(find.text('Quote Q-12800'), findsOneWidget);
    expect(repository.records, hasLength(5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('shared recorder and AI processing apply suggestions without overwriting',
      (tester) async {
    final repository = _InMemoryDocumentRepository(_fixtureQuotes());
    final quote = repository.records.first;
    final extractor = _FakeExtractor();
    await tester.pumpWidget(MaterialApp(home: CreateAddendumScreen(
        repository: repository,
      linkedDocument: quote,
      voiceRecorderFactory: _FakeRecorder.new,
      voiceExtractionService: extractor,
      requestTemporaryApiKey: (_) async => 'in-memory-demo-key',
    )));
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(1), 'Manual title stays');
    await tester.ensureVisible(find.text('Create with AI Voice'));
    await tester.tap(find.text('Create with AI Voice'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Record Addendum Details'), findsOneWidget);
    await tester.tap(find.byKey(const Key('voice-save')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(extractor.calls, 1);
    expect(find.text('Manual title stays'), findsWidgets);
    final saved = tester.widgetList<TextFormField>(find.byType(TextFormField))
        .map((f) => f.controller?.text).toList();
    expect(saved, contains('A-0005'));
    expect(saved, contains('Waterproofing and new tiles'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('small phones, Figma and tablet landscape remain scrollable',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _InMemoryDocumentRepository(_fixtureQuotes());
    final quote = repository.records.first;
    for (final size in [const Size(320, 650), const Size(430, 932),
      const Size(720, 390), const Size(1024, 768)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(MaterialApp(
        home: CreateAddendumScreen(
        repository: repository,linkedDocument: quote),
      ));
      expect(find.byKey(const Key('create-addendum-scroll')), findsOneWidget);
      await tester.ensureVisible(find.text('Create Addendum'));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: '$size');
    }
  });
}
