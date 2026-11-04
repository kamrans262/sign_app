import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/features/jobs/data/mock_jobs.dart';
import 'package:sign2digital/features/jobs/domain/job_note_model.dart';
import 'package:sign2digital/features/jobs/domain/note_document_draft.dart';
import 'package:sign2digital/features/jobs/presentation/screens/convert_document_screen.dart';
import 'package:sign2digital/features/jobs/presentation/screens/job_notes_screen.dart';
import 'package:sign2digital/features/jobs/presentation/widgets/sign2digital_job_note_card.dart';
import 'package:sign2digital/features/quotes/domain/quote_draft_input.dart';
import 'package:sign2digital/features/quotes/domain/quote_extraction_models.dart';
import 'package:sign2digital/features/quotes/domain/quote_preparation_service.dart';
import 'package:sign2digital/features/quotes/presentation/screens/quote_ai_processing_screen.dart';
import 'package:sign2digital/features/quotes/presentation/screens/review_quote_screen.dart';
import 'package:sign2digital/features/quotes/presentation/widgets/sign2digital_document_status_timeline.dart';
import 'package:sign2digital/features/quotes/presentation/widgets/sign2digital_signature_action_card.dart';
import 'package:sign2digital/core/widgets/sign2digital_bottom_navigation_bar.dart';

class _RecordingService implements QuotePreparationService {
  final stream = StreamController<QuotePreparationSnapshot>.broadcast();
  QuoteDraftInput? received;

  @override
  Stream<QuotePreparationSnapshot> prepare(QuoteDraftInput input) {
    received = input;
    return stream.stream;
  }

  Future<void> dispose() => stream.close();
}

final note = JobNoteModel(
  id: 'job-note-one',
  jobId: 'job-130',
  title: 'Site meeting with Client',
  body: 'Complete renovation of the terrace, including new tiles, '
    'waterproofing and railings',
  createdAt: DateTime(2026, 8, 12, 10, 30),
  visibility: JobNoteVisibility.privateNote,
  type: JobNoteType.text,
);

class _FakeNotePreparationService implements NoteDocumentPreparationService {
  JobNoteModel? received;
  String? receivedType;

  @override
  Future<NoteDocumentDraft> prepare(
      JobNoteModel input, String documentType) async {
    received = input;
    receivedType = documentType;
    return NoteDocumentDraft(
      noteId: input.id,
      jobId: input.jobId,
      documentType: documentType,
      title: 'Generated report',
      content: 'Based only on: ${input.body}',
    );
  }
}

