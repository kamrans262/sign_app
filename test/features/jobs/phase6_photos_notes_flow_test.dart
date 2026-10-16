import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/features/jobs/data/job_note_local_store.dart';
import 'package:sign2digital/features/jobs/data/mock_jobs.dart';
import 'package:sign2digital/features/jobs/domain/job_note_model.dart';
import 'package:sign2digital/features/jobs/domain/note_document_draft.dart';
import 'package:sign2digital/features/jobs/presentation/screens/add_job_note_screen.dart';
import 'package:sign2digital/features/jobs/presentation/screens/convert_document_screen.dart';
import 'package:sign2digital/features/jobs/presentation/screens/job_notes_screen.dart';
import 'package:sign2digital/features/jobs/services/voice_recorder_service.dart';

class _Recorder implements VoiceRecorderService {
  bool started = false;
  @override
  Stream<double> get amplitude => const Stream<double>.empty();
  @override
  Future<void> start() async { started = true; }
  @override
  Future<void> pause() async {}
  @override
  Future<void> resume() async {}
  @override
  Future<String> save() async => '/recorded/note.m4a';
  @override
  Future<void> cancel() async {}
  @override
  Future<void> dispose() async {}
}

class _DocumentAI implements NoteDocumentPreparationService {
  String? type;
  String? sourceNoteId;

  @override
  Future<NoteDocumentDraft> prepare(
      JobNoteModel note, String documentType) async {
    type = documentType;
    sourceNoteId = note.id;
    return NoteDocumentDraft(
      noteId: note.id, jobId: note.jobId,
      documentType: documentType,
      title: 'Visit report', content: 'Scope: ${note.body}',
    );
  }
}

void main() {
  final job = MockJobsData.jobs.first;
  setUp(NoteDocumentDraftSession.clear);

  test('session note storage is job scoped and does not send anything', () {
    final store = JobNoteLocalStore(includeDemoNotes: false);
    store.add(JobNoteModel(
      id: 'new-1', jobId: job.id, title: 'Private update',
      body: 'Concrete was inspected',
      createdAt: DateTime(2026, 10, 16),
      type: JobNoteType.text, visibility: JobNoteVisibility.privateNote,
    ));
    expect(store.notesFor(job.id), hasLength(1));
    expect(store.notesFor('another-job'), isEmpty);
    expect(store.notesFor(job.id).single.visibility,
        JobNoteVisibility.privateNote);
  });

  testWidgets('Add Notes saves a new private text note into the selected job',
      (tester) async {
    final store = JobNoteLocalStore(includeDemoNotes: false);
    await tester.pumpWidget(MaterialApp(home: JobNotesScreen(
      job: job, store: store,
    )));
    await tester.ensureVisible(find.text('＋ Add Notes'));
    await tester.tap(find.text('＋ Add Notes'));
    await tester.pumpAndSettle();
    expect(find.byType(AddJobNoteScreen), findsOneWidget);
    final inputs = find.byType(TextFormField);
    await tester.enterText(inputs.at(0), 'Worksite update');
    await tester.enterText(inputs.at(1), 'Floor has been installed');
    await tester.ensureVisible(find.byKey(const Key('job-note-save')));
    await tester.tap(find.byKey(const Key('job-note-save')));
    await tester.pumpAndSettle();
    expect(find.byType(AddJobNoteScreen), findsNothing);
    expect(store.notesFor(job.id), hasLength(1));
    expect(store.notesFor(job.id).first.body, 'Floor has been installed');
    expect(store.notesFor(job.id).first.type, JobNoteType.text);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Voice Notes requires a real recorded path before saving',
      (tester) async {
    final store = JobNoteLocalStore(includeDemoNotes: false);
    final recorder = _Recorder();
    await tester.pumpWidget(MaterialApp(home: JobNotesScreen(
      job: job, store: store, voiceRecorderFactory: () => recorder,
    )));
    await tester.tap(find.byKey(const Key('details-tab-1')));
    await tester.pump();
    await tester.ensureVisible(find.text('＋ Add Notes'));
    await tester.tap(find.text('＋ Add Notes'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Voice update');
    await tester.ensureVisible(find.byKey(const Key('job-note-save')));
    await tester.tap(find.byKey(const Key('job-note-save')));
    await tester.pump();
    expect(store.notesFor(job.id), isEmpty);
    await tester.ensureVisible(find.byKey(const Key('job-note-record')));
    await tester.tap(find.byKey(const Key('job-note-record')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(recorder.started, isTrue);
    await tester.tap(find.byKey(const Key('voice-save')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('job-note-audio-ready')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('job-note-save')));
    await tester.tap(find.byKey(const Key('job-note-save')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(store.notesFor(job.id).single.type, JobNoteType.voice);
    expect(store.notesFor(job.id).single.audioPath, '/recorded/note.m4a');
    expect(tester.takeException(), isNull);
  });

  testWidgets('customer-facing note cannot be converted as a private note',
      (tester) async {
    final note = JobNoteModel(
      id: 'customer-1', jobId: job.id, title: 'Shared observation',
      body: 'Customer-visible text', createdAt: DateTime.now(),
      type: JobNoteType.text,
      visibility: JobNoteVisibility.customerFacing,
    );
    await tester.pumpWidget(MaterialApp(home: JobNotesScreen(
      job: job, notes: [note],
    )));
    await tester.tap(find.byKey(const Key('job-note-customer-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('job-note-convert')), findsNothing);
    expect(find.text('Close'), findsOneWidget);
  });

  testWidgets('Report AI produces editable job-linked draft for local approval',
      (tester) async {
    final ai = _DocumentAI();
    final note = JobNoteModel(
      id: 'private-1', jobId: job.id, title: 'Roof inspection',
      body: 'Roof tiles need replacement', createdAt: DateTime.now(),
      type: JobNoteType.text,
      visibility: JobNoteVisibility.privateNote,
    );
    await tester.pumpWidget(MaterialApp(home: ConvertDocumentScreen(
      note: note, notePreparationService: ai,
    )));
    await tester.tap(find.byKey(const Key('convert-document-type-1')));
    await tester.ensureVisible(find.byKey(const Key('convert-generate-draft')));
    await tester.tap(find.byKey(const Key('convert-generate-draft')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(ai.sourceNoteId, note.id);
    expect(ai.type, 'report');
    expect(find.byKey(const Key('note-document-content')), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('note-document-content')),
      'Edited after checking the site',
    );
    await tester.tap(find.byKey(const Key('note-document-approve')));
    await tester.pump();
    final saved = NoteDocumentDraftSession.forNote(note.id, 'report')!;
    expect(saved.content, 'Edited after checking the site');
    expect(saved.approvedLocally, isTrue);
    expect(saved.jobId, job.id);
    expect(tester.takeException(), isNull);
  });
}
