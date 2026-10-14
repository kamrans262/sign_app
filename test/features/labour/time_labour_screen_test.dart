import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/core/widgets/sign2digital_bottom_navigation_bar.dart';
import 'package:sign2digital/core/widgets/sign2digital_dashboard_header.dart';
import 'package:sign2digital/features/clients/presentation/screens/clients_screen.dart';
import 'package:sign2digital/features/clients/presentation/widgets/sign2digital_status_badge.dart';
import 'package:sign2digital/features/labour/data/demo_labour_repository.dart';
import 'package:sign2digital/features/labour/domain/labour_entry.dart';
import 'package:sign2digital/features/labour/presentation/screens/time_labour_screen.dart';
import 'package:sign2digital/features/labour/presentation/screens/labour_entry_details_screen.dart';
import 'package:sign2digital/features/labour/presentation/screens/add_labour_entry_screen.dart';
import 'package:sign2digital/features/jobs/domain/job_model.dart';

class _Stub implements LabourRepository {
  _Stub(this.entries, this.available);
  final List<LabourEntry> entries;
  final List<JobModel> available;
  bool fail = false;
  @override
  Future<List<LabourEntry>> list() async {
    if (fail) throw StateError('offline');
    return entries;
  }
  @override
  Future<List<JobModel>> jobs() async => available;
  @override
  Future<void> save(LabourEntry entry) async => entries.add(entry);
}

LabourEntry record(String id, {LabourEntryKind kind=LabourEntryKind.labour,
    LabourEntryStatus status=LabourEntryStatus.pending,
    double hours=6, String name='Alex Martin',
    DateTime? date, String? jobId}) => LabourEntry(
  id: id, kind: kind, workerName: name, role: 'electrician',
  jobId: jobId ?? LabourDemoJobs.riverside.id,
  jobName: 'Riverside Villa',
  date: date ?? DateTime(2026,8,23),
  hours: hours, status: status,
);

