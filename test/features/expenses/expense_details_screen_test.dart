import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/core/widgets/sign2digital_information_table.dart';
import 'package:sign2digital/core/widgets/sign2digital_primary_button.dart';
import 'package:sign2digital/features/clients/presentation/widgets/sign2digital_status_badge.dart';
import 'package:sign2digital/features/expenses/data/demo_expense_repository.dart';
import 'package:sign2digital/features/expenses/domain/expense_record.dart';
import 'package:sign2digital/features/expenses/presentation/screens/expense_details_screen.dart';
import 'package:sign2digital/features/expenses/presentation/screens/add_expense_screen.dart';
import 'package:sign2digital/features/expenses/presentation/screens/receipt_screen.dart';
import 'package:sign2digital/features/clients/presentation/widgets/sign2digital_details_tabs.dart';
import 'package:sign2digital/features/jobs/data/local_job_photo_source.dart';

final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJ'
  'AAAADUlEQVQIHWP4z8DwHwAFgAI/ScL/nwAAAABJRU5ErkJggg==',
);

ExpenseRecord expense({
  ExpenseStatus status = ExpenseStatus.approved,
  List<LocalJobPhotoSelection> photos = const [],
  List<ExpenseHistoryEvent> history = const [],
}) => ExpenseRecord(
  id: 'expense-1',
  title: 'Fuel',
  category: ExpenseCategory.fuel,
  job: 'Kitchen renovation',
  report: 'Site report',
  amount: 78.80,
  date: DateTime(2026, 8, 23, 22),
  status: status,
  clientName: 'Jean Dupont',
  approvedBy: status == ExpenseStatus.approved ? 'Jean Dupont' : null,
  approvedAt: status == ExpenseStatus.approved
      ? DateTime(2026, 8, 23) : null,
  updatedAt: DateTime(2026, 8, 23),
  photos: photos,
  history: history,
);

