import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/features/invoices/domain/invoice_record.dart';
import 'package:sign2digital/features/invoices/data/demo_invoice_repository.dart';
import 'package:sign2digital/features/invoices/presentation/screens/add_invoice_screen.dart';
import 'package:sign2digital/features/invoices/presentation/screens/invoice_details_screen.dart';

InvoiceRecord _invoice({
  InvoiceStatus status = InvoiceStatus.pending,
  List<InvoiceLineItem> items = const [],
  List<InvoicePaymentRecord> payments = const [],
  List<InvoiceHistoryEvent> history = const [],
}) => InvoiceRecord(
  id: 'detail-test',
  number: 'INV-2026-0098',
  project: 'Riverside Villa',
  clientName: 'Jean Dupont',
  amount: 108.10,
  date: DateTime(2026, 8, 23),
  dueDate: DateTime(2026, 9, 5),
  iban: 'CH93 0076 2011 6238 5295 7',
  jobId: 'labour-demo-riverside',
  status: status,
  vatBasisPoints: 810,
  items: items,
  payments: payments,
  history: history,
);

const _items = [
  InvoiceLineItem(description: 'Electric installation',
    quantity: 1, unitPriceMinor: 10000),
];

Future<void> _open(WidgetTester tester, InvoiceRecord invoice, {
  InvoiceRepository? repository,
  InvoicePdfAction? onDownload,
  InvoicePdfAction? onSend,
}) async {
  await tester.pumpWidget(MaterialApp(home: InvoiceDetailsScreen(
    invoice: invoice,
    repository: repository ?? const DemoInvoiceRepository(),
    onDownload: onDownload,
    onSend: onSend,
  )));
  await tester.pumpAndSettle();
}

