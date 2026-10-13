import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/features/jobs/data/demo_job_notes.dart';
import 'package:sign2digital/features/jobs/data/mock_jobs.dart';
import 'package:sign2digital/features/jobs/domain/job_note_model.dart';
import 'package:sign2digital/features/jobs/presentation/screens/job_details_screen.dart';
import 'package:sign2digital/features/jobs/presentation/screens/job_notes_screen.dart';
import 'package:sign2digital/features/jobs/presentation/widgets/sign2digital_job_note_card.dart';

void main() {
  final job = MockJobsData.jobs.first;

  Future<void> setSize(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  test('notes have stable distinct IDs and belong to their selected job', () {
    final notes = DemoJobNotes.forJob(job.id, now: DateTime(2026, 10, 12));
    expect(notes, hasLength(3));
    expect(notes.map((n) => n.id).toSet(), hasLength(3));
    expect(notes.every((n) => n.jobId == job.id), isTrue);
    expect(
      notes.where((n) => n.type == JobNoteType.textWithAudio),
      hasLength(1),
    );
    expect(notes.first.timestampLabel(DateTime(2026, 10, 12)), 'Today 10:24');
    expect(
      notes.first.timestampLabel(DateTime(2026, 10, 14)),
      '12 Oct 2026 10:24',
    );
  });

  testWidgets('Job Details Notes card opens Job Notes and custom Back works', (
    tester,
  ) async {
    await setSize(tester, const Size(430, 932));
    await tester.pumpWidget(MaterialApp(home: JobDetailsScreen(job: job)));
    await tester.pumpAndSettle();
    final notesCard = find.byKey(const Key('job-section-notes'));
    await tester.ensureVisible(notesCard);
    await tester.pumpAndSettle();
    await tester.tap(notesCard);
    await tester.pumpAndSettle();
    expect(find.byType(JobNotesScreen), findsOneWidget);
    expect(find.text('Keep track of important information'), findsOneWidget);
    expect(find.byKey(const Key('dashboard-tab-1')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pumpAndSettle();
    expect(find.byType(JobNotesScreen), findsNothing);
    expect(find.byType(JobDetailsScreen), findsOneWidget);
  });

  testWidgets('tabs filter by note type and do not invent voice recordings', (
    tester,
  ) async {
    await setSize(tester, const Size(430, 932));
    await tester.pumpWidget(MaterialApp(home: JobNotesScreen(job: job)));
    await tester.pumpAndSettle();
    expect(find.byType(Sign2DigitalJobNoteCard), findsNWidgets(3));
    await tester.tap(find.byKey(const Key('details-tab-1')));
    await tester.pumpAndSettle();
    expect(find.text('No voice notes yet.'), findsOneWidget);
    expect(find.byType(Sign2DigitalJobNoteCard), findsNothing);
    await tester.tap(find.byKey(const Key('details-tab-0')));
    await tester.pumpAndSettle();
    expect(find.byType(Sign2DigitalJobNoteCard), findsNWidgets(3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('voice notes are shown only under Voice Notes', (tester) async {
    await setSize(tester, const Size(430, 932));
    final note = JobNoteModel(
      id: 'voice-1',
      jobId: job.id,
      title: 'Audio reminder',
      body: 'Voice entry',
      createdAt: DateTime(2026, 10, 12, 10, 24),
      type: JobNoteType.voice,
      visibility: JobNoteVisibility.privateNote,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: JobNotesScreen(job: job, notes: [note]),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Audio reminder'), findsNothing);
    await tester.tap(find.byKey(const Key('details-tab-1')));
    await tester.pumpAndSettle();
    expect(find.text('Audio reminder'), findsOneWidget);
  });

  testWidgets('visibility and Add Notes callback pass job, type and privacy', (
    tester,
  ) async {
    await setSize(tester, const Size(430, 932));
    String? resultJob;
    JobNoteVisibility? resultVisibility;
    JobNoteType? resultType;
    await tester.pumpWidget(
      MaterialApp(
        home: JobNotesScreen(
          job: job,
          onAddNotes: (id, visibility, type) {
            resultJob = id;
            resultVisibility = visibility;
            resultType = type;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('note-visibility-customer')));
    await tester.tap(find.byKey(const Key('details-tab-1')));
    await tester.pumpAndSettle();
    final button = find.text('＋ Add Notes');
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    expect(resultJob, job.id);
    expect(resultVisibility, JobNoteVisibility.customerFacing);
    expect(resultType, JobNoteType.voice);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tap callback receives actual note and banner dismiss is local', (
    tester,
  ) async {
    await setSize(tester, const Size(430, 932));
    JobNoteModel? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: JobNotesScreen(job: job, onNoteTap: (note) => selected = note),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(job.title), findsOneWidget);
    await tester.tap(find.byKey(const Key('job-photo-dismiss-banner')));
    await tester.pumpAndSettle();
    expect(find.text(job.title), findsNothing);
    final target = find.byKey(Key('job-note-${job.id}-demo-note-1'));
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    expect(selected?.id, '${job.id}-demo-note-1');
    expect(tester.takeException(), isNull);
  });

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(430, 932),
    const Size(932, 430),
    const Size(1024, 768),
  ]) {
    testWidgets('Job Notes is responsive at $size', (tester) async {
      await setSize(tester, size);
      await tester.pumpWidget(MaterialApp(home: JobNotesScreen(job: job)));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('dashboard-tab-1')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.drag(
        find.byKey(const Key('job-notes-scroll')),
        const Offset(0, -1200),
      );
      await tester.pumpAndSettle();
      expect(find.text('＋ Add Notes'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
