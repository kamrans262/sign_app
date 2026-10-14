import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/features/jobs/data/local_job_photo_source.dart';
import 'package:sign2digital/features/jobs/services/voice_recorder_service.dart';
import 'package:sign2digital/features/labour/data/demo_labour_repository.dart';
import 'package:sign2digital/features/deposits/data/demo_deposit_repository.dart';
import 'package:sign2digital/features/deposits/domain/deposit_record.dart';
import 'package:sign2digital/features/deposits/presentation/screens/add_deposit_screen.dart';
import 'package:sign2digital/features/deposits/services/deposit_voice_extraction_service.dart';

class _Photos implements JobPhotoSource {
  final bytes = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/SqsAAAAASUVORK5CYII=');

  @override
  Future<List<LocalJobPhotoSelection>> upload() async => [
    LocalJobPhotoSelection(name: 'test.png', bytes: bytes, sourceKey: 'photo-1'),
  ];

  @override
  Future<LocalJobPhotoSelection?> camera() async => null;
}

class _Recorder implements VoiceRecorderService {
  bool started = false;
  bool disposed = false;
  @override
  Stream<double> get amplitude => const Stream<double>.empty();
  @override
  Future<void> start() async { started = true; }
  @override
  Future<void> pause() async {}
  @override
  Future<void> resume() async {}
  @override
  Future<String> save() async => 'mock-recording.m4a';
  @override
  Future<void> cancel() async {}
  @override
  Future<void> dispose() async { disposed = true; }
}

class _Extraction implements DepositVoiceExtractionService {
  final future = Completer<DepositVoiceSuggestion>();
  String? path;
  String? key;

  @override
  Future<DepositVoiceSuggestion> extract(String audioPath, String temporaryKey) {
    path = audioPath;
    key = temporaryKey;
    return future.future;
  }
}

Future<void> _show(WidgetTester tester, AddDepositScreen screen) async {
  await tester.pumpWidget(MaterialApp(home: Scaffold(
    body: Builder(builder: (context) => TextButton(
      onPressed: () => Navigator.of(context).push<void>(
        MaterialPageRoute<void>(builder: (_) => screen)),
      child: const Text('Open form'),
    )),
  )));
  await tester.tap(find.text('Open form'));
  await tester.pumpAndSettle();
}

