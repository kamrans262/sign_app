import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/core/widgets/sign2digital_entry_list_card.dart';
import 'package:sign2digital/features/equipment/data/demo_equipment_repository.dart';
import 'package:sign2digital/features/equipment/domain/equipment_record.dart';
import 'package:sign2digital/features/equipment/services/equipment_voice_extraction_service.dart';
import 'package:sign2digital/features/equipment/presentation/screens/equipment_screen.dart';
import 'package:sign2digital/features/equipment/presentation/screens/add_equipment_screen.dart';
import 'package:sign2digital/features/equipment/presentation/screens/equipment_details_screen.dart';
import 'package:sign2digital/features/quotes/presentation/widgets/sign2digital_signature_action_card.dart';

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

  test('AI suggestions reject invented or malformed data', () {
    final suggestion = EquipmentVoiceSuggestion.fromJson({
      'name': 'Excavator',
      'equipmentId': 'EQ-0009',
      'purchaseDate': '2026-02-31',
      'status': 'In Use',
    });
    expect(suggestion.name, 'Excavator');
    expect(suggestion.status, EquipmentStatus.inUse);
    expect(suggestion.purchaseDate, isNull);
    expect(EquipmentVoiceSuggestion.fromJson({}).hasData, isFalse);
  });

  testWidgets('Listing reuses global header and filters actual status',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: EquipmentScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Search Equipment'), findsOneWidget);
    expect(find.byKey(const Key('equipment-card-EQP-0001')), findsOneWidget);
    // Equipment must use the same invoice/expense card and circular leading.
    expect(find.byType(Sign2DigitalEntryListCard), findsOneWidget);
    expect(find.byKey(const Key('equipment-leading-EQP-0001')), findsOneWidget);
    expect(find.byKey(const Key('equipment-create')), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
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

  testWidgets('Equipment custom name and category use Other and titled fields',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: AddEquipmentScreen(availableNames: ['Mini Excavator'])));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('equipment-form-name')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('equipment-custom-value')), findsNothing);
    expect(find.text('Other'), findsOneWidget);
    await tester.tap(find.byKey(const Key('equipment-custom-name')));
    await tester.pumpAndSettle();
    expect(find.text('Enter Equipment Name'), findsOneWidget);
    expect(find.text('Equipment Name'), findsOneWidget);
    await tester.enterText(find.descendant(
      of: find.byKey(const Key('equipment-custom-value')),
      matching: find.byType(TextFormField)), 'Hydraulic Lift');
    await tester.tap(find.text('Use'));
    await tester.pumpAndSettle();
    expect(find.text('Hydraulic Lift'), findsOneWidget);

    await tester.tap(find.byKey(const Key('equipment-form-category')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('equipment-custom-value')), findsNothing);
    await tester.tap(find.byKey(const Key('equipment-category-other')));
    await tester.pumpAndSettle();
    expect(find.text('Enter Category'), findsOneWidget);
    expect(find.text('Category'), findsWidgets);
    await tester.enterText(find.descendant(
      of: find.byKey(const Key('equipment-custom-value')),
      matching: find.byType(TextFormField)), 'Specialty Lifting');
    await tester.tap(find.text('Use'));
    await tester.pumpAndSettle();
    expect(find.text('Specialty Lifting'), findsOneWidget);
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
    // The name legitimately appears in summary and in the details table.
    expect(find.descendant(
      of: find.byKey(const Key('equipment-detail-summary')),
      matching: find.text('Mini Excavator'),
    ), findsOneWidget);
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

  testWidgets('Equipment detail uses four document-style action cards above tabs',
      (tester) async {
    final saved = EquipmentRecord(
      id: 'EX-100', name: 'Drill', category: 'Construction',
      brand: 'Bosch', model: '2004',
      purchaseDate: DateTime(2026, 11, 14),
      status: EquipmentStatus.inUse,
      serverId: 10, demoOnly: false,
    );
    await tester.pumpWidget(MaterialApp(
      home: EquipmentDetailsScreen(
        equipment: saved, repository: const DemoEquipmentRepository()),
    ));
    await tester.pumpAndSettle();
    final row = find.byKey(const Key('equipment-detail-actions'));
    expect(row, findsOneWidget);
    final cards = find.descendant(
      of: row, matching: find.byType(Sign2DigitalSignatureActionCard));
    expect(cards, findsNWidgets(4));
    for (final key in [
      'equipment-details-edit',
      'equipment-details-log-usage',
      'equipment-details-loan-history',
      'equipment-details-schedule',
    ]) {
      final card = tester.widget<Sign2DigitalSignatureActionCard>(
        find.byKey(Key(key)));
      expect(card.documentStyling, isTrue);
      expect(card.selected, isFalse);
    }
    expect(tester.getTopLeft(row).dy,
      greaterThan(tester.getBottomLeft(
        find.byKey(const Key('equipment-detail-summary'))).dy));
    expect(tester.getBottomLeft(row).dy,
      lessThan(tester.getTopLeft(
        find.byKey(const Key('details-tab-0'))).dy));
    expect(tester.takeException(), isNull);
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
