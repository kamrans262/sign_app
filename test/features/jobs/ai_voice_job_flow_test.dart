import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/core/widgets/sign2digital_input_field.dart';
import 'package:sign2digital/features/clients/data/client_repository.dart';
import 'package:sign2digital/features/clients/domain/client_draft.dart';
import 'package:sign2digital/features/clients/domain/client_profile.dart';
import 'package:sign2digital/features/jobs/models/extracted_job_details.dart';
import 'package:sign2digital/features/jobs/presentation/screens/create_job_screen.dart';
import 'package:sign2digital/features/jobs/presentation/widgets/ai_voice_flow_dialog.dart';

import '../../support/fake_voice_services.dart';

class SingleClientRepository implements ClientRepository {
  @override
  Future<List<ClientProfile>> listClients() async => [
    const ClientProfile(
      id: 'real-client-1',
      companyName: 'Alpine Renovations',
      companyType: 'Business',
      email: 'contact@alpine.ch',
      phone: '',
      jobCount: 0,
    ),
  ];

  @override
  Future<ClientProfile> createClient(ClientDraft draft) =>
      throw UnimplementedError();

  @override
  Future<ClientProfile> updateClient(String id, ClientDraft draft) =>
      throw UnimplementedError();
}

Future<void> openVoice(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('create-with-ai-voice-button')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  test('JSON suggestions reject invalid dates and budget', () {
    final result = ExtractedJobDetails.fromJson({
      'startDate': '2026-02-30',
      'endDate': 'unsure',
      'budgetChf': -20,
      'teamMemberNames': ['Sophie Bernard', '', null],
      'address': '  Rue de Genève 12  ',
    });
    expect(result.startDate, isNull);
    expect(result.endDate, isNull);
    expect(result.budgetChf, isNull);
    expect(result.address, 'Rue de Genève 12');
    expect(result.teamMemberNames, ['Sophie Bernard']);
  });

  testWidgets('record pause resume save process -> form fields + ID mapping', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final recorder = FakeVoiceRecorder();
    final pending = Completer<ExtractedJobDetails>();
    final extraction = FakeVoiceExtraction(onExtract: (_) => pending.future);
    await tester.pumpWidget(
      MaterialApp(
        home: CreateJobScreen(
          clientRepository: SingleClientRepository(),
          voiceRecorderFactory: () => recorder,
          voiceExtractionService: extraction,
        ),
      ),
    );
    await openVoice(tester);
    expect(find.byType(AiVoiceFlowDialog), findsOneWidget);
    expect(find.text('Record Job Details'), findsOneWidget);
    expect(find.text('● Recording'), findsOneWidget);
    expect(recorder.starts, 1);
    await tester.tap(find.byKey(const Key('voice-pause-resume')));
    await tester.pump();
    expect(recorder.pauses, 1);
    expect(find.text('Paused'), findsOneWidget);
    await tester.tap(find.byKey(const Key('voice-pause-resume')));
    await tester.pump();
    expect(recorder.resumes, 1);
    await tester.tap(find.byKey(const Key('voice-save')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(recorder.saves, 1);
    expect(extraction.calls, 1);
    expect(find.text('AI is Processing your Voice'), findsOneWidget);
    expect(find.byKey(const Key('voice-processing-waveform')), findsOneWidget);
    pending.complete(
      const ExtractedJobDetails(
        clientName: 'Alpine Renovations',
        address: 'Rue de Genève 12, Lausanne',
        description: 'Renovate the terrace.',
        budgetChf: 12000,
        teamMemberNames: ['Sophie Bernard'],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AiVoiceFlowDialog), findsNothing);
    expect(find.text('Alpine Renovations'), findsOneWidget);
    expect(find.text('Sophie Bernard'), findsOneWidget);
    final address = tester.widget<Sign2DigitalInputField>(
      find.widgetWithText(Sign2DigitalInputField, 'Address'),
    );
    expect(address.controller.text, 'Rue de Genève 12, Lausanne');
    expect(recorder.disposed, isTrue);
  });

  testWidgets('cancel discards unfinished recording and leaves the form', (
    tester,
  ) async {
    final recorder = FakeVoiceRecorder();
    await tester.pumpWidget(
      MaterialApp(
        home: CreateJobScreen(
          voiceRecorderFactory: () => recorder,
          voiceExtractionService: FakeVoiceExtraction(),
        ),
      ),
    );
    await openVoice(tester);
    await tester.tap(find.byKey(const Key('voice-cancel')));
    await tester.pumpAndSettle();
    expect(recorder.cancels, 1);
    expect(find.byType(AiVoiceFlowDialog), findsNothing);
    expect(find.text('Create Job'), findsOneWidget);
  });

  testWidgets('without a real service, shows truthful unavailable state', (
    tester,
  ) async {
    final recorder = FakeVoiceRecorder();
    await tester.pumpWidget(
      MaterialApp(
        home: CreateJobScreen(
          voiceRecorderFactory: () => recorder,
          voiceExtractionService: FakeVoiceExtraction(configured: false),
        ),
      ),
    );
    await openVoice(tester);
    await tester.tap(find.byKey(const Key('voice-save')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 240));
    expect(find.text('AI extraction unavailable'), findsOneWidget);
    expect(
      find.textContaining('Your recording has been saved'),
      findsOneWidget,
    );
    await tester.tap(find.text('Close / Manual Entry'));
    await tester.pumpAndSettle();
    expect(find.byType(AiVoiceFlowDialog), findsNothing);
    expect(recorder.cancels, 0); // Saved audio must not be thrown away.
  });

  testWidgets('preserves manually typed values when AI suggests replacements', (
    tester,
  ) async {
    final recorder = FakeVoiceRecorder();
    final extraction = FakeVoiceExtraction(
      onExtract: (_) async => const ExtractedJobDetails(
        address: 'Different address',
        description: 'AI description',
        budgetChf: 5000,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: CreateJobScreen(
          voiceRecorderFactory: () => recorder,
          voiceExtractionService: extraction,
        ),
      ),
    );
    final address = tester.widget<Sign2DigitalInputField>(
      find.widgetWithText(Sign2DigitalInputField, 'Address'),
    );
    address.controller.text = 'Keep this manual address';
    await openVoice(tester);
    await tester.tap(find.byKey(const Key('voice-save')));
    await tester.pumpAndSettle();
    expect(address.controller.text, 'Keep this manual address');
    expect(find.text('Create Job'), findsOneWidget);
  });

  testWidgets(
    'without a server, saved recording asks for a temporary API key',
    (tester) async {
      final recorder = FakeVoiceRecorder();
      await tester.pumpWidget(
        MaterialApp(
          home: CreateJobScreen(voiceRecorderFactory: () => recorder),
        ),
      );
      await openVoice(tester);
      await tester.tap(find.byKey(const Key('voice-save')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 240));
      expect(find.text('Connect AI Processing'), findsOneWidget);
      expect(find.byKey(const Key('voice-openai-api-key')), findsOneWidget);
      expect(find.byKey(const Key('voice-process-with-key')), findsOneWidget);
      expect(recorder.saves, 1);
      await tester.tap(find.text('Close / Manual Entry'));
      await tester.pumpAndSettle();
      expect(find.byType(AiVoiceFlowDialog), findsNothing);
    },
  );
}