Future<void> _reach(WidgetTester tester, String key) async {
  final finder = find.byKey(Key(key));
  await tester.scrollUntilVisible(finder, 125,
    scrollable: find.descendant(
      of: find.byKey(const Key('invoice-details-scroll')),
      matching: find.byType(Scrollable)).first);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

void main() {
  setUp(DemoInvoiceRepository.clearLocalChanges);

  testWidgets('Details reuse real status, calculated amounts and copy job',
      (tester) async {
    await _open(tester, _invoice(items: _items));
    expect(find.text('Invoices'), findsOneWidget);
    expect(find.text('Riverside Villa'), findsWidgets);
    expect(find.byKey(const Key('invoice-details-table')), findsOneWidget);
    expect(find.text('CHF 108.10'), findsWidgets);
    await _reach(tester, 'information-row-copy');
    await tester.tap(find.byKey(const Key('information-row-copy')));
    final clipboard = await Clipboard.getData('text/plain');
    expect(clipboard?.text, 'Riverside Villa');
    expect(find.text('Paid Date'), findsNothing);
    expect(find.text('Sent Date'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Items show only actual rows and computed subtotal/VAT/total',
      (tester) async {
    await _open(tester, _invoice(items: _items));
    await tester.tap(find.byKey(const Key('details-tab-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('invoice-details-items')), findsOneWidget);
    expect(find.text('Electric installation'), findsOneWidget);
    expect(find.text('CHF 100.00'), findsWidgets);
    expect(find.text('CHF 8.10'), findsOneWidget);
    expect(find.text('CHF 108.10'), findsWidgets);
    await tester.tap(find.byKey(const Key('details-tab-0')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('invoice-details-table')), findsOneWidget);
  });

  testWidgets('Payments and history use only recorded events',
      (tester) async {
    final payment = InvoicePaymentRecord(
      id: 'actual-payment', amountMinor: 2500,
      method: 'Bank transfer', status: 'Paid',
      paidAt: DateTime(2026, 8, 24),
      referenceNumber: 'A-0005');
    final event = InvoiceHistoryEvent(
      id: 'event-1', title: 'Invoice sent',
      occurredAt: DateTime(2026, 8, 23, 12));
    await _open(tester, _invoice(
      items: _items, payments: [payment], history: [event]));
    await tester.tap(find.byKey(const Key('details-tab-2')));
    await tester.pumpAndSettle();
    expect(find.text('Bank transfer'), findsOneWidget);
    expect(find.text('A-0005'), findsOneWidget);
    expect(find.text('CHF 25.00'), findsWidgets);
    expect(find.text('CHF 83.10'), findsWidgets);
    await tester.tap(find.byKey(const Key('details-tab-3')));
    await tester.pumpAndSettle();
    expect(find.text('Invoice sent'), findsOneWidget);
    expect(find.byKey(const Key('invoice-history-event-1')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('No fictional payments/history or items appear',
      (tester) async {
    await _open(tester, _invoice());
    await tester.tap(find.byKey(const Key('details-tab-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('invoice-details-items-empty')), findsOneWidget);
    await tester.tap(find.byKey(const Key('details-tab-2')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('invoice-details-payments-empty')),
      findsOneWidget);
    await tester.tap(find.byKey(const Key('details-tab-3')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('invoice-details-history-empty')),
      findsOneWidget);
  });

  testWidgets('PDF download and send invoke actions with real generated bytes',
      (tester) async {
    var downloaded = 0;
    var shared = 0;
    await _open(tester, _invoice(items: _items),
      onDownload: (record, bytes) async {
        expect(record.number, 'INV-2026-0098');
        expect(bytes.length, greaterThan(100));
        expect(bytes.sublist(0, 4), <int>[37, 80, 68, 70]);
        downloaded++;
      },
      onSend: (record, bytes) async {
        expect(record.id, 'detail-test');
        expect(bytes, isNotEmpty);
        shared++;
      },
    );
    await _reach(tester, 'invoice-details-download');
    await tester.tap(find.byKey(const Key('invoice-details-download')));
    await tester.pumpAndSettle();
    expect(downloaded, 1);
    await _reach(tester, 'invoice-details-send');
    await tester.tap(find.byKey(const Key('invoice-details-send')));
    await tester.pumpAndSettle();
    expect(shared, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Edit opens populated form; paid invoices stay protected',
      (tester) async {
    final pending = _invoice(items: _items);
    await _open(tester, pending);
    await _reach(tester, 'invoice-details-edit');
    await tester.tap(find.byKey(const Key('invoice-details-edit')));
    await tester.pumpAndSettle();
    expect(find.byType(AddInvoiceScreen), findsOneWidget);
    expect(find.text('Save Changes'), findsWidgets);
    expect(find.text('INV-2026-0098'), findsWidgets);
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await _open(tester, _invoice(status: InvoiceStatus.paid, items: _items));
    await _reach(tester, 'invoice-details-edit');
    await tester.tap(find.byKey(const Key('invoice-details-edit')));
    await tester.pump();
    expect(find.byType(AddInvoiceScreen), findsNothing);
    expect(find.textContaining('cannot be edited'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('Manual paid mutation preserves identity and creates real local event',
      () async {
    final repo = DemoInvoiceRepository();
    final before = (await repo.listInvoices())
        .firstWhere((record) => record.status == InvoiceStatus.pending);
    final after = await repo.markAsPaid(before.id);
    expect(after.id, before.id);
    expect(after.number, before.number);
    expect(after.amount, before.amount);
    expect(after.status, InvoiceStatus.paid);
    expect(after.manuallyPaidAt, isNotNull);
    expect(after.history.single.title, 'Invoice marked paid');
    expect(after.payments.single.method, 'Manual record');
  });

  for (final size in [
    const Size(320, 568), const Size(390, 844),
    const Size(768, 1024), const Size(1024, 768),
  ]) {
    testWidgets('Four-tab details and action controls adapt at $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _open(tester, _invoice(items: _items));
      await tester.ensureVisible(find.byKey(const Key('details-tab-3')));
      await tester.tap(find.byKey(const Key('details-tab-3')));
      await tester.pumpAndSettle();
      await _reach(tester, 'invoice-details-download');
      expect(find.byKey(const Key('invoice-details-send')), findsOneWidget);
      expect(find.byKey(const Key('invoice-details-edit')), findsOneWidget);
      expect(tester.takeException(), isNull, reason: '$size');
    });
  }
}
