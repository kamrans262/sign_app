import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/features/invoices/data/demo_invoice_repository.dart';
import 'package:sign2digital/features/invoices/domain/invoice_record.dart';
import 'package:sign2digital/features/invoices/presentation/screens/add_invoice_screen.dart';
import 'package:sign2digital/features/invoices/presentation/screens/invoice_details_screen.dart';
import 'package:sign2digital/features/invoices/presentation/screens/invoices_screen.dart';
import 'package:sign2digital/features/clients/presentation/screens/more_screen.dart';

InvoiceRecord _invoice(String id, InvoiceStatus status, double amount,
    DateTime date, {String? client, String? project}) => InvoiceRecord(
  id: id, number: 'INV-$id',
  project: project ?? 'Riverside Villa',
  clientName: client ?? 'John Smith',
  amount: amount, date: date, status: status,
);

class _StubInvoices extends InvoiceRepository {
  _StubInvoices(this.records);
  List<InvoiceRecord> records;
  bool failLoad = false;
  @override
  Future<List<InvoiceRecord>> listInvoices() async {
    if (failLoad) { throw StateError('Network unavailable'); }
    return records.toList();
  }
  @override
  Future<InvoiceRecord> markAsPaid(String id) async {
    final invoice = records.singleWhere((item) => item.id == id);
    if (!invoice.status.canMarkPaid) { throw StateError('Cannot mark paid'); }
    final updated = invoice.withStatus(InvoiceStatus.paid);
    records = [for (final item in records)
      if (item.id == id) updated else item];
    return updated;
  }
}

Future<void> _reveal(WidgetTester tester, String id) async {
  await tester.scrollUntilVisible(find.byKey(Key(id)), 120,
    scrollable: find.descendant(
      of: find.byKey(const Key('invoices-scroll')),
      matching: find.byType(Scrollable),
    ).first);
  await tester.pumpAndSettle();
}

Future<void> _openPaidDialog(WidgetTester tester) async {
  final action = find.byKey(const Key('invoice-details-mark-paid'));
  await tester.scrollUntilVisible(
    action, 120,
    scrollable: find.descendant(
      of: find.byKey(const Key('invoice-details-scroll')),
      matching: find.byType(Scrollable),
    ).first,
  );
  await tester.ensureVisible(action);
  await tester.pumpAndSettle();
  await tester.tap(action);
  await tester.pumpAndSettle();
}

