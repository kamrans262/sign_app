import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/features/equipment/data/demo_equipment_repository.dart';
import 'package:sign2digital/features/equipment/domain/equipment_record.dart';
import 'package:sign2digital/features/equipment/presentation/screens/equipment_screen.dart';
import 'package:sign2digital/features/equipment/presentation/screens/add_equipment_screen.dart';
import 'package:sign2digital/features/equipment/presentation/screens/equipment_details_screen.dart';

void main() {
  setUp(DemoEquipmentRepository.resetForTests);

  test('Saving, usage, edits and maintenance use one equipment record', () async {
    const repository = DemoEquipmentRepository();
    final date = DateTime(2026, 8, 25);
    final original = EquipmentRecord(
      id: 'EQP-NEW', name: 'Loader', category: 'Earthmoving',
      brand: 'Kubota', model: 'R520', purchaseDate: date,
      status: EquipmentStatus.available);
    final saved = await repository.saveEquipment(original);
    expect(saved.history.single.title, 'Equipment created');
    expect((await repository.listEquipment()).length, 2);
    final edited = await repository.updateEquipment(
      saved.copyWith(status: EquipmentStatus.inUse));
    expect(edited.status, EquipmentStatus.inUse);
    final used = await repository.logUsage(saved.id,
      EquipmentUsage(id: 'usage-1', date: date, hours: 2.5, job: 'Site A'));
    expect(used.hours, 2.5);
    final maintained = await repository.scheduleMaintenance(saved.id,
      EquipmentMaintenance(
        id: 'maintenance-1', date: date,
        description: 'Inspect hydraulics'));
    expect(maintained.maintenance.single.description, 'Inspect hydraulics');
    expect(maintained.hours, 2.5);
    expect(maintained.history.length, 4);
    await expectLater(repository.saveEquipment(original), throwsStateError);
  });

  testWidgets('Listing reuses global header and filters actual status',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: EquipmentScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Search Equipment'), findsOneWidget);
    expect(find.byKey(const Key('equipment-card-EQP-0001')), findsOneWidget);
    await tester.tap(find.byKey(const Key('details-tab-2')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('equipment-empty')), findsOneWidget);
    await tester.tap(find.byKey(const Key('details-tab-0')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('clients-search-input')), 'nonexistent');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('equipment-empty')), findsOneWidget);
  });

  testWidgets('Add equipment validates required fields and opens AI button',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: AddEquipmentScreen(availableNames: ['Mini Excavator'])));
    await tester.pumpAndSettle();
    expect(find.text('Equipment'), findsOneWidget);
    expect(find.text('Create with AI Voice'), findsOneWidget);
    final scroll = find.byKey(const Key('equipment-form-scroll'));
    await tester.scrollUntilVisible(
      find.byKey(const Key('equipment-form-save')), 130,
      scrollable: find.descendant(of: scroll,
        matching: find.byType(Scrollable)).first);
    await tester.tap(find.byKey(const Key('equipment-form-save')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('equipment-form-error')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Equipment Details shows saved fields and four tabs',
      (tester) async {
    const repository = DemoEquipmentRepository();
    final equipment = (await repository.listEquipment()).first;
    await tester.pumpWidget(MaterialApp(
      home: EquipmentDetailsScreen(
        equipment: equipment, repository: repository)));
    await tester.pumpAndSettle();
    expect(find.text('Mini Excavator'), findsOneWidget);
    expect(find.byKey(const Key('equipment-details-table')), findsOneWidget);
    await tester.tap(find.byKey(const Key('details-tab-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('equipment-usage-empty')), findsOneWidget);
    await tester.tap(find.byKey(const Key('details-tab-2')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('equipment-maintenance-empty')), findsOneWidget);
    await tester.tap(find.byKey(const Key('details-tab-3')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('equipment-history-empty')), findsOneWidget);
  });

  for (final size in [
    const Size(320, 568), const Size(390, 844),
    const Size(768, 1024),
  ]) {
    testWidgets('Equipment listing fits screen $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(home: EquipmentScreen()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$size');
    });
  }
}
