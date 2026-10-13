import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/core/widgets/sign2digital_bottom_navigation_bar.dart';
import 'package:sign2digital/core/widgets/sign2digital_dashboard_header.dart';
import 'package:sign2digital/features/clients/presentation/screens/clients_screen.dart';
import 'package:sign2digital/features/clients/presentation/widgets/sign2digital_status_badge.dart';
import 'package:sign2digital/features/expenses/data/demo_expense_repository.dart';
import 'package:sign2digital/features/expenses/domain/expense_record.dart';
import 'package:sign2digital/features/expenses/presentation/screens/expense_details_screen.dart';
import 'package:sign2digital/features/expenses/presentation/screens/expenses_screen.dart';

class _StubRepository implements ExpenseRepository {
  _StubRepository(this.records, {this.fail = false});
  final List<ExpenseRecord> records;
  bool fail;
  @override
  Future<List<ExpenseRecord>> listExpenses() async {
    if (fail) throw StateError('offline');
    return records;
  }
  @override
  Future<void> saveDraft(ExpenseRecord expense) async => records.add(expense);
}

ExpenseRecord example(String id, ExpenseStatus status, double amount,
    DateTime date, {String title = 'Fuel'}) => ExpenseRecord(
  id: id,
  category: ExpenseCategory.fuel,
  title: title,
  job: 'Kitchen renovation',
  report: 'Site report',
  amount: amount,
  date: date,
  status: status,
);