Future<void> _reach(WidgetTester tester, String key) async {
  await tester.scrollUntilVisible(
    find.byKey(Key(key)),
    key == 'deposit-form-client' || key == 'deposit-form-job'
        ? -150 : 130,
    scrollable: find.descendant(
      of: find.byKey(const Key('deposit-entry-form-scroll')),
      matching: find.byType(Scrollable),
    ).first,
  );
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

Future<void> _enter(WidgetTester tester, String key, String value) async {
  await _reach(tester, key);
  await tester.enterText(find.descendant(
    of: find.byKey(Key(key)),
    matching: find.byType(EditableText),
  ), value);
  await tester.pump();
}

void main() {
  setUp(DemoDepositRepository.clearLocalDeposits);

  test('AI extracts only supported values and rejects invalid data', () {
    final valid = DepositVoiceSuggestion.fromJson({
      'jobReference': 'JOB-L-001',
      'clientName': 'Jean Dupont',
      'amount': 98.25,
      'depositDate': '2026-08-25',
      'paymentMethod': 'Bank transfer',
      'referenceNumber': 'A-0005',
      'notes': 'Deposit for renovation',
    });
    expect(valid.clientName, 'Jean Dupont');
    expect(valid.amount, 98.25);
    expect(valid.depositDate, DateTime(2026, 8, 25));
    expect(valid.paymentMethod, 'Bank transfer');
    expect(valid.hasSuggestions, isTrue);
    final invalid = DepositVoiceSuggestion.fromJson({
      'amount': -1,
      'depositDate': '2026-02-30',
      'paymentMethod': '',
    });
    expect(invalid.amount, isNull);
    expect(invalid.depositDate, isNull);
    expect(invalid.hasSuggestions, isFalse);
  });

  testWidgets('Create Deposit has fields, validates and returns typed draft',
      (tester) async {
    DepositRecord? saved;
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: Builder(builder: (context) => TextButton(
        onPressed: () async {
          saved = await Navigator.of(context).push<DepositRecord>(
            MaterialPageRoute<DepositRecord>(
              builder: (_) => AddDepositScreen(
                jobs: [LabourDemoJobs.riverside],
                datePicker: (_, _) async => DateTime(2026, 8, 25),
              ),
            ),
          );
        },
        child: const Text('Open form'),
      )),
    )));
    await tester.tap(find.text('Open form'));
    await tester.pumpAndSettle();
    expect(find.text('Deposits'), findsOneWidget);
    expect(find.text('Create with AI Voice'), findsOneWidget);
    await _reach(tester, 'deposit-form-save');
    await tester.tap(find.byKey(const Key('deposit-form-save')));
    await tester.pump();
    expect(find.byKey(const Key('deposit-form-error')), findsOneWidget);
    expect(saved, isNull);

    await _reach(tester, 'deposit-form-job');
    await tester.tap(find.byKey(const Key('deposit-form-job')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(
      const Key('deposit-select-job-labour-demo-riverside')));
    await tester.pumpAndSettle();
    await _enter(tester, 'deposit-form-client', 'Jean Dupont');
    await _enter(tester, 'deposit-form-amount', 'CHF 98.00');
    await _reach(tester, 'deposit-form-date');
    await tester.tap(find.byKey(const Key('deposit-form-date')));
    await tester.pumpAndSettle();
    await _enter(tester, 'deposit-form-method', 'Bank transfer');
    await _enter(tester, 'deposit-form-reference', 'A-0005');
    await _enter(tester, 'deposit-form-notes', 'Terrace deposit');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await _reach(tester, 'deposit-form-save');
    await tester.tap(find.byKey(const Key('deposit-form-save')));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.title, 'Riverside Villa');
    expect(saved!.clientName, 'Jean Dupont');
    expect(saved!.amount, 98);
    expect(saved!.date, DateTime(2026, 8, 25));
    expect(saved!.status, DepositStatus.pending);
    expect(saved!.jobId, 'labour-demo-riverside');
    expect(saved!.paymentMethod, 'Bank transfer');
    expect(saved!.referenceNumber, 'A-0005');
    expect(saved!.notes, 'Terrace deposit');
    await const DemoDepositRepository().saveDeposit(saved!);
    expect((await const DemoDepositRepository().listDeposits()).length, 5);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Image picker uses shared tiles and photo removal',
      (tester) async {
    await _show(tester, AddDepositScreen(
      jobs: [LabourDemoJobs.riverside], photoSource: _Photos(),
    ));
    await _reach(tester, 'deposit-add-photo');
    await tester.tap(find.byKey(const Key('deposit-add-photo')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('deposit-choose-gallery')));
    await tester.pumpAndSettle();
    final photo = find.byKey(const Key('deposit-photo-0'));
    expect(photo, findsOneWidget);
    await tester.tap(find.descendant(of: photo,
      matching: find.byTooltip('Remove photo preview')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('deposit-photo-0')), findsNothing);
    expect(find.byKey(const Key('deposit-add-photo')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Shared microphone processing fills deposit-specific fields',
      (tester) async {
    final recorder = _Recorder();
    final extraction = _Extraction();
    await _show(tester, AddDepositScreen(
      jobs: [LabourDemoJobs.riverside],
      voiceRecorderFactory: () => recorder,
      voiceExtractionService: extraction,
      requestTemporaryApiKey: (_) async => 'temporary-test-key',
    ));
    await tester.tap(find.byKey(const Key('create-with-ai-voice-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Record Deposit Details'), findsOneWidget);
    expect(recorder.started, isTrue);
    await tester.tap(find.byKey(const Key('voice-save')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('AI is Processing your Voice'), findsOneWidget);
    extraction.future.complete(const DepositVoiceSuggestion(
      clientName: 'Jean Dupont', amount: 98,
      paymentMethod: 'Bank transfer', referenceNumber: 'A-0005',
    ));
    await tester.pumpAndSettle();
    expect(extraction.path, 'mock-recording.m4a');
    expect(extraction.key, 'temporary-test-key');
    await _reach(tester, 'deposit-form-client');
    expect(find.text('Jean Dupont'), findsOneWidget);
    await _reach(tester, 'deposit-form-amount');
    expect(find.text('98.00'), findsOneWidget);
    expect(recorder.disposed, isTrue);
    expect(tester.takeException(), isNull);
  });

  for (final size in [
    const Size(320, 568), const Size(390, 844),
    const Size(768, 1024), const Size(1024, 768),
  ]) {
    testWidgets('Deposit fields and save are reachable at $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _show(tester, AddDepositScreen(
        jobs: [LabourDemoJobs.riverside],
      ));
      await _reach(tester, 'deposit-form-save');
      expect(find.byKey(const Key('deposit-form-save')), findsOneWidget);
      expect(tester.takeException(), isNull, reason: '$size');
    });
  }
}