void main() {
  setUp(DemoExpenseRepository.clearDrafts);

  testWidgets('Expense Details matches the selected expense and shared table',
      (tester) async {
    await tester.pumpWidget(MaterialApp(home: ExpenseDetailsScreen(
      expense: expense(),
    )));
    expect(find.text('Expenses'), findsOneWidget);
    expect(find.byKey(const Key('expense-detail-summary')), findsOneWidget);
    expect(find.text('Fuel'), findsWidgets);
    expect(find.text('Kitchen renovation, Site report'), findsOneWidget);
    expect(find.text('CHF 78.80'), findsWidgets);
    expect(find.text('23 August 2026  10:00 PM'), findsOneWidget);
    expect(find.byType(Sign2DigitalInformationTable), findsOneWidget);
    expect(find.text('Approved'), findsNWidgets(2));
    expect(find.text('Approved By:'), findsOneWidget);
    expect(find.text('Approved Date:'), findsOneWidget);
    expect(find.text('Valid Until:'), findsNothing);
    expect(find.byKey(const Key('expense-edit')), findsOneWidget);
    expect(find.byKey(const Key('expense-request-reimburse')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Status and amount are consistent for To Review and Reimbursed',
      (tester) async {
    for (final status in [
      ExpenseStatus.toReview, ExpenseStatus.reimbursed,
    ]) {
      await tester.pumpWidget(MaterialApp(home: ExpenseDetailsScreen(
        expense: expense(status: status),
      )));
      expect(find.byType(Sign2DigitalStatusBadge), findsNWidgets(2));
      expect(find.text(status.label), findsNWidgets(2));
      expect(find.text('CHF 78.80'), findsWidgets);
      expect(find.text('Approved By:'), findsNothing);
      final action = tester.widget<Sign2DigitalPrimaryButton>(
        find.byKey(const Key('expense-request-reimburse')));
      expect(action.enabled, isFalse);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('Receipt tab opens page with all attachments and restores tab',
      (tester) async {
    final pictures = [
      for (var i = 0; i < 3; i++)
        LocalJobPhotoSelection(
          name: 'receipt-$i.png',
          bytes: Uint8List.fromList(_png),
          sourceKey: 'receipt-$i',
        ),
    ];
    await tester.pumpWidget(MaterialApp(home: ExpenseDetailsScreen(
      expense: expense(photos: pictures),
    )));
    await tester.tap(find.byKey(const Key('details-tab-1')));
    await tester.pumpAndSettle();
    expect(find.byType(ReceiptScreen), findsOneWidget);
    for (var i = 0; i < pictures.length; i++) {
      expect(find.byKey(Key('receipt-thumbnail-$i')), findsOneWidget);
    }
    expect(find.byKey(const Key('receipt-preview-image')), findsOneWidget);
    await tester.tap(find.byKey(const Key('receipt-thumbnail-1')));
    await tester.pump();
    expect(find.byKey(const Key('receipt-preview-image')), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(ExpenseDetailsScreen), findsOneWidget);
    expect(tester.widget<Sign2DigitalDetailsTabs>(
      find.byType(Sign2DigitalDetailsTabs)).selectedIndex, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Empty Receipt page offers actual upload workflow',
      (tester) async {
    await tester.pumpWidget(MaterialApp(home: ExpenseDetailsScreen(
      expense: expense(),
    )));
    await tester.tap(find.byKey(const Key('details-tab-1')));
    await tester.pumpAndSettle();
    expect(find.byType(ReceiptScreen), findsOneWidget);
    expect(find.byKey(const Key('receipt-preview-empty')), findsOneWidget);
    expect(find.byKey(const Key('receipt-add-photo')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('receipt-add-photo')));
    await tester.tap(find.byKey(const Key('receipt-add-photo')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('receipt-pick-gallery')), findsOneWidget);
    expect(find.byKey(const Key('receipt-pick-camera')), findsOneWidget);
    expect(find.byKey(const Key('receipt-pick-pdf')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Only recorded history events appear, chronologically',
      (tester) async {
    await tester.pumpWidget(MaterialApp(home: ExpenseDetailsScreen(
      expense: expense(history: [
        ExpenseHistoryEvent(id: 'created', title: 'Expense Created',
          occurredAt: DateTime(2026, 8, 23, 9)),
        ExpenseHistoryEvent(id: 'updated', title: 'Expense Updated',
          occurredAt: DateTime(2026, 8, 24, 10),
          description: 'Saved locally'),
      ]),
    )));
    await tester.tap(find.byKey(const Key('details-tab-2')));
    await tester.pumpAndSettle();
    expect(find.text('Expense Updated'), findsOneWidget);
    expect(find.text('Expense Created'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Expense Updated')).dy,
      lessThan(tester.getTopLeft(find.text('Expense Created')).dy));
    expect(find.text('Expense Approved'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('No history does not invent an approval audit trail',
      (tester) async {
    await tester.pumpWidget(MaterialApp(home: ExpenseDetailsScreen(
      expense: expense(),
    )));
    await tester.tap(find.byKey(const Key('details-tab-2')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('expense-history-empty')), findsOneWidget);
  });

  testWidgets('Reimbursement is never marked sent without service',
      (tester) async {
    await tester.pumpWidget(MaterialApp(home: ExpenseDetailsScreen(
      expense: expense(),
    )));
    await tester.ensureVisible(
      find.byKey(const Key('expense-request-reimburse')));
    await tester.tap(find.byKey(const Key('expense-request-reimburse')));
    await tester.pump();
    expect(find.text('Reimbursement service is not connected yet.'),
      findsOneWidget);
    expect(find.text('Approved'), findsNWidgets(2));
  });

  testWidgets('Connected reimbursement response changes status only on success',
      (tester) async {
    var calls = 0;
    await tester.pumpWidget(MaterialApp(home: ExpenseDetailsScreen(
      expense: expense(),
      onRequestReimbursement: (current) async {
        calls++;
        return ExpenseRecord(
          id: current.id, category: current.category,
          title: current.title, job: current.job, report: current.report,
          amount: current.amount, date: current.date,
          status: ExpenseStatus.reimbursed,
          reimbursementRequested: true,
        );
      },
    )));
    await tester.ensureVisible(
      find.byKey(const Key('expense-request-reimburse')));
    await tester.tap(find.byKey(const Key('expense-request-reimburse')));
    await tester.pumpAndSettle();
    expect(calls, 0);
    await tester.tap(find.byKey(const Key('expense-confirm-reimburse')));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.text('Reimbursed'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Editing preserves selected record ID and updates existing demo',
      (tester) async {
    const repo = DemoExpenseRepository();
    final selected = (await repo.listExpenses()).first;
    await tester.pumpWidget(MaterialApp(home: ExpenseDetailsScreen(
      expense: selected, repository: repo,
    )));
    await tester.ensureVisible(find.byKey(const Key('expense-edit')));
    await tester.tap(find.byKey(const Key('expense-edit')));
    await tester.pumpAndSettle();
    expect(find.byType(AddExpenseScreen), findsOneWidget);
    final field = find.descendant(
      of: find.byKey(const Key('expense-add-amount')),
      matching: find.byType(TextFormField));
    await tester.enterText(field, '81.25');
    await tester.ensureVisible(find.byKey(const Key('expense-save-draft')));
    await tester.tap(find.byKey(const Key('expense-save-draft')));
    await tester.pumpAndSettle();
    expect(find.byType(ExpenseDetailsScreen), findsOneWidget);
    expect(find.text('CHF 81.25'), findsWidgets);
    final fromRepo = (await repo.listExpenses()).where(
      (record) => record.id == selected.id).toList();
    expect(fromRepo, hasLength(1));
    expect(fromRepo.single.amount, 81.25);
    expect(fromRepo.single.status, selected.status);
    expect(tester.takeException(), isNull);
  });

  for (final size in [
    const Size(320, 650), const Size(375, 667),
    const Size(390, 844), const Size(430, 932),
    const Size(600, 900), const Size(768, 1024),
    const Size(1024, 768), const Size(720, 390),
  ]) {
    testWidgets('Expense Details responsive tabs/table/buttons $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(home: ExpenseDetailsScreen(
        expense: expense(),
      )));
      expect(find.byKey(const Key('expense-detail-summary')), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('expense-edit')));
      await tester.pump();
      expect(find.byKey(const Key('expense-request-reimburse')), findsOneWidget);
      expect(tester.takeException(), isNull, reason: '$size');
    });
  }
}
