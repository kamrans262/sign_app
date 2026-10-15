import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/features/documents/domain/document_record.dart';
import 'package:sign2digital/features/documents/presentation/screens/generate_ai_document_screen.dart';
import 'package:sign2digital/features/documents/presentation/screens/document_details_screen.dart';
import 'package:sign2digital/features/jobs/data/mock_jobs.dart';
import 'package:sign2digital/features/jobs/services/voice_recorder_service.dart';
import 'package:sign2digital/features/jobs/services/voice_job_extraction_service.dart';
import 'package:sign2digital/features/jobs/models/extracted_job_details.dart';
import 'package:sign2digital/features/jobs/presentation/widgets/ai_voice_flow_dialog.dart';

class _Recorder implements VoiceRecorderService {
  final _level = StreamController<double>.broadcast();
  @override
  Stream<double> get amplitude => _level.stream;
  @override
  Future<void> start() async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> resume() async {}
  @override
  Future<String> save() async => '/fixture/saved-voice.m4a';
  @override
  Future<void> cancel() async {}
  @override
  Future<void> dispose() => _level.close();
}

class _Extraction implements VoiceJobExtractionService {
  @override
  bool get isConfigured => true;

  @override
  Future<ExtractedJobDetails> extract(String audioPath) async {
    return ExtractedJobDetails(
      description: 'Roof insulation and finishing work',
      startDate: DateTime(2026, 8, 25),
    );
  }
}

Future<void> _show(
  WidgetTester tester, {
  AiDocumentGenerator? generator,
  bool selectJob = false,
}) async {
  await tester.pumpWidget(MaterialApp(
    home: GenerateAiDocumentScreen(
      jobs: [MockJobsData.jobs.first],
      initialJob: selectJob ? MockJobsData.jobs.first : null,
      datePicker: (_, __) async => DateTime(2026, 8, 25),
      documentGenerator: generator,
      voiceRecorderFactory: _Recorder.new,
      voiceExtractionService: _Extraction(),
    ),
  ));
  await tester.pumpAndSettle();
}

Future<void> _reach(WidgetTester tester, String key) async {
  final target = find.byKey(Key(key));
  await tester.scrollUntilVisible(
    target, 130,
    scrollable: find.descendant(
      of: find.byKey(const Key('generate-ai-document-scroll')),
      matching: find.byType(Scrollable),
    ).first,
  );
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Uses shared header, form fields and defaults six sections on',
      (tester) async {
    await _show(tester);
    expect(find.text('AI Document'), findsOneWidget);
    expect(find.text('Create with AI Voice'), findsOneWidget);
    expect(find.byKey(const Key('generate-ai-date')), findsOneWidget);
    expect(find.byKey(const Key('generate-ai-job')), findsOneWidget);
    for (final section in AiDocumentSection.values) {
      expect(find.byKey(Key('generate-ai-section-${section.name}')),
        findsOneWidget);
    }
    expect(find.text('Generate Document'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Date and dropdown validate, section toggle and instructions persist',
      (tester) async {
    AiDocumentGenerationRequest? received;
    await _show(tester, generator: (request) async {
      received = request;
      throw StateError('Test generator is unavailable');
    });
    await tester.tap(find.byKey(const Key('generate-ai-submit')));
    await tester.pumpAndSettle();
    expect(find.text('Select a document date.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('generate-ai-date')));
    await tester.pumpAndSettle();
    expect(find.text('August 25, 2026'), findsOneWidget);
    await tester.tap(find.byKey(const Key('generate-ai-submit')));
    await tester.pumpAndSettle();
    expect(find.text('Select a valid Job / Project.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('generate-ai-job')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(
      Key('generate-ai-job-${MockJobsData.jobs.first.id}')));
    await tester.pumpAndSettle();
    await _reach(tester, 'generate-ai-section-photos');
    await tester.tap(find.byKey(const Key('generate-ai-section-photos')));
    await _reach(tester, 'generate-ai-instructions');
    await tester.enterText(
      find.byKey(const Key('generate-ai-instructions')),
      'Describe waterproofing only');
    await tester.tap(find.byKey(const Key('generate-ai-submit')));
    await tester.pumpAndSettle();
    expect(received?.job.id, MockJobsData.jobs.first.id);
    expect(received?.documentDate, DateTime(2026, 8, 25));
    expect(received?.sections, isNot(contains(AiDocumentSection.photos)));
    expect(received?.instructions, 'Describe waterproofing only');
    expect(find.textContaining('entries are preserved'), findsOneWidget);
  });

  testWidgets('Missing generator never claims an AI document was created',
      (tester) async {
    await _show(tester, selectJob: true);
    await tester.tap(find.byKey(const Key('generate-ai-date')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('generate-ai-submit')));
    await tester.pumpAndSettle();
    expect(find.text('AI document generation not connected'), findsOneWidget);
    expect(find.byKey(const Key('generate-ai-open-existing')), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.byType(GenerateAiDocumentScreen), findsOneWidget);
  });

  testWidgets('Saved service result opens existing document details',
      (tester) async {
    await _show(tester, selectJob: true,
      generator: (request) async => DocumentRecord(
        id: 'persisted-generated-report',
        category: DocumentCategory.reports,
        number: 'AI-2026-1',
        title: 'Actual generated report',
        project: request.job.title,
        customer: request.job.clientName,
        timestamp: request.documentDate,
        status: 'Generated',
      ),
    );
    await tester.tap(find.byKey(const Key('generate-ai-date')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('generate-ai-submit')));
    await tester.pumpAndSettle();
    expect(find.byType(DocumentDetailsScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Shared voice dialog opens and Cancel preserves manual input',
      (tester) async {
    await _show(tester);
    await _reach(tester, 'generate-ai-instructions');
    await tester.enterText(find.byKey(const Key('generate-ai-instructions')),
      'Existing manual instructions');
    await _reach(tester, 'generate-ai-voice');
    await tester.tap(find.byKey(const Key('generate-ai-voice')));
    await tester.pumpAndSettle();
    expect(find.byType(AiVoiceFlowDialog), findsOneWidget);
    await tester.tap(find.byKey(const Key('voice-cancel')));
    await tester.pumpAndSettle();
    await _reach(tester, 'generate-ai-instructions');
    expect(find.text('Existing manual instructions'), findsOneWidget);
  });

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(768, 1024),
  ]) {
    testWidgets('Generate AI Document scrolls and fits at $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _show(tester);
      await _reach(tester, 'generate-ai-instructions');
      expect(find.byKey(const Key('generate-ai-submit')), findsOneWidget);
      expect(tester.takeException(), isNull, reason: '$size');
    });
  }
}
