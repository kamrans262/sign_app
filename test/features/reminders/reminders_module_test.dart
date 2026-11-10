import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/core/widgets/sign2digital_entry_list_card.dart';
import 'package:sign2digital/core/widgets/sign2digital_input_field.dart';
import 'package:sign2digital/features/clients/presentation/screens/more_screen.dart';
import 'package:sign2digital/features/reminders/data/demo_reminder_repository.dart';
import 'package:sign2digital/features/reminders/data/remote_reminder_repository.dart';
import 'package:sign2digital/features/reminders/domain/reminder_record.dart';
import 'package:sign2digital/features/reminders/presentation/screens/add_reminder_screen.dart';
import 'package:sign2digital/features/reminders/presentation/screens/reminders_screen.dart';
import 'package:sign2digital/features/reminders/services/reminder_voice_extraction_service.dart';
import 'package:sign2digital/features/jobs/presentation/widgets/ai_voice_flow_dialog.dart';

import '../../support/fake_voice_services.dart';

class _Repository implements ReminderRepository {
  _Repository(this.records);
  final List<ReminderRecord> records;

  @override
  Future<List<ReminderRecord>> listReminders() async => [...records];

  @override
  Future<ReminderRecord> saveReminder(ReminderRecord entry) async {
    records.add(entry);
    return entry;
  }

  @override
  Future<ReminderRecord> updateReminder(ReminderRecord entry) async {
    final index = records.indexWhere((old) => old.id == entry.id);
    if (index < 0) throw StateError('Unknown reminder');
    records[index] = entry;
    return entry;
  }

  @override
  Future<ReminderRecord> setCompleted(String id, bool completed) async {
    final index = records.indexWhere((e) => e.id == id);
    if (index < 0) throw StateError('Unknown reminder');
    final item = records[index].copyWith(
      completedAt: completed ? DateTime.now() : null,
      clearCompleted: !completed);
    records[index] = item;
    return item;
  }
}

class _References implements ReminderReferenceSource {
  @override
  Future<List<ReminderRelatedItem>> listForType(ReminderType type) async =>
    type == ReminderType.invoice ? [
      const ReminderRelatedItem(
        id: 'invoice-1', title: 'INV-2026-88',
        project: 'Roadside Villa', type: ReminderType.invoice),
    ] : [];
}

class _FakeReminderVoice implements ReminderVoiceExtractionService {
  _FakeReminderVoice(this.onExtract);
  final Future<ReminderVoiceSuggestion> Function() onExtract;

  @override
  Future<ReminderVoiceSuggestion> extract(String _) => onExtract();
}

Future<void> _reach(WidgetTester tester, String key, {bool up = false}) async {
  final finder = find.byKey(Key(key));
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(finder, up ? -180 : 180,
      scrollable: find.byType(Scrollable).first);
  } else {
    await tester.ensureVisible(finder);
  }
  await tester.pumpAndSettle();
}

