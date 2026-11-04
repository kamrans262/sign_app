import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/core/widgets/sign2digital_primary_button.dart';
import 'package:sign2digital/core/widgets/sign2digital_outlined_button.dart';
import 'package:sign2digital/features/jobs/data/local_job_photo_source.dart';
import 'package:sign2digital/features/labour/data/demo_labour_repository.dart';
import 'package:sign2digital/features/labour/domain/labour_entry.dart';
import 'package:sign2digital/features/labour/presentation/screens/labour_entry_details_screen.dart';

LabourEntry _entry({
  String id = 'local-labour-test',
  LabourEntryStatus status = LabourEntryStatus.pending,
  double? rate = 85,
  List<LocalJobPhotoSelection> photos = const [],
  List<LabourHistoryEvent> history = const [],
}) => LabourEntry(
  id: id,
  kind: LabourEntryKind.labour,
  workerName: 'Alex Martin',
  role: 'Electrician',
  jobId: LabourDemoJobs.riverside.id,
  jobName: LabourDemoJobs.riverside.title,
  date: DateTime(2026, 8, 14),
  startMinutes: 8 * 60,
  endMinutes: 16 * 60,
  hours: 8,
  hourlyRate: rate,
  photos: photos,
  history: history,
  status: status,
);

Future<void> _show(WidgetTester tester, LabourEntry entry,
    {LabourRepository? repository}) async {
  await tester.pumpWidget(MaterialApp(
    home: LabourEntryDetailsScreen(
      entry: entry, repository: repository),
  ));
  // Bounded frames avoid waiting for unrelated ongoing UI activity.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _reveal(WidgetTester tester, String key) async {
  await tester.scrollUntilVisible(
    find.byKey(Key(key)),
    170,
    scrollable: find.descendant(
      of: find.byKey(const Key('labour-detail-scroll')),
      matching: find.byType(Scrollable),
    ).first,
  );
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.pump();
}

