import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/features/jobs/data/local_job_photo_source.dart';
import 'package:sign2digital/features/jobs/services/voice_recorder_service.dart';
import 'package:sign2digital/features/labour/data/demo_labour_repository.dart';
import 'package:sign2digital/features/labour/domain/labour_entry.dart';
import 'package:sign2digital/features/labour/presentation/screens/add_labour_entry_screen.dart';
import 'package:sign2digital/features/labour/services/labour_voice_extraction_service.dart';

class _Photos implements JobPhotoSource {
  final data = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/SqsAAAAASUVORK5CYII=');
  @override
  Future<List<LocalJobPhotoSelection>> upload() async => [
    LocalJobPhotoSelection(name: 'test.png', bytes: data, sourceKey: 'photo1'),
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

class _Extraction implements LabourVoiceExtractionService {
  final future = Completer<LabourVoiceSuggestion>();
  String? path;
  String? key;
  @override
  Future<LabourVoiceSuggestion> extract(String audioPath, String temporaryKey) {
    path = audioPath;
    key = temporaryKey;
    return future.future;
  }
}

Future<void> _show(WidgetTester tester, AddLabourEntryScreen screen) async {
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
    key == 'labour-form-worker' ? -150 : 130,
    scrollable: find.descendant(
      of: find.byKey(const Key('labour-entry-form-scroll')),
      matching: find.byType(Scrollable),
    ).first,
  );
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

void main() {
  test('Overnight duration, zero duration and voice suggestions', () {
    expect(LabourTimeRange.durationMinutes(22 * 60, 6 * 60), 480);
    expect(LabourTimeRange.display(480), '8:00 hours');
    expect(LabourTimeRange.durationMinutes(600, 600), 0);
    expect(LabourTimeRange.durationMinutes(600, 660), 60);
    final suggestion = LabourVoiceSuggestion.fromJson({
      'worker': 'Marc Dupont',
      'startTime': '22:30',
      'endTime': '06:00',
      'hourlyRate': 85,
      'date': '2026-08-25',
      'description': 'Tile the terrace',
    });
    expect(suggestion.worker, 'Marc Dupont');
    expect(suggestion.startMinutes, 1350);
    expect(suggestion.endMinutes, 360);
    expect(suggestion.hourlyRate, 85);
    expect(suggestion.date, DateTime(2026, 8, 25));
    final uncertain = LabourVoiceSuggestion.fromJson({
      'startTime': '25:70', 'date': '2026-02-30',
      'hourlyRate': -5,
    });
    expect(uncertain.startMinutes, isNull);
    expect(uncertain.date, isNull);
    expect(uncertain.hourlyRate, isNull);
    expect(uncertain.hasSuggestions, isFalse);
  });

  testWidgets('Create Labour form computes night hours and returns full entry',
      (tester) async {
    LabourEntry? saved;
    final times = [const TimeOfDay(hour: 22, minute: 0),
                   const TimeOfDay(hour: 6, minute: 0)];
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: Builder(builder: (context) => TextButton(
        onPressed: () async {
          saved = await Navigator.of(context).push<LabourEntry>(
            MaterialPageRoute<LabourEntry>(builder: (_) => AddLabourEntryScreen(
              kind: LabourEntryKind.labour,
              jobs: [LabourDemoJobs.riverside],
              initialJob: LabourDemoJobs.riverside,
              datePicker: (_, _) async => DateTime(2026, 8, 25),
              timePicker: (_, _) async => times.removeAt(0),
            )),
          );
        },
        child: const Text('Open form'),
      )),
    )));
    await tester.tap(find.text('Open form'));
    await tester.pumpAndSettle();

    expect(find.text('Create with AI Voice'), findsOneWidget);
    await _reach(tester, 'labour-form-date');
    await tester.tap(find.byKey(const Key('labour-form-date')));
    await tester.pumpAndSettle();
    await _reach(tester, 'labour-form-start');
    await tester.tap(find.byKey(const Key('labour-form-start')));
    await tester.pumpAndSettle();
    await _reach(tester, 'labour-form-end');
    await tester.tap(find.byKey(const Key('labour-form-end')));
    await tester.pumpAndSettle();
    expect(find.text('8:00 hours'), findsOneWidget);

    await _reach(tester, 'labour-form-worker');
    await tester.enterText(find.byType(EditableText).first, 'Taylor Reed');
    await _reach(tester, 'labour-form-role');
    await tester.enterText(find.byType(EditableText).last, 'Electrician');
    await _reach(tester, 'labour-form-rate');
    await tester.enterText(find.byType(EditableText).last, '85.00');
    await _reach(tester, 'labour-form-task');
    await tester.enterText(find.byType(EditableText).last, 'Renovate terrace');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();

    await _reach(tester, 'labour-form-save');
    await tester.tap(find.byKey(const Key('labour-form-save')));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.workerName, 'Taylor Reed');
    expect(saved!.role, 'Electrician');
    expect(saved!.startMinutes, 1320);
    expect(saved!.endMinutes, 360);
    expect(saved!.hours, 8);
    expect(saved!.hourlyRate, 85);
    expect(saved!.task, 'Renovate terrace');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Photo selection reuses upload and removes only selected photo',
      (tester) async {
    await _show(tester, AddLabourEntryScreen(
      kind: LabourEntryKind.labour,
      jobs: [LabourDemoJobs.riverside],
      photoSource: _Photos(),
    ));
    await _reach(tester, 'labour-add-photo');
    await tester.tap(find.byKey(const Key('labour-add-photo')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('labour-choose-gallery')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('labour-photo-0')), findsOneWidget);
    final photo = find.byKey(const Key('labour-photo-0'));
    await tester.tap(find.descendant(of: photo,
      matching: find.byTooltip('Remove photo preview')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('labour-photo-0')), findsNothing);
    expect(find.byKey(const Key('labour-add-photo')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Shared microphone and processing popup fill only spoken values',
      (tester) async {
    final recorder = _Recorder();
    final extraction = _Extraction();
    await _show(tester, AddLabourEntryScreen(
      kind: LabourEntryKind.labour,
      jobs: [LabourDemoJobs.riverside],
      voiceRecorderFactory: () => recorder,
      voiceExtractionService: extraction,
      requestTemporaryApiKey: (_) async => 'temporary-test-key',
    ));
    await tester.tap(find.byKey(const Key('create-with-ai-voice-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Record labour Details'), findsOneWidget);
    expect(recorder.started, isTrue);
    await tester.tap(find.byKey(const Key('voice-save')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('AI is Processing your Voice'), findsOneWidget);
    extraction.future.complete(const LabourVoiceSuggestion(
      worker: 'Marc Dupont', labourType: 'Electrician', hourlyRate: 85,
    ));
    await tester.pumpAndSettle();
    expect(extraction.path, 'mock-recording.m4a');
    expect(extraction.key, 'temporary-test-key');
    expect(find.text('Record labour Details'), findsNothing);
    await _reach(tester, 'labour-form-worker');
    expect(find.text('Marc Dupont'), findsOneWidget);
    await _reach(tester, 'labour-form-rate');
    expect(find.text('85.00'), findsOneWidget);
    expect(recorder.disposed, isTrue);
    expect(tester.takeException(), isNull);
  });

  for (final size in [
    const Size(320, 568), const Size(390, 844),
    const Size(768, 1024), const Size(1024, 768),
  ]) {
    testWidgets('Create Labour fields remain scrollable at $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _show(tester, AddLabourEntryScreen(
        kind: LabourEntryKind.labour,
        jobs: [LabourDemoJobs.riverside],
      ));
      await _reach(tester, 'labour-form-save');
      expect(find.byKey(const Key('labour-form-save')), findsOneWidget);
      expect(tester.takeException(), isNull, reason: '$size');
    });
  }
}
