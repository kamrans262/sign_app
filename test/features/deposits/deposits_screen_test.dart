import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/core/widgets/sign2digital_bottom_navigation_bar.dart';
import 'package:sign2digital/core/widgets/sign2digital_dashboard_header.dart';
import 'package:sign2digital/features/clients/presentation/screens/clients_screen.dart';
import 'package:sign2digital/features/clients/presentation/widgets/sign2digital_status_badge.dart';
import 'package:sign2digital/features/deposits/data/demo_deposit_repository.dart';
import 'package:sign2digital/features/deposits/domain/deposit_record.dart';
import 'package:sign2digital/features/deposits/presentation/screens/deposits_screen.dart';

class _StubRepository implements DepositRepository {
  _StubRepository(this.records, {this.fail = false});
  final List<DepositRecord> records;
  bool fail;
  @override
  Future<List<DepositRecord>> listDeposits() async {
    if (fail) { throw StateError('offline'); }
    return records;
  }
}

DepositRecord _example(
  String id, DepositStatus status, double amount, DateTime date, {
  String title = 'Riverside Villa', String clientName = 'Jean Dupont',
}) => DepositRecord(
  id: id, title: title, clientName: clientName,
  amount: amount, date: date, status: status,
);

void main() {
  test('Demo records are typed, distinct and explicitly local samples',
      () async {
    final records = await const DemoDepositRepository().listDeposits();
    expect(records.length, 4);
    expect(records.map((entry) => entry.id).toSet().length, 4);
    expect(records.every((entry) => entry.demoOnly), isTrue);
    expect(records.every((entry) =>
      entry.status == DepositStatus.received), isTrue);
    expect(records.first.formattedAmount, 'CHF 78.80');
    expect(records.first.matches('JEAN'), isTrue);
    expect(records.first.matches('riverside'), isTrue);
    expect(records.first.matches('missing'), isFalse);
  });

  testWidgets('More opens Deposits with the existing global controls',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ClientsScreen()));
    await tester.tap(find.byKey(const Key('dashboard-tab-4')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-deposits')));
    await tester.pumpAndSettle();
    expect(find.byType(DepositsScreen), findsOneWidget);
    expect(find.byType(Sign2DigitalDashboardHeader), findsWidgets);
    expect(find.text('Search documents'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget);
    expect(find.text('Refunded'), findsOneWidget);
    expect(tester.widget<Sign2DigitalBottomNavigationBar>(
      find.byType(Sign2DigitalBottomNavigationBar).last).selectedIndex, 4);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Status, search and numeric/date sorting work together',
      (tester) async {
    final repository = _StubRepository([
      _example('older', DepositStatus.received, 9, DateTime(2025)),
      _example('newer', DepositStatus.pending, 101, DateTime(2026),
        clientName: 'Luis'),
      _example('middle', DepositStatus.received, 35, DateTime(2025, 8)),
      _example('refunded', DepositStatus.refunded, 12, DateTime(2024)),
    ]);
    await tester.pumpWidget(MaterialApp(home: DepositsScreen(
      repository: repository)));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('deposit-card-newer')), findsOneWidget);
    expect(find.text('Date (newest)'), findsOneWidget);
    await tester.tap(find.byKey(const Key('details-tab-2')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('deposit-card-newer')), findsNothing);
    expect(find.byKey(const Key('deposit-card-middle')), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('clients-search-input')), 'jean');
    await tester.pump();
    expect(find.byKey(const Key('deposit-card-older')), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('clients-search-input')), '');
    await tester.pump();
    await tester.tap(find.byKey(const Key('deposits-sort')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('deposit-sort-highest')));
    await tester.pumpAndSettle();
    expect(find.text('Amount (highest)'), findsOneWidget);
    expect(tester.getTopLeft(find.byKey(const Key('deposit-card-middle'))).dy,
      lessThan(tester.getTopLeft(find.byKey(
        const Key('deposit-card-older'))).dy));
    await tester.tap(find.byKey(const Key('details-tab-0')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('deposit-card-newer')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Bank icon, Received badge, cost and centered chevron reuse card',
      (tester) async {
    DepositRecord? opened;
    await tester.pumpWidget(MaterialApp(home: DepositsScreen(
      onDepositTap: (record) => opened = record,
    )));
    await tester.pumpAndSettle();
    final first = find.byKey(const Key('deposit-card-demo-deposit-1'));
    expect(first, findsOneWidget);
    expect(find.byKey(const Key('deposit-amount-demo-deposit-1')),
      findsOneWidget);
    final badge = find.descendant(of: first,
      matching: find.byType(Sign2DigitalStatusBadge));
    expect(tester.widget<Sign2DigitalStatusBadge>(badge).status, 'Received');
    expect(find.descendant(of: first, matching: find.byIcon(
      Icons.account_balance_outlined)), findsOneWidget);
    final arrow = find.descendant(of: first,
      matching: find.byIcon(Icons.chevron_right_rounded));
    expect((tester.getCenter(arrow).dy - tester.getCenter(first).dy).abs(),
      lessThan(4));
    await tester.tap(first);
    await tester.pump();
    expect(opened?.id, 'demo-deposit-1');
    expect(tester.takeException(), isNull);
  });

  testWidgets('FAB delegates creation; missing flows show honest messages',
      (tester) async {
    var createCalls = 0;
    await tester.pumpWidget(MaterialApp(home: DepositsScreen(
      onCreateDeposit: () => createCalls++,
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('deposits-create')));
    await tester.pump();
    expect(createCalls, 1);
    await tester.pumpWidget(const MaterialApp(home: DepositsScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('deposits-create')));
    await tester.pump();
    expect(find.text('Deposit creation is not connected yet.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Repository errors retry; empty status has no fake deposits',
      (tester) async {
    final stub = _StubRepository([], fail: true);
    await tester.pumpWidget(MaterialApp(home: DepositsScreen(
      repository: stub)));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('deposits-retry')), findsOneWidget);
    stub.fail = false;
    await tester.tap(find.byKey(const Key('deposits-retry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('deposits-empty')), findsOneWidget);
    expect(find.byKey(const Key('deposit-card-demo-deposit-1')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final size in [
    const Size(320, 650), const Size(375, 667),
    const Size(390, 844), const Size(430, 932),
    const Size(600, 900), const Size(768, 1024),
    const Size(1024, 768), const Size(720, 390),
  ]) {
    testWidgets('Responsive deposit list, fixed nav and FAB at $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(home: DepositsScreen()));
      await tester.pumpAndSettle();
      final scroll = find.byKey(const Key('deposits-scroll'));
      final nav = find.byType(Sign2DigitalBottomNavigationBar);
      final fab = find.byKey(const Key('deposits-create'));
      expect(tester.getBottomRight(scroll).dy,
        lessThanOrEqualTo(tester.getTopLeft(nav).dy + 1));
      expect(tester.getBottomRight(fab).dy,
        lessThanOrEqualTo(tester.getTopLeft(nav).dy + 1));
      await tester.scrollUntilVisible(
        find.byKey(const Key('deposit-card-demo-deposit-4')), 130,
        scrollable: find.descendant(of: scroll,
          matching: find.byType(Scrollable)).first);
      expect(tester.takeException(), isNull, reason: '$size');
    });
  }
}