void main() {
  setUp(DemoLabourRepository.clearLocalEntries);

  testWidgets('Details use saved cost, job copy and real approval fields',
      (tester) async {
    final entry = _entry(status: LabourEntryStatus.approved);
    String? clipboardText;
    final messenger=TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if(call.method=='Clipboard.setData') {
        clipboardText=(call.arguments as Map)['text'] as String?;
        return null;
      }
      if(call.method=='Clipboard.getData') {
        return {'text':clipboardText};
      }
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(
      SystemChannels.platform,null));
    await _show(tester, entry);
    expect(find.text('Alex Martin'), findsOneWidget);
    expect(find.text('8.00 hours'), findsOneWidget);
    expect(find.text('Total: CHF 680.00'), findsOneWidget);
    expect(find.byKey(const Key('labour-detail-table')), findsOneWidget);
    expect(find.text('Approved by'), findsNothing);
    expect(find.text('Approved Date'), findsNothing);
    await _reveal(tester, 'information-row-copy');
    await tester.tap(find.byKey(const Key('information-row-copy')));
    await tester.pump();
    final data = await Clipboard.getData('text/plain');
    expect(data?.text, 'Riverside Villa');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Photos and history use real data, not placeholders',
      (tester) async {
    final bytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/SqsAAAAASUVORK5CYII=');
    final photo = LocalJobPhotoSelection(
      name: 'photo.png', bytes: bytes, sourceKey: 'photo-test');
    final event = LabourHistoryEvent(
      id: 'real-event',
      title: 'Labour entry created',
      occurredAt: DateTime(2026, 8, 14, 9, 20),
      actorName: 'Alex Martin',
    );
    await _show(tester, _entry(photos: [photo], history: [event]));
    await tester.tap(find.byKey(const Key('details-tab-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('labour-detail-photo-0')), findsOneWidget);
    await tester.tap(find.byKey(const Key('labour-detail-photo-0')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('labour-photo-full-preview')), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('details-tab-2')));
    await tester.pumpAndSettle();
    expect(find.text('Labour entry created'), findsOneWidget);
    expect(find.textContaining('Alex Martin'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Empty photos and history do not fabricate information',
      (tester) async {
    await _show(tester, _entry());
    await tester.tap(find.byKey(const Key('details-tab-1')));
    await tester.pump();
    expect(find.byKey(const Key('labour-detail-photos-empty')), findsOneWidget);
    await tester.tap(find.byKey(const Key('details-tab-2')));
    await tester.pump();
    expect(find.byKey(const Key('labour-detail-history-empty')), findsOneWidget);
  });

  testWidgets('Protected approved records cannot be edited or deleted',
      (tester) async {
    final repo = const DemoLabourRepository();
    await _show(tester, _entry(status: LabourEntryStatus.approved),
      repository: repo);
    await _reveal(tester, 'labour-detail-edit');
    expect(tester.widget<Sign2DigitalPrimaryButton>(
      find.byKey(const Key('labour-detail-edit'))).enabled,isFalse);
    expect(tester.widget<Sign2DigitalOutlinedButton>(
      find.byKey(const Key('labour-detail-delete'))).enabled,isFalse);
    await tester.tap(find.byKey(const Key('labour-detail-delete')));
    await tester.pump();
    expect(find.byKey(const Key('labour-confirm-delete')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Delete confirms first and refreshes repository after success',
      (tester) async {
    final repository = const DemoLabourRepository();
    final entry = _entry(id: 'local-delete-test');
    await repository.save(entry);
    await _show(tester, entry, repository: repository);
    await _reveal(tester, 'labour-detail-delete');
    await tester.tap(find.byKey(const Key('labour-detail-delete')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('labour-confirm-delete')), findsOneWidget);
    await tester.tap(find.text('Cancel').last);
    await tester.pumpAndSettle();
    expect((await repository.list()).any((e) => e.id == entry.id), isTrue);
    await tester.tap(find.byKey(const Key('labour-detail-delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('labour-confirm-delete')));
    await tester.pumpAndSettle();
    expect((await repository.list()).any((e) => e.id == entry.id), isFalse);
  });

  testWidgets('Edit form is prefilled and updates same entry id',
      (tester) async {
    final repository = const DemoLabourRepository();
    final entry = _entry(id: 'local-edit-test');
    await repository.save(entry);
    await _show(tester, entry, repository: repository);
    await _reveal(tester, 'labour-detail-edit');
    await tester.tap(find.byKey(const Key('labour-detail-edit')));
    await tester.pumpAndSettle();
    final scroll = find.descendant(
      of: find.byKey(const Key('labour-entry-form-scroll')),
      matching: find.byType(Scrollable),
    ).first;
    await tester.scrollUntilVisible(
      find.byKey(const Key('labour-form-worker')), -120,
      scrollable: scroll,
    );
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('labour-form-worker')),
        matching: find.byType(EditableText),
      ), 'Taylor Reed');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('labour-form-save')), 150,
      scrollable: scroll,
    );
    await tester.ensureVisible(find.byKey(const Key('labour-form-save')));
    expect(find.text('Save Changes'), findsOneWidget);
    await tester.tap(find.byKey(const Key('labour-form-save')));
    await tester.pumpAndSettle();
    final records = (await repository.list())
      .where((e) => e.id == entry.id).toList();
    expect(records.length, 1);
    expect(records.single.workerName, 'Taylor Reed');
    expect(records.single.history.length, 2);
    // The editor leaves the details list scrolled near its bottom; rebuild
    // the lazily rendered worker header before asserting the visible name.
    await tester.scrollUntilVisible(
      find.byKey(const Key('labour-detail-worker')), -220,
      scrollable: find.descendant(
        of: find.byKey(const Key('labour-detail-scroll')),
        matching: find.byType(Scrollable),
      ).first,
    );
    await tester.pump();
    expect(find.byKey(const Key('labour-detail-name')), findsOneWidget);
    expect(find.text('Taylor Reed'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final size in [
    const Size(320, 568), const Size(390, 844),
    const Size(768, 1024), const Size(1024, 768),
  ]) {
    testWidgets('Details and buttons remain reachable at $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _show(tester, _entry());
      await _reveal(tester, 'labour-detail-edit');
      expect(find.byKey(const Key('labour-detail-delete')), findsOneWidget);
      expect(find.byKey(const Key('labour-detail-edit')), findsOneWidget);
      expect(tester.takeException(), isNull, reason: '$size');
    });
  }
}