Future<void> _scrollToEntryField(WidgetTester tester, String key) async {
  await tester.scrollUntilVisible(
    find.byKey(Key(key)),
    key == 'labour-form-worker' ? -120 : 120,
    scrollable: find.descendant(
      of: find.byKey(const Key('labour-entry-form-scroll')),
      matching: find.byType(Scrollable),
    ).first,
  );
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

void main() {
  setUp(DemoLabourRepository.clearLocalEntries);

  test('Demo Labour and Time Sheet records differ and have unique IDs',
      () async {
    final entries = await const DemoLabourRepository().list();
    expect(entries.length, 6);
    expect(entries.map((e)=>e.id).toSet().length, entries.length);
    expect(entries.where((e)=>e.kind==LabourEntryKind.labour).length, 4);
    expect(entries.where((e)=>e.kind==LabourEntryKind.timeSheet).length, 2);
    expect(entries.first.initials, 'AM');
    expect(entries.first.formattedHours, '6.00h');
    expect(entries[1].statusLabel, 'Pending');
  });

  testWidgets('More opens Time & Labour with existing global components',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ClientsScreen()));
    await tester.tap(find.byKey(const Key('dashboard-tab-4')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-time-labour')));
    await tester.pumpAndSettle();
    expect(find.byType(TimeLabourScreen), findsOneWidget);
    expect(find.byType(Sign2DigitalDashboardHeader), findsWidgets);
    expect(find.text('Search documents'), findsOneWidget);
    expect(find.text('Labour'), findsOneWidget);
    expect(find.text('Time Sheet'), findsOneWidget);
    expect(tester.widget<Sign2DigitalBottomNavigationBar>(
      find.byType(Sign2DigitalBottomNavigationBar).last).selectedIndex, 4);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Labour/Time Sheet tabs filter different records',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: TimeLabourScreen()));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('labour-card-labour-demo-1')),
      findsOneWidget);
    expect(find.text('Alex Martin'), findsWidgets);
    await tester.tap(find.byKey(const Key('details-tab-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('labour-card-timesheet-demo-1')),
      findsOneWidget);
    expect(find.text('Sophie Laurent'), findsOneWidget);
    expect(find.byKey(const Key('labour-card-labour-demo-1')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Search and job selection combine without losing selected tab',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: TimeLabourScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('details-tab-1')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('clients-search-input')),
      'Sophie');
    await tester.pump();
    expect(find.byKey(const Key('labour-card-timesheet-demo-1')),
      findsOneWidget);
    expect(find.byKey(const Key('labour-card-timesheet-demo-2')),
      findsNothing);
    await tester.tap(find.byKey(const Key('labour-job-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('labour-job-all')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('labour-card-timesheet-demo-1')),
      findsOneWidget);
    await tester.enterText(find.byKey(const Key('clients-search-input')), '');
    await tester.pump();
    expect(find.byKey(const Key('labour-card-timesheet-demo-2')),
      findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Sort hours numerically and card goes to correct record',
      (tester) async {
    final stub = _Stub([
      record('low', hours: 3),
      record('high', hours: 12, name:'Jordan Lee'),
      record('middle', hours: 9, name: 'Alex Martin'),
    ], [LabourDemoJobs.riverside]);
    await tester.pumpWidget(MaterialApp(home: TimeLabourScreen(repository: stub)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('labour-sort')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('labour-sort-mostHours')));
    await tester.pumpAndSettle();
    expect(find.text('Hours (highest)'), findsOneWidget);
    final high = find.byKey(const Key('labour-card-high'));
    final middle = find.byKey(const Key('labour-card-middle'));
    expect(tester.getTopLeft(high).dy, lessThan(tester.getTopLeft(middle).dy));
    await tester.tap(high);
    await tester.pumpAndSettle();
    expect(find.byType(LabourEntryDetailsScreen), findsOneWidget);
    expect(find.text('Jordan Lee'), findsWidgets);
    expect(find.text('12.00h'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Card shows hours, global badge and centered arrow',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: TimeLabourScreen()));
    await tester.pumpAndSettle();
    final card = find.byKey(const Key('labour-card-labour-demo-1'));
    expect(card, findsOneWidget);
    expect(find.descendant(of: card,
      matching: find.byType(Sign2DigitalStatusBadge)), findsOneWidget);
    expect(find.descendant(of: card,
      matching: find.text('6.00h')), findsOneWidget);
    final arrow = find.descendant(of: card,
      matching: find.byIcon(Icons.chevron_right_rounded));
    expect((tester.getCenter(arrow).dy - tester.getCenter(card).dy).abs(),
      lessThan(5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('FAB opens the shared Create Labour form and validates inputs',
      (tester) async {
    final stub = _Stub([], [LabourDemoJobs.riverside]);
    await tester.pumpWidget(MaterialApp(home: TimeLabourScreen(repository: stub)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('details-tab-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('labour-create')));
    await tester.pumpAndSettle();
    expect(find.byType(AddLabourEntryScreen), findsOneWidget);
    expect(find.text('Create with AI Voice'), findsOneWidget);
    await _scrollToEntryField(tester, 'labour-form-save');
    await tester.tap(find.byKey(const Key('labour-form-save')));
    await tester.pump();
    expect(find.byKey(const Key('labour-form-error')), findsOneWidget);
    expect(stub.entries, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Empty and error/retry do not invent records',
      (tester) async {
    final stub = _Stub([], [LabourDemoJobs.riverside])..fail=true;
    await tester.pumpWidget(MaterialApp(home: TimeLabourScreen(repository: stub)));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('labour-retry')), findsOneWidget);
    stub.fail=false;
    await tester.tap(find.byKey(const Key('labour-retry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('labour-empty')), findsOneWidget);
    expect(find.text('Alex Martin'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final size in [
    const Size(320,568), const Size(430,932), const Size(768,1024),
  ]) {
    testWidgets('Add Entry fields and save reachable at $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(home: AddLabourEntryScreen(
        kind: LabourEntryKind.labour,
        jobs: [LabourDemoJobs.riverside],
        initialJob: LabourDemoJobs.riverside,
      )));
      await _scrollToEntryField(tester, 'labour-form-rate');
      expect(find.byKey(const Key('labour-form-rate')), findsOneWidget);
      await _scrollToEntryField(tester, 'labour-form-save');
      expect(find.byKey(const Key('labour-form-save')), findsOneWidget);
      expect(tester.takeException(), isNull, reason: '$size');
    });
  }

  for (final size in [
    const Size(320,650), const Size(375,667),
    const Size(390,844), const Size(430,932),
    const Size(600,900), const Size(768,1024),
    const Size(1024,768), const Size(720,390),
  ]) {
    testWidgets('Labour full screen no overflow and FAB accessible $size',
        (tester) async {
      tester.view.physicalSize=size;
      tester.view.devicePixelRatio=1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(home: TimeLabourScreen()));
      await tester.pumpAndSettle();
      final nav=find.byType(Sign2DigitalBottomNavigationBar);
      final fab=find.byKey(const Key('labour-create'));
      expect(tester.getBottomRight(fab).dy,
        lessThanOrEqualTo(tester.getTopLeft(nav).dy+1));
      await tester.scrollUntilVisible(
        find.byKey(const Key('labour-card-labour-demo-4')), 100,
        scrollable: find.descendant(
          of: find.byKey(const Key('labour-scroll')),
          matching: find.byType(Scrollable)).first);
      expect(tester.takeException(), isNull, reason: '$size');
    });
  }
}
