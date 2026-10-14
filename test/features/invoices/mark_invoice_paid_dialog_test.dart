import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/features/invoices/domain/invoice_record.dart';
import 'package:sign2digital/features/invoices/presentation/screens/invoice_details_screen.dart';
import 'package:sign2digital/features/invoices/presentation/widgets/mark_invoice_paid_dialog.dart';

InvoiceRecord _invoice([InvoiceStatus status = InvoiceStatus.pending]) =>
    InvoiceRecord(
      id: 'test-invoice',
      number: 'INV-2026-0098',
      project: 'Riverside Villa',
      clientName: 'John Smith',
      amount: 78.80,
      date: DateTime(2026, 8, 23),
      status: status,
    );

class _ControlledRepository extends InvoiceRepository {
  _ControlledRepository(this.record);
  InvoiceRecord record;
  final response = Completer<InvoiceRecord>();
  int confirmations = 0;

  @override
  Future<List<InvoiceRecord>> listInvoices() async => [record];

  @override
  Future<InvoiceRecord> markAsPaid(String id) async {
    confirmations++;
    final result = await response.future;
    record = result;
    return result;
  }
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
  testWidgets('Confirmation modal matches shared UI, never updates on Cancel',
      (tester) async {
    final repo = _ControlledRepository(_invoice());
    await tester.pumpWidget(MaterialApp(home:
      InvoiceDetailsScreen(invoice: repo.record, repository: repo)));
    await tester.pumpAndSettle();
    await _openPaidDialog(tester);
    expect(find.byKey(const Key('invoice-paid-confirm-heading')), findsOneWidget);
    expect(find.text('This will record the invoice as manually paid'),
      findsOneWidget);
    expect(find.byKey(const Key('invoice-paid-cancel')), findsOneWidget);
    expect(find.byKey(const Key('invoice-paid-confirm')), findsOneWidget);
    await tester.tap(find.byKey(const Key('invoice-paid-cancel')));
    await tester.pumpAndSettle();
    expect(repo.confirmations, 0);
    expect(repo.record.status, InvoiceStatus.pending);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Busy modal cannot double submit and updates only on success',
      (tester) async {
    final repo = _ControlledRepository(_invoice());
    await tester.pumpWidget(MaterialApp(home:
      InvoiceDetailsScreen(invoice: repo.record, repository: repo)));
    await tester.pumpAndSettle();
    await _openPaidDialog(tester);
    await tester.tap(find.byKey(const Key('invoice-paid-confirm')));
    await tester.pump();
    expect(repo.confirmations, 1);
    expect(repo.record.status, InvoiceStatus.pending);
    expect(tester.widget<PopScope>(
      find.descendant(of: find.byType(MarkInvoicePaidDialog),
        matching: find.byType(PopScope))).canPop, isFalse);
    repo.response.complete(_invoice(InvoiceStatus.paid));
    await tester.pumpAndSettle();
    expect(repo.record.status, InvoiceStatus.paid);
    expect(find.byType(MarkInvoicePaidDialog), findsNothing);
    expect(find.byKey(const Key('invoice-details-mark-paid')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Failed repository update leaves invoice unchanged and retryable',
      (tester) async {
    final repo = _ControlledRepository(_invoice());
    await tester.pumpWidget(MaterialApp(home:
      InvoiceDetailsScreen(invoice: repo.record, repository: repo)));
    await tester.pumpAndSettle();
    await _openPaidDialog(tester);
    await tester.tap(find.byKey(const Key('invoice-paid-confirm')));
    await tester.pump();
    repo.response.completeError(StateError('Network failed'));
    await tester.pumpAndSettle();
    expect(repo.record.status, InvoiceStatus.pending);
    expect(find.byKey(const Key('invoice-paid-error')), findsOneWidget);
    expect(find.byKey(const Key('invoice-paid-confirm')), findsOneWidget);
    await tester.tap(find.byKey(const Key('invoice-paid-cancel')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Already paid and drafts never expose the paid action',
      (tester) async {
    for (final status in [InvoiceStatus.paid, InvoiceStatus.draft]) {
      final invoice = _invoice(status);
      await tester.pumpWidget(MaterialApp(home:
        InvoiceDetailsScreen(
          key: ValueKey(status),
          invoice: invoice,
          repository: _ControlledRepository(invoice),
        )));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('invoice-details-mark-paid')), findsNothing);
    }
    expect(tester.takeException(), isNull);
  });

  for (final size in [
    const Size(320, 568), const Size(390, 844),
    const Size(768, 1024), const Size(1024, 768),
  ]) {
    testWidgets('Popup text and buttons do not overflow at $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = _ControlledRepository(_invoice());
      await tester.pumpWidget(MaterialApp(home:
        InvoiceDetailsScreen(invoice: repo.record, repository: repo)));
      await tester.pumpAndSettle();
      await _openPaidDialog(tester);
      expect(find.byKey(const Key('invoice-paid-confirm')), findsOneWidget);
      expect(tester.takeException(), isNull, reason: '$size');
    });
  }
}
