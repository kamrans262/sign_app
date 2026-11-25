import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/features/clients/domain/client_profile.dart';
import 'package:sign2digital/features/jobs/presentation/screens/create_job_screen.dart';
import 'package:sign2digital/features/jobs/presentation/widgets/ai_voice_flow_dialog.dart';

import '../../support/fake_voice_services.dart';

void main() {
  const client = ClientProfile(
    id: 'test-client',
    companyName: 'Dupont Construction SA',
    companyType: 'Construction company',
    email: 'contact@dupont.ch',
    phone: '+41 21 123 45 67',
    jobCount: 2,
  );

  for (final size in <Size>[
    const Size(320, 568),
    const Size(430, 932),
    const Size(800, 1180),
  ]) {
    testWidgets('Create Job form renders at ${size.width}x${size.height}', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const MaterialApp(home: CreateJobScreen(initialClient: client)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Create Job'), findsOneWidget);
      expect(find.text('Dupont Construction SA'), findsOneWidget);
      expect(find.byKey(const Key('create-job-scroll')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('AI voice opens the recording popup without a fake success', (
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
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('create-with-ai-voice-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(AiVoiceFlowDialog), findsOneWidget);
    expect(find.text('Record Deposit Details'), findsOneWidget);
    await tester.tap(find.byKey(const Key('voice-cancel')));
    await tester.pumpAndSettle();
    expect(recorder.cancels, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('date field opens an actual date picker', (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(home: CreateJobScreen(initialClient: client)),
    );
    await tester.pumpAndSettle();
    final date = find.byKey(const Key('job-start-date'));
    await tester.ensureVisible(date);
    await tester.pumpAndSettle();
    await tester.tap(date);
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