void main() {
  setUp(DemoReminderRepository.resetForTests);

  test('M20 signed-in reminder screens use the real Laravel repository by default', () {
    final selected = RemindersScreen.repositoryForSession(true);
    expect(selected, isA<RemoteReminderRepository>());
    expect(selected, isNot(isA<DemoReminderRepository>()));

    final preview = RemindersScreen.repositoryForSession(false);
    expect(preview, isA<DemoReminderRepository>());

    const injected = DemoReminderRepository();
    expect(RemindersScreen.repositoryForSession(true, injected), same(injected));
  });


  test('Reminder status and JSON extraction do not invent data', () {
    final now = DateTime(2026, 10, 15, 12);
    final original = ReminderRecord(
      id: 'r', title: 'Site Visit', type: ReminderType.job,
      remindAt: now.add(const Duration(hours: 1)));
    expect(original.filterAt(now), ReminderFilter.upcoming);
    expect(original.copyWith(
      remindAt: now.subtract(const Duration(hours: 1)))
        .filterAt(now), ReminderFilter.overdue);
    expect(original.copyWith(completedAt: now).filterAt(now),
        ReminderFilter.completed);

    final voice = ReminderVoiceSuggestion.fromJson({
      'title': 'Check the invoice', 'type': 'Invoice',
      'reminderDate': '2026-02-31', 'reminderTime': '25:70',
    });
    expect(voice.title, 'Check the invoice');
    expect(voice.type, ReminderType.invoice);
    expect(voice.date, isNull);
    expect(voice.time, isNull);
    expect(ReminderVoiceSuggestion.fromJson({}).hasData, isFalse);
  });

  test('Demo repository saves, edits and completes reminders locally', () async {
    const source = DemoReminderRepository();
    final reminder = ReminderRecord(
      id: 'user-test-1', title: 'Check materials',
      type: ReminderType.other,
      remindAt: DateTime(2026, 11, 1, 13),
      sendNotification: false);
    await source.saveReminder(reminder);
    expect((await source.listReminders()).last.title, 'Check materials');
    final edited = await source.updateReminder(
      reminder.copyWith(title: 'Updated material check'));
    expect(edited.sendNotification, isFalse);
    final complete = await source.setCompleted(reminder.id, true);
    expect(complete.completed, isTrue);
    expect((await source.listReminders()).last.completed, isTrue);
    await expectLater(source.saveReminder(reminder), throwsStateError);
  });

  testWidgets('More opens Reminders; listing filters and searches', (tester) async {
    final now = DateTime(2026, 10, 15, 12);
    final records = _Repository([
      ReminderRecord(
        id: 'up-1', title: 'Client Meeting',
        type: ReminderType.client,
        remindAt: now.add(const Duration(hours: 7))),
      ReminderRecord(
        id: 'late-1', title: 'Submit Invoice',
        type: ReminderType.invoice,
        remindAt: now.subtract(const Duration(days: 2))),
      ReminderRecord(
        id: 'done-1', title: 'Site Review',
        type: ReminderType.job,
        remindAt: now.subtract(const Duration(days: 1)),
        completedAt: now),
    ]);
    await tester.pumpWidget(MaterialApp(home: RemindersScreen(
      repository: records, now: () => now)));
    await tester.pumpAndSettle();

    // SliverList builds only on-screen cards at a given viewport size.
    expect(find.byType(Sign2DigitalEntryListCard), findsWidgets);
    expect(find.byKey(const Key('reminders-add')), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(tester.getSize(find.byKey(const Key('reminders-add'))),
        const Size(50, 50));
    expect(find.text('Add Reminder'), findsNothing);
    await tester.tap(find.byKey(const Key('details-tab-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('reminder-card-up-1')), findsOneWidget);
    expect(find.byKey(const Key('reminder-card-late-1')), findsNothing);
    await tester.tap(find.byKey(const Key('details-tab-2')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('reminder-card-late-1')), findsOneWidget);
    await tester.tap(find.byKey(const Key('details-tab-3')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('reminder-card-done-1')), findsOneWidget);
    await tester.tap(find.byKey(const Key('details-tab-0')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('clients-search-input')), 'client');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('reminder-card-up-1')), findsOneWidget);
    expect(find.byKey(const Key('reminder-card-late-1')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('More section provides the Reminders route', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MoreScreen()));
    await tester.scrollUntilVisible(
      find.byKey(const Key('open-reminders')), 150);
    await tester.tap(find.byKey(const Key('open-reminders')));
    await tester.pumpAndSettle();
    expect(find.byType(RemindersScreen), findsOneWidget);
  });

  testWidgets('Reminder form validates and saves selected fields and toggle',
      (tester) async {
    ReminderRecord? saved;
    final date = DateTime(2026, 10, 25);
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () async {
            saved = await Navigator.of(context).push<ReminderRecord>(
              MaterialPageRoute(builder: (_) => AddReminderScreen(
                referenceSource: _References(),
                datePicker: (_, __) async => date,
                timePicker: (_, __) async =>
                    const TimeOfDay(hour: 19, minute: 30))));
          },
          child: const Text('Open')),
      )),
    ));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await _reach(tester, 'reminder-save');
    await tester.tap(find.byKey(const Key('reminder-save')));
    await tester.pumpAndSettle();
    await _reach(tester, 'reminder-form-error');
    expect(find.textContaining('Enter a title'), findsOneWidget);

    await _reach(tester, 'reminder-title', up: true);
    await tester.enterText(find.byType(TextFormField).first, 'Send invoice');
    await tester.tap(find.byKey(const Key('reminder-type')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('reminder-type-invoice')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('reminder-related')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('reminder-related-invoice-1')));
    await tester.pumpAndSettle();
    await _reach(tester, 'reminder-date');
    await tester.tap(find.byKey(const Key('reminder-date')));
    await tester.pumpAndSettle();
    await _reach(tester, 'reminder-time');
    await tester.tap(find.byKey(const Key('reminder-time')));
    await tester.pumpAndSettle();
    await _reach(tester, 'reminder-notification-setting');
    await tester.tap(find.byKey(const Key('reminder-notification-toggle')));
    await tester.pumpAndSettle();
    await _reach(tester, 'reminder-save');
    await tester.tap(find.byKey(const Key('reminder-save')));
    await tester.pumpAndSettle();
    expect(saved?.title, 'Send invoice');
    expect(saved?.type, ReminderType.invoice);
    expect(saved?.relatedItem?.id, 'invoice-1');
    expect(saved?.remindAt, DateTime(2026, 10, 25, 19, 30));
    expect(saved?.sendNotification, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Existing voice popup records, cancels and retains form', (tester) async {
    final recorder = FakeVoiceRecorder();
    await tester.pumpWidget(MaterialApp(home: AddReminderScreen(
      voiceRecorderFactory: () => recorder,
      voiceExtractionService: _FakeReminderVoice(() async =>
        const ReminderVoiceSuggestion(title: 'Call client')),
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('create-with-ai-voice-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(AiVoiceFlowDialog), findsOneWidget);
    expect(find.text('Record Reminder Details'), findsOneWidget);
    expect(find.byKey(const Key('reminder-voice-api-key')), findsNothing);
    await tester.tap(find.byKey(const Key('voice-cancel')));
    await tester.pumpAndSettle();
    expect(recorder.cancels, 1);
    expect(find.byType(AiVoiceFlowDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AI processing applies approved suggestion and preserves entries',
      (tester) async {
    final recorder = FakeVoiceRecorder();
    await tester.pumpWidget(MaterialApp(home: AddReminderScreen(
      voiceRecorderFactory: () => recorder,
      voiceExtractionService: _FakeReminderVoice(() async =>
        const ReminderVoiceSuggestion(
          title: 'Call client', type: ReminderType.client,
          time: TimeOfDay(hour: 17, minute: 0))),
    )));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Manual title');
    await tester.tap(find.byKey(const Key('create-with-ai-voice-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    await tester.tap(find.byKey(const Key('voice-save')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Use extracted reminder details?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('reminder-voice-apply')));
    await tester.pumpAndSettle();
    final field = tester.widget<Sign2DigitalInputField>(
      find.byKey(const Key('reminder-title')));
    expect(field.controller.text, 'Manual title');
    expect(recorder.disposed, isTrue);
    expect(tester.takeException(), isNull);
  });

  for (final size in [
    const Size(320, 568), const Size(390, 844),
    const Size(768, 1024),
  ]) {
    testWidgets('Reminders listing and form have no overflow at $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(home: RemindersScreen()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const Key('reminders-add')));
      await tester.pumpAndSettle();
      expect(find.byType(AddReminderScreen), findsOneWidget);
      await _reach(tester, 'reminder-save');
      expect(tester.takeException(), isNull, reason: '$size');
    });
  }
}