void main() {
  setUp(DemoInvoiceRepository.clearLocalChanges);

  test('Demo payment only changes selected ID, never the amount or paid rows',
      () async {
    final repo = DemoInvoiceRepository();
    final before = await repo.listInvoices();
    final target = before.singleWhere(
      (record) => record.status == InvoiceStatus.pending);
    final updated = await repo.markAsPaid(target.id);
    expect(updated.status, InvoiceStatus.paid);
    expect(updated.manuallyPaidAt, isNotNull);
    expect(updated.id, target.id);
    expect(updated.number, target.number);
    expect(updated.amount, target.amount);
    final after = await repo.listInvoices();
    expect(after.singleWhere((x) => x.id == target.id).status,
      InvoiceStatus.paid);
    expect(after.where((x) => x.id != target.id)
      .every((x) => x.status == before.singleWhere(
        (b) => b.id == x.id).status), isTrue);
    await expectLater(repo.markAsPaid(target.id), throwsStateError);
    await expectLater(repo.markAsPaid('missing'), throwsStateError);
  });

  test('Draft creation cannot fake an already paid invoice', () async {
    final repo = DemoInvoiceRepository();
    final draft = _invoice('created', InvoiceStatus.draft, 83,
      DateTime(2026, 8, 24));
    await repo.saveDraft(draft);
    expect((await repo.listInvoices()).singleWhere(
      (x) => x.id == 'created').status, InvoiceStatus.draft);
    await expectLater(repo.saveDraft(draft), throwsArgumentError);
    await expectLater(repo.markAsPaid(draft.id), throwsStateError);
  });

  testWidgets('More menu opens Invoices, retaining global header and navigation',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home:Scaffold(body:MoreScreen()),
    ));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('open-invoices')),200,
      scrollable:find.descendant(
        of:find.byKey(const Key('more-menu-scroll')),
        matching:find.byType(Scrollable),
      ),
    );
    await tester.tap(find.byKey(const Key('open-invoices')));
    await tester.pumpAndSettle();
    expect(find.byType(InvoicesScreen), findsOneWidget);
    expect(find.text('Search Invoices'), findsOneWidget);
    expect(find.byKey(const Key('invoices-create')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Search, six tabs and numeric amount/date sorting work',
      (tester) async {
    final repo = _StubInvoices([
      _invoice('paid', InvoiceStatus.paid, 10, DateTime(2026, 8, 21)),
      _invoice('pending', InvoiceStatus.pending, 500, DateTime(2026, 8, 23)),
      _invoice('partial', InvoiceStatus.partiallyPaid, 225,
        DateTime(2026, 8, 24)),
      _invoice('draft', InvoiceStatus.draft, 120, DateTime(2026, 8, 20),
        client: 'Jean Dupont'),
      _invoice('overdue', InvoiceStatus.overdue, 20, DateTime(2026, 7, 21)),
      _invoice('sent', InvoiceStatus.sent, 40, DateTime(2026, 8, 22)),
    ]);
    await tester.pumpWidget(MaterialApp(home: InvoicesScreen(
      repository: repo)));
    await tester.pumpAndSettle();
    expect(find.text('Search Invoices'), findsOneWidget);
    expect(find.text('Date (newest)'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('details-tab-3')));
    await tester.tap(find.byKey(const Key('details-tab-3')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('invoice-card-pending')), findsOneWidget);
    expect(find.byKey(const Key('invoice-card-partial')), findsOneWidget);
    expect(find.byKey(const Key('invoice-card-paid')), findsNothing);
    await tester.ensureVisible(find.byKey(const Key('details-tab-0')));
    await tester.tap(find.byKey(const Key('details-tab-0')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('clients-search-input')), 'Jean');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('invoice-card-draft')), findsOneWidget);
    expect(find.byKey(const Key('invoice-card-paid')), findsNothing);
    await tester.enterText(find.byKey(const Key('clients-search-input')), '');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('invoices-sort')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('invoice-sort-highest')));
    await tester.pumpAndSettle();
    expect(find.text('Amount (highest)'), findsOneWidget);
    await _reveal(tester, 'invoice-card-pending');
    expect(tester.getTopLeft(find.byKey(
      const Key('invoice-card-pending'))).dy,
      lessThan(tester.getTopLeft(find.byKey(
        const Key('invoice-card-sent'))).dy));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Card opens details and only details can start marking paid',
      (tester) async {
    final repo = _StubInvoices([
      _invoice('pending', InvoiceStatus.pending, 78.80, DateTime(2026, 8, 23)),
    ]);
    await tester.pumpWidget(MaterialApp(home: InvoicesScreen(repository: repo)));
    await tester.pumpAndSettle();
    expect(find.text('Mark as Paid'), findsNothing);
    await tester.tap(find.byKey(const Key('invoice-card-pending')));
    await tester.pumpAndSettle();
    expect(find.byType(InvoiceDetailsScreen), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('invoice-details-mark-paid')),120,
      scrollable:find.descendant(
        of:find.byKey(const Key('invoice-details-scroll')),
        matching:find.byType(Scrollable),
      ).first,
    );
    expect(find.byKey(const Key('invoice-details-mark-paid')), findsOneWidget);
    expect(find.byKey(const Key('invoice-paid-confirm-heading')), findsNothing);
    await _openPaidDialog(tester);
    expect(find.byKey(const Key('invoice-paid-confirm-heading')), findsOneWidget);
    await tester.tap(find.byKey(const Key('invoice-paid-cancel')));
    await tester.pumpAndSettle();
    expect(repo.records.single.status, InvoiceStatus.pending);
    await _openPaidDialog(tester);
    await tester.tap(find.byKey(const Key('invoice-paid-confirm')));
    await tester.pumpAndSettle();
    expect(repo.records.single.status, InvoiceStatus.paid);
    expect(find.byKey(const Key('invoice-details-mark-paid')), findsNothing);
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('details-tab-4')));
    await tester.tap(find.byKey(const Key('details-tab-4')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('invoice-card-pending')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('FAB opens a dedicated draft screen, no unrelated form',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: InvoicesScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('invoices-create')));
    await tester.pumpAndSettle();
    expect(find.byType(AddInvoiceScreen), findsOneWidget);
    expect(find.byKey(const Key('invoice-create-job')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('invoice-create-save')), 140,
      scrollable: find.descendant(
        of: find.byKey(const Key('invoice-create-scroll')),
        matching: find.byType(Scrollable)).first);
    await tester.ensureVisible(find.byKey(const Key('invoice-create-save')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('invoice-create-save')));
    await tester.pump();
    expect(find.byKey(const Key('invoice-create-error')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Loading failure allows retry, empty tabs contain no fake rows',
      (tester) async {
    final repo = _StubInvoices([])..failLoad = true;
    await tester.pumpWidget(MaterialApp(home: InvoicesScreen(repository: repo)));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('invoices-retry')), findsOneWidget);
    repo.failLoad = false;
    await tester.tap(find.byKey(const Key('invoices-retry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('invoices-empty')), findsOneWidget);
  });

  for (final size in [
    const Size(320, 568), const Size(390, 844),
    const Size(768, 1024), const Size(1024, 768),
  ]) {
    testWidgets('Invoice tabs, rows and FAB fit at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(home: InvoicesScreen()));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('invoices-create')), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('details-tab-5')));
      if (size.width == 320) {
        await tester.ensureVisible(find.byKey(const Key('details-tab-3')));
        await tester.tap(find.byKey(const Key('details-tab-3')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('invoice-card-invoice-demo-pending-1')),
          findsOneWidget);
        expect(tester.takeException(), isNull, reason: '$size');
      }
      await tester.ensureVisible(find.byKey(const Key('details-tab-5')));
      await tester.tap(find.byKey(const Key('details-tab-5')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$size');
    });
  }
}
