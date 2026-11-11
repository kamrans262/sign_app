import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:sign2digital/core/theme/app_colors.dart';
import 'package:sign2digital/features/jobs/data/mock_jobs.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/features/expenses/domain/expense_record.dart';
import 'package:sign2digital/features/expenses/presentation/screens/add_expense_screen.dart';
import 'package:sign2digital/features/expenses/services/expense_voice_extraction_service.dart';
import 'package:sign2digital/features/jobs/data/local_job_photo_source.dart';
import 'package:sign2digital/core/widgets/sign2digital_bottom_navigation_bar.dart';

class _Photos implements JobPhotoSource {
  @override
  Future<LocalJobPhotoSelection?> camera() async => null;
  @override
  Future<List<LocalJobPhotoSelection>> upload() async => [
    for (var i = 0; i < 3; i++)
      LocalJobPhotoSelection(
        name: 'receipt-$i.png',
        bytes: Uint8List.fromList(
          [0x89,0x50,0x4e,0x47,0x0d,0x0a,0x1a,0x0a]),
        sourceKey: 'receipt-$i',
      ),
  ];
}

void main() {
  test('Expense voice suggestions parse only recognized fields', () {
    final input = ExpenseVoiceSuggestion.fromJson({
      'jobReference':'JOB-A-001', 'expenseType':'Fuel',
      'date':'2026-08-25', 'amount':98.0,
      'description':'Refuel on site',
      'tags':['Transport', 'Transport','Site Visit'],
    });
    expect(input.category, ExpenseCategory.fuel);
    expect(input.date, DateTime(2026,8,25));
    expect(input.amount, 98);
    expect(input.tags, ['Transport','Site Visit']);
    expect(ExpenseVoiceSuggestion.fromJson({
      'expenseType':'Not a category', 'amount':-5, 'date':'2026-99-88',
    }).amount, isNull);
  });

  testWidgets('Create Expense uses the header, fields, reusable voice and nav',
      (tester) async {
    tester.view.physicalSize = const Size(430,932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: AddExpenseScreen()));
    expect(find.text('Expenses'), findsOneWidget);
    expect(find.text('Create with AI Voice'), findsOneWidget);
    for (final field in ['Job','Expense Type','Date','Amount',
      'Description','Tags']) {
      expect(find.textContaining(field), findsWidgets);
    }
    expect(find.byKey(const Key('expense-add-photo')), findsOneWidget);
    expect(find.byKey(const Key('expense-cancel')), findsOneWidget);
    expect(find.byKey(const Key('expense-save-draft')), findsOneWidget);
    expect(tester.widget<Sign2DigitalBottomNavigationBar>(
      find.byType(Sign2DigitalBottomNavigationBar)).selectedIndex, 4);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Expense job search owns controller until sheet reverse animation ends',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: AddExpenseScreen()));
    await tester.tap(find.byKey(const Key('expense-add-job')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('expense-job-search')), findsOneWidget);
    expect(tester.takeException(), isNull);

    final field = tester.widget<TextField>(
      find.byKey(const Key('expense-job-search')));
    expect(field.style?.color, AppColors.dark);
    expect(field.decoration?.hintStyle?.color, AppColors.dark);

    await tester.enterText(find.byKey(const Key('expense-job-search')),
      'no-job-has-this-name');
    await tester.pump();
    expect(find.text('No matching jobs'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('expense-job-search')), '');
    await tester.pump();
    await tester.tap(find.byKey(Key('expense-job-${MockJobsData.jobs.first.id}')));
    // The route result completes before the reverse transition disposes
    // its still-mounted TextField. It must never see a disposed controller.
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(milliseconds: 80));
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('expense-job-search')), findsNothing);
    expect(tester.takeException(), isNull);

    // Closing without choosing a job follows the same safe lifecycle.
    await tester.tap(find.byKey(const Key('expense-add-job')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('selection-sheet-close')));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Empty upload is full width, three receipts appear with Add Photo',
      (tester) async {
    await tester.pumpWidget(MaterialApp(home: AddExpenseScreen(
      photoSource: _Photos(),
    )));
    final add = find.byKey(const Key('expense-add-photo'));
    final grid = find.byKey(const Key('expense-photo-grid'));
    await tester.ensureVisible(add);
    expect(tester.getSize(add).width,
      closeTo(tester.getSize(grid).width, 1));
    await tester.tap(add);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('expense-choose-gallery')));
    await tester.pump();
    for (var i=0;i<3;i++) {
      expect(find.byKey(Key('expense-photo-$i')), findsOneWidget);
    }
    expect(add, findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('expense-photo-1')));
    await tester.tap(find.descendant(
      of: find.byKey(const Key('expense-photo-1')),
      matching: find.byType(IconButton)));
    await tester.pump();
    expect(find.byKey(const Key('expense-photo-2')), findsNothing);
    expect(find.byKey(const Key('expense-photo-1')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Tags are deduplicated, removable and wrap',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AddExpenseScreen()));
    await tester.ensureVisible(find.byKey(const Key('expense-tag-input')));
    await tester.enterText(find.byKey(const Key('expense-tag-input')),
      'Transport,Site Visit,Transport');
    await tester.pump();
    expect(find.byKey(const Key('expense-tag-Transport')), findsOneWidget);
    expect(find.byKey(const Key('expense-tag-Site Visit')), findsOneWidget);
    // InputChip deletion uses the framework's delete affordance, whose
    // icon may differ across Flutter versions. Verify its callback instead.
    tester.widget<InputChip>(
      find.byKey(const Key('expense-tag-Transport')),
    ).onDeleted?.call();
    await tester.pump();
    expect(find.byKey(const Key('expense-tag-Transport')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final size in [
    const Size(320,568), const Size(375,667), const Size(390,844),
    const Size(430,932), const Size(600,950), const Size(768,1024),
    const Size(1024,768), const Size(720,390),
  ]) {
    testWidgets('Responsive Create Expense and reachable Save at $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(home: AddExpenseScreen()));
      final scroll = find.byKey(const Key('create-expense-scroll'));
      final nav = find.byType(Sign2DigitalBottomNavigationBar);
      expect(tester.getBottomRight(scroll).dy,
        lessThanOrEqualTo(tester.getTopLeft(nav).dy + 1));
      await tester.ensureVisible(find.byKey(const Key('expense-save-draft')));
      await tester.pump();
      expect(find.byKey(const Key('expense-add-photo')), findsOneWidget);
      expect(tester.takeException(), isNull, reason: '$size');
    });
  }
}