void main() {
  setUp(DemoExpenseRepository.clearDrafts);

  test('demo data is typed and has four unique expenses', () async {
    final demo = await const DemoExpenseRepository().listExpenses();
    expect(demo.map((x) => x.id).toSet().length, 4);
    expect(demo.map((x) => x.title).toList(),
      ['Fuel','Tools','Parking','Meals']);
    expect(demo[0].formattedAmount, 'CHF 78.80');
    expect(demo[1].status, ExpenseStatus.toReview);
    expect(demo[0].matches('kitchen'), isTrue);
    expect(demo[0].matches('no-match'), isFalse);
  });

  testWidgets('main dashboard More tab opens Expenses with reused widgets',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ClientsScreen()));
    await tester.tap(find.byKey(const Key('dashboard-tab-4')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-expenses')));
    await tester.pumpAndSettle();
    expect(find.byType(ExpensesScreen), findsOneWidget);
    expect(find.byType(Sign2DigitalDashboardHeader), findsWidgets);
    expect(find.text('Search documents'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    expect(find.text('To Review'), findsWidgets);
    expect(find.text('Approved'), findsWidgets);
    expect(find.text('Reimbursed'), findsOneWidget);
    expect(tester.widget<Sign2DigitalBottomNavigationBar>(
      find.byType(Sign2DigitalBottomNavigationBar).last).selectedIndex, 4);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tabs, search and sort combine with numeric amount/date ordering',
      (tester) async {
    final repository = _StubRepository([
      example('older', ExpenseStatus.approved, 9, DateTime(2025), title: 'Fuel'),
      example('newer', ExpenseStatus.toReview, 101, DateTime(2026), title: 'Tools'),
      example('middle', ExpenseStatus.approved, 35, DateTime(2025, 8), title: 'Meals'),
    ]);
    await tester.pumpWidget(MaterialApp(home: ExpensesScreen(
      repository: repository)));
    await tester.pumpAndSettle();
    expect(find.text('Date (newest)'), findsOneWidget);
    final scroll = find.byKey(const Key('expenses-scroll'));
    expect(find.byKey(const Key('expense-card-newer')), findsOneWidget);
    await tester.tap(find.byKey(const Key('details-tab-2')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('expense-card-newer')), findsNothing);
    expect(find.byKey(const Key('expense-card-older')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('clients-search-input')), 'Fuel');
    await tester.pump();
    expect(find.byKey(const Key('expense-card-middle')), findsNothing);
    await tester.tap(find.byKey(const Key('expenses-sort')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('expense-sort-highest')));
    await tester.pumpAndSettle();
    expect(find.text('Amount (highest)'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('clients-search-input')), '');
    await tester.pump();
    final middle = find.byKey(const Key('expense-card-middle'));
    final older = find.byKey(const Key('expense-card-older'));
    expect(tester.getTopLeft(middle).dy, lessThan(tester.getTopLeft(older).dy));
    await tester.tap(find.byKey(const Key('details-tab-0')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('expense-card-newer')), findsOneWidget);
    expect(scroll, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('card opens matching expense; amount, badge and arrow visible',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ExpensesScreen()));
    await tester.pumpAndSettle();
    final fuel = find.byKey(const Key('expense-card-demo-expense-1'));
    expect(fuel, findsOneWidget);
    expect(find.text('CHF 78.80'), findsNWidgets(4));
    final badge = find.descendant(of: fuel,
      matching: find.byType(Sign2DigitalStatusBadge));
    expect(tester.widget<Sign2DigitalStatusBadge>(badge).status, 'Approved');
    final icon = find.descendant(of: fuel, matching: find.byIcon(
      Icons.local_gas_station_outlined));
    expect(icon, findsOneWidget);
    final arrow = find.descendant(of: fuel,
      matching: find.byIcon(Icons.chevron_right_rounded));
    expect((tester.getCenter(arrow).dy - tester.getCenter(fuel).dy).abs(),
      lessThan(4));
    final fuelText = find.descendant(of: fuel, matching: find.text('Fuel'));
    expect(tester.getTopLeft(fuelText).dx,
      lessThan(tester.getTopLeft(badge).dx));

    await tester.tap(fuel);
    await tester.pumpAndSettle();
    expect(find.byType(ExpenseDetailsScreen), findsOneWidget);
    final details = tester.widget<ExpenseDetailsScreen>(
      find.byType(ExpenseDetailsScreen));
    expect(details.expense.id, 'demo-expense-1');
    expect(find.text('CHF 78.80'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('FAB creates local To Review draft, validation stays honest',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ExpensesScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('expenses-create')));
    await tester.pumpAndSettle();
    expect(find.text('Add Expense'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('expense-save-draft')));
    await tester.tap(find.byKey(const Key('expense-save-draft')));
    await tester.pump();
    expect(find.byKey(const Key('expense-add-error')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('expense-add-job')),
      'Kitchen renovation');
    await tester.enterText(find.byKey(const Key('expense-add-amount')),
      '12.50');
    await tester.ensureVisible(find.byKey(const Key('expense-save-draft')));
    await tester.tap(find.byKey(const Key('expense-save-draft')));
    await tester.pumpAndSettle();
    final all = await const DemoExpenseRepository().listExpenses();
    expect(all, hasLength(5));
    final draft = all.last;
    expect(draft.amount, 12.5);
    expect(draft.status, ExpenseStatus.toReview);
    expect(draft.demoOnly, isTrue);
    expect(find.byKey(Key('expense-card-${draft.id}')), findsOneWidget);
  });

  testWidgets('empty, failed/retry lists use repository, not fake items',
      (tester) async {
    final stub = _StubRepository([], fail: true);
    await tester.pumpWidget(MaterialApp(home: ExpensesScreen(
      repository: stub)));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('expenses-retry')), findsOneWidget);
    stub.fail = false;
    await tester.tap(find.byKey(const Key('expenses-retry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('expenses-empty')), findsOneWidget);
    expect(find.text('Fuel'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final size in [
    const Size(320, 650), const Size(375, 667),
    const Size(390, 844), const Size(430, 932),
    const Size(600, 900), const Size(768, 1024),
    const Size(1024, 768), const Size(720, 390),
  ]) {
    testWidgets('responsive no-overflow cards/tabs/FAB at $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(home: ExpensesScreen()));
      await tester.pumpAndSettle();
      final scroll = find.byKey(const Key('expenses-scroll'));
      final nav = find.byType(Sign2DigitalBottomNavigationBar);
      final fab = find.byKey(const Key('expenses-create'));
      expect(tester.getBottomRight(scroll).dy,
        lessThanOrEqualTo(tester.getTopLeft(nav).dy + 1));
      expect(tester.getBottomRight(fab).dy,
        lessThanOrEqualTo(tester.getTopLeft(nav).dy + 1));
      await tester.scrollUntilVisible(
        find.byKey(const Key('expense-card-demo-expense-4')), 130,
        scrollable: find.descendant(of: scroll,
          matching: find.byType(Scrollable)).first);
      expect(tester.takeException(), isNull, reason: '$size');
    });
  }
}
