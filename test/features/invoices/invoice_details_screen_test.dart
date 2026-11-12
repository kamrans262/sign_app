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
  String lifecycleStatus = 'draft',
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
  lifecycleStatus: lifecycleStatus,
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
  if (finder.evaluate().isNotEmpty) {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    return;
  }
  await tester.scrollUntilVisible(finder, 125,
    scrollable: find.descendant(
      of: find.byKey(const Key('invoice-details-scroll')),
      matching: find.byType(Scrollable)).first);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Future<void> _selectTab(WidgetTester tester, int index) async {
  final target = find.byKey(Key('details-tab-$index'));
  await tester.scrollUntilVisible(target, -125,
    scrollable: find.descendant(
      of: find.byKey(const Key('invoice-details-scroll')),
      matching: find.byType(Scrollable)).first);
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
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
    String? copiedJob;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          copiedJob = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(() => messenger.setMockMethodCallHandler(
      SystemChannels.platform, null));
    await tester.ensureVisible(find.byKey(const Key('information-row-copy')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('information-row-copy')));
    await tester.pump();
    expect(copiedJob, 'Riverside Villa');
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
    expect(find.byKey(const Key('invoice-details-download')), findsOneWidget);
    expect(find.byKey(const Key('invoice-details-preview')), findsOneWidget);
    expect(find.byKey(const Key('invoice-details-send')), findsNothing);
    expect(find.byKey(const Key('invoice-details-edit')), findsNothing);
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
    expect(find.byKey(const Key('invoice-details-actions')), findsNothing);
    expect(find.byKey(const Key('invoice-details-download')), findsNothing);
    expect(find.byKey(const Key('invoice-details-send')), findsNothing);
    await tester.tap(find.byKey(const Key('details-tab-3')));
    await tester.pumpAndSettle();
    expect(find.text('Invoice sent'), findsOneWidget);
    expect(find.byKey(const Key('invoice-history-event-1')), findsOneWidget);
    expect(find.byKey(const Key('invoice-details-actions')), findsNothing);
    expect(find.byKey(const Key('invoice-details-download')), findsNothing);
    expect(find.byKey(const Key('invoice-details-preview')), findsNothing);
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
    await _open(tester, _invoice(
      items: _items, lifecycleStatus: 'approved'),
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
    await tester.tap(find.byKey(const Key('details-tab-1')));
    await tester.pumpAndSettle();
    await _reach(tester, 'invoice-details-download');
    await tester.tap(find.byKey(const Key('invoice-details-download')));
    await tester.pumpAndSettle();
    expect(downloaded, 1);
    await tester.tap(find.byKey(const Key('details-tab-0')));
    await tester.pumpAndSettle();
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
    await tester.scrollUntilVisible(
      find.byKey(const Key('invoice-create-number')), -125,
      scrollable: find.descendant(
        of: find.byKey(const Key('invoice-create-scroll')),
        matching: find.byType(Scrollable)).first);
    final numberInput = find.descendant(
      of: find.byKey(const Key('invoice-create-number')),
      matching: find.byType(EditableText));
    expect(tester.widget<EditableText>(numberInput).controller.text,
      'INV-2026-0098');
    await tester.scrollUntilVisible(
      find.byKey(const Key('invoice-create-save')), 140,
      scrollable: find.descendant(
        of: find.byKey(const Key('invoice-create-scroll')),
        matching: find.byType(Scrollable)).first);
    expect(find.text('Save Changes'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Drafts never show Send; paid invoices never expose Edit',
      (tester) async {
    await _open(tester, _invoice(status: InvoiceStatus.draft,
      items: _items));
    await _reach(tester, 'invoice-details-edit');
    expect(find.byKey(const Key('invoice-details-send')), findsNothing);
    expect(find.byKey(const Key('invoice-details-edit')), findsOneWidget);
    await _selectTab(tester, 1);
    await _reach(tester, 'invoice-details-download');
    final disabledDownload = tester.widget<InkWell>(
      find.descendant(of: find.byKey(const Key('invoice-details-download')),
        matching: find.byType(InkWell)).first);
    expect(disabledDownload.onTap, isNull);
    expect(find.byKey(const Key('invoice-details-preview')), findsOneWidget);
    await _open(tester, _invoice(status: InvoiceStatus.paid,
      lifecycleStatus: 'approved', items: _items));
    expect(find.byKey(const Key('invoice-details-edit')), findsNothing);
    expect(find.byKey(const Key('invoice-details-approve')), findsNothing);
    expect(find.byKey(const Key('invoice-details-mark-paid')), findsNothing);
    expect(find.byType(AddInvoiceScreen), findsNothing);
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

  testWidgets('Approved invoice shows Send only under Details',
      (tester) async {
    await _open(tester, _invoice(status: InvoiceStatus.pending,
      lifecycleStatus: 'approved', items: _items));
    await _reach(tester, 'invoice-details-send');
    expect(find.byKey(const Key('invoice-details-send')), findsOneWidget);
    expect(find.byKey(const Key('invoice-details-edit')), findsNothing);
    expect(find.byKey(const Key('invoice-details-approve')), findsNothing);
    await _selectTab(tester, 1);
    expect(find.byKey(const Key('invoice-details-send')), findsNothing);
    expect(find.byKey(const Key('invoice-details-download')), findsOneWidget);
    expect(find.byKey(const Key('invoice-details-preview')), findsOneWidget);
  });

  for (final size in [
    const Size(320, 568), const Size(390, 844),
    const Size(768, 1024), const Size(1024, 768),
  ]) {
    testWidgets('Invoice tab-specific actions adapt at $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _open(tester, _invoice(status: InvoiceStatus.draft,
        items: _items));
      await _reach(tester, 'invoice-details-edit');
      expect(find.byKey(const Key('invoice-details-edit')), findsOneWidget);
      expect(find.byKey(const Key('invoice-details-send')), findsNothing);
      await _selectTab(tester, 1);
      await _reach(tester, 'invoice-details-preview');
      final download = tester.getRect(
        find.byKey(const Key('invoice-details-download')));
      final preview = tester.getRect(
        find.byKey(const Key('invoice-details-preview')));
      expect(download.top, closeTo(preview.top, 1), reason: '$size');
      expect(download.width, closeTo(preview.width, 1), reason: '$size');
      expect(tester.takeException(), isNull, reason: '$size');
      await _selectTab(tester, 2);
      expect(find.byKey(const Key('invoice-details-actions')), findsNothing);
      await _selectTab(tester, 3);
      expect(find.byKey(const Key('invoice-details-actions')), findsNothing);
      expect(tester.takeException(), isNull, reason: '$size');
    });
  }
}