void main() {
  setUp(NoteDocumentDraftSession.clear);
  testWidgets('note dialog opens real note conversion; Back preserves Job Notes',
      (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: JobNotesScreen(
        job: MockJobsData.jobs.first,
        notes: [
          JobNoteModel(
            id: 'linked-note',
            jobId: MockJobsData.jobs.first.id,
            title: note.title, body: note.body,
            createdAt: note.createdAt,
            visibility: note.visibility, type: note.type,
          ),
        ],
      ),
    ));
    await tester.ensureVisible(find.byKey(const Key('job-note-linked-note')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('job-note-linked-note')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('job-note-convert')));
    await tester.pumpAndSettle();
    final screen = tester.widget<ConvertDocumentScreen>(
      find.byType(ConvertDocumentScreen),
    );
    expect(screen.note.id, 'linked-note');
    expect(screen.note.jobId, MockJobsData.jobs.first.id);
    expect(find.text('Convert Document'), findsOneWidget);
    expect(find.byType(Sign2DigitalBottomNavigationBar), findsOneWidget);
    final nav = tester.widget<Sign2DigitalBottomNavigationBar>(
      find.byType(Sign2DigitalBottomNavigationBar));
    expect(nav.selectedIndex, 1);
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pumpAndSettle();
    expect(find.byType(JobNotesScreen), findsOneWidget);
    expect(find.byType(ConvertDocumentScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Figma note card, selected Quote, four steps and Jobs navigation',
      (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: ConvertDocumentScreen(note: note),
    ));
    expect(find.text('Selected Note'), findsOneWidget);
    expect(find.byType(Sign2DigitalJobNoteCard), findsOneWidget);
    expect(find.text(note.title), findsOneWidget);
    expect(find.text(note.body), findsOneWidget);
    expect(find.text('Private'), findsOneWidget);
    expect(find.text('At 10:30'), findsOneWidget);
    expect(find.text('Document Type'), findsOneWidget);
    expect(find.text('AI Document Preparation'), findsOneWidget);
    expect(find.text('Select document Type'), findsOneWidget);
    expect(find.text('AI Draft'), findsOneWidget);
    expect(find.text('Review'), findsOneWidget);
    expect(find.text('Approve'), findsOneWidget);
    expect(find.byKey(const Key('document-preparation-timeline')), findsOneWidget);
    expect(find.byType(Sign2DigitalSignatureActionCard), findsNWidgets(4));
    final quote = tester.widget<Sign2DigitalSignatureActionCard>(
      find.byKey(const Key('convert-document-type-0')));
    expect(quote.selected, isTrue);
    final report = tester.widget<Sign2DigitalSignatureActionCard>(
      find.byKey(const Key('convert-document-type-1')));
    expect(report.selected, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('selecting another type prepares editable draft only with user review',
      (tester) async {
    final generated = _FakeNotePreparationService();
    await tester.pumpWidget(MaterialApp(home: ConvertDocumentScreen(
      note: note, notePreparationService: generated,
    )));
    await tester.tap(find.byKey(const Key('convert-document-type-1')));
    await tester.pump();
    expect(tester.widget<Sign2DigitalSignatureActionCard>(
      find.byKey(const Key('convert-document-type-1'))).selected, isTrue);
    expect(tester.widget<Sign2DigitalSignatureActionCard>(
      find.byKey(const Key('convert-document-type-0'))).selected, isFalse);
    expect(find.text(note.body), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('convert-generate-draft')));
    await tester.tap(find.byKey(const Key('convert-generate-draft')));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(generated.received?.id, note.id);
    expect(generated.receivedType, 'report');
    expect(find.text('Review document draft'), findsOneWidget);
    expect(find.byType(QuoteAiProcessingScreen), findsNothing);
    await tester.tap(find.byKey(const Key('note-document-approve')));
    await tester.pumpAndSettle();
    expect(NoteDocumentDraftSession.forNote(note.id, 'report')?.approvedLocally, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('real selected note and job IDs reach existing quote service/review',
      (tester) async {
    final service = _RecordingService();
    addTearDown(service.dispose);
    await tester.pumpWidget(MaterialApp(
      home: ConvertDocumentScreen(
        note: note,
        quotePreparationService: service,
      ),
    ));
    await tester.ensureVisible(find.byKey(const Key('convert-generate-draft')));
    await tester.tap(find.byKey(const Key('convert-generate-draft')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(QuoteAiProcessingScreen), findsOneWidget);
    expect(service.received?.method, QuoteInputMethod.text);
    expect(service.received?.description, note.body);
    expect(service.received?.jobId, note.jobId);
    expect(service.received?.sourceNoteId, note.id);
    service.stream.add(const QuotePreparationSnapshot(
      stage: QuotePreparationStage.completed,
      items: [
        QuotePreparedWorkItem(
          title: 'Terrace renovation',
          description: 'Tiles and waterproofing',
          quantity: 1,
        ),
      ],
    ));
    await tester.pump();
    final review = find.byKey(const Key('quote-processing-review'));
    await tester.ensureVisible(review);
    await tester.tap(review);
    await tester.pumpAndSettle();
    expect(find.byType(ReviewQuoteScreen), findsOneWidget);
    final draft = tester.widget<ReviewQuoteScreen>(
      find.byType(ReviewQuoteScreen)).initialDraft;
    expect(draft.jobId, note.jobId);
    expect(draft.sourceNoteId, note.id);
    expect(draft.approvedLocally, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty selected note refuses AI request',
      (tester) async {
    final empty = JobNoteModel(
      id: 'blank', jobId: note.jobId,
      title: 'Blank note', body: '',
      createdAt: note.createdAt, type: note.type,
      visibility: note.visibility,
    );
    await tester.pumpWidget(MaterialApp(home: ConvertDocumentScreen(note: empty)));
    await tester.ensureVisible(find.byKey(const Key('convert-generate-draft')));
    await tester.tap(find.byKey(const Key('convert-generate-draft')));
    await tester.pump();
    expect(find.textContaining('no text to prepare'), findsOneWidget);
    expect(find.byType(QuoteAiProcessingScreen), findsNothing);
  });

  for (final size in [
    const Size(320, 650),
    const Size(375, 667),
    const Size(430, 932),
    const Size(720, 390),
    const Size(1024, 768),
  ]) {
    testWidgets('conversion scroll and fixed navigation stay usable at $size',
      (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(home: ConvertDocumentScreen(note: note)));
      final bottom = find.byType(Sign2DigitalBottomNavigationBar);
      expect(tester.widget<Sign2DigitalBottomNavigationBar>(bottom).selectedIndex, 1);
      final scroll = find.byKey(const Key('convert-document-scroll'));
      expect(tester.getBottomRight(scroll).dy,
        lessThanOrEqualTo(tester.getTopLeft(bottom).dy + 1));
      await tester.ensureVisible(find.byKey(const Key('convert-generate-draft')));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }
}
