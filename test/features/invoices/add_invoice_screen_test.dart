import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/features/deposits/domain/deposit_record.dart';
import 'package:sign2digital/features/invoices/domain/invoice_record.dart';
import 'package:sign2digital/features/invoices/presentation/screens/add_invoice_screen.dart';
import 'package:sign2digital/features/invoices/services/invoice_voice_extraction_service.dart';
import 'package:sign2digital/features/labour/data/demo_labour_repository.dart';
import 'package:sign2digital/features/jobs/services/voice_recorder_service.dart';

class _Invoices extends InvoiceRepository {
  InvoiceRecord? saved;
  bool reject = false;
  @override
  Future<List<InvoiceRecord>> listInvoices() async =>
      saved == null ? [] : [saved!];
  @override
  Future<InvoiceRecord> markAsPaid(String id) =>
      Future<InvoiceRecord>.error(
        UnsupportedError('Mark as Paid is not supported by this test fake.'));
  @override
  Future<void> saveDraft(InvoiceRecord invoice) async {
    if (reject) { throw StateError('Not saved'); }
    saved = invoice;
  }
}

class _Deposits extends DepositRepository {
  @override
  Future<List<DepositRecord>> listDeposits() async => [
    DepositRecord(
      id: 'paid-matching', title: 'Riverside Villa', clientName: 'Jean Dupont',
      amount: 12.50, date: DateTime(2026, 8, 24),
      jobId: LabourDemoJobs.riverside.id,
      status: DepositStatus.received),
    DepositRecord(
      id: 'pending-matching', title: 'Riverside Villa', clientName: 'Jean Dupont',
      amount: 50, date: DateTime(2026, 8, 24),
      jobId: LabourDemoJobs.riverside.id,
      status: DepositStatus.pending),
    DepositRecord(
      id: 'paid-unrelated', title: 'Another job', clientName: 'Jean Dupont',
      amount: 100, date: DateTime(2026, 8, 24),
      jobId: 'another-job', status: DepositStatus.received),
  ];
}

class _Recorder implements VoiceRecorderService {
  bool started = false;
  @override
  Stream<double> get amplitude => const Stream<double>.empty();
  @override
  Future<void> start() async { started = true; }
  @override
  Future<void> pause() async {}
  @override
  Future<void> resume() async {}
  @override
  Future<String> save() async => 'fake-invoice.m4a';
  @override
  Future<void> cancel() async {}
  @override
  Future<void> dispose() async {}
}

class _Voice implements InvoiceVoiceExtractionService {
  final completer = Completer<InvoiceVoiceSuggestion>();
  @override
  Future<InvoiceVoiceSuggestion> extract(String path) {
    expect(path, 'fake-invoice.m4a');
    return completer.future;
  }
}

Future<void> _scroll(WidgetTester tester, String key) async {
  final finder = find.byKey(Key(key));
  await tester.scrollUntilVisible(
    finder, 140,
    scrollable: find.descendant(
      of: find.byKey(const Key('invoice-create-scroll')),
      matching: find.byType(Scrollable)).first);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Future<void> _launch(WidgetTester tester, AddInvoiceScreen screen) async {
  await tester.pumpWidget(MaterialApp(home: Scaffold(
    body: Builder(builder: (context) => TextButton(
      onPressed: () => Navigator.of(context).push<void>(
        MaterialPageRoute<void>(builder: (_) => screen)),
      child: const Text('Open invoice'),
    )),
  )));
  await tester.tap(find.text('Open invoice'));
  await tester.pumpAndSettle();
}

void main() {
  test('Line items use minor units, VAT rounds and deposits reduce due', () {
    final items = [
      const InvoiceLineItem(
        description: 'Electric Installation',
        quantity: 3, unitPriceMinor: 1999),
      const InvoiceLineItem(
        description: 'Labour',
        quantity: 1, unitPriceMinor: 1001),
    ];
    final invoice = InvoiceRecord(
      id: 'math', number: 'INV-MATH', project: 'Riverside Villa',
      clientName: 'John Smith', amount: 76.98,
      date: DateTime(2026, 8, 24), status: InvoiceStatus.draft,
      items: items, vatBasisPoints: 1000, depositPaidMinor: 2500);
    expect(invoice.subtotalMinor, 6998);
    expect(invoice.vatMinor, 700);
    expect(invoice.totalMinor, 7698);
    expect(invoice.amountDueMinor, 5198);
    expect(invoice.withStatus(InvoiceStatus.paid).items.length, 2);
    expect(invoice.withStatus(InvoiceStatus.paid).depositPaidMinor, 2500);
    final incomplete = InvoiceRecord(
      id: 'unknown', number: 'N', project: 'J', clientName: 'C',
      amount: 0, date: DateTime(2026),
      status: InvoiceStatus.draft,
      items: [const InvoiceLineItem(description: 'Material',
        quantity: 1)]);
    expect(incomplete.subtotalMinor, isNull);
    expect(incomplete.totalMinor, isNull);
    expect(incomplete.amountDueMinor, isNull);
  });

  test('IBAN checksum and AI missing-data validation', () {
    expect(isValidInvoiceIban('CH93 0076 2011 6238 5295 7'), isTrue);
    expect(isValidInvoiceIban('CH93 0076 2011 6238 5295 8'), isFalse);
    expect(isValidInvoiceIban(''), isFalse);
    final suggestions = InvoiceVoiceSuggestion.fromJson({
      'invoiceNumber': 'INV-2026-0001',
      'issueDate': '2026-08-25',
      'dueDate': '2026-08-30',
      'items': [
        {'description': 'Labour', 'quantity': 2, 'unitPrice': 85.20},
        {'description': 'Material', 'quantity': 1},
      ],
    });
    expect(suggestions.invoiceNumber, 'INV-2026-0001');
    expect(suggestions.items[0].unitPriceMinor, 8520);
    expect(suggestions.items[1].unitPriceMinor, isNull);
    expect(InvoiceVoiceSuggestion.fromJson({
      'issueDate': '2026-02-30',
      'items': [{'description': '', 'quantity': 0}],
    }).hasSuggestions, isFalse);
  });

  testWidgets('Figma fields, shared document table and summary are present',
      (tester) async {
    await _launch(tester, const AddInvoiceScreen());
    expect(find.text('Invoices'), findsOneWidget);
    expect(find.text('Create with AI Voice'), findsOneWidget);
    await _scroll(tester, 'invoice-create-due-date');
    expect(find.text('Due Date'), findsOneWidget);
    await _scroll(tester, 'invoice-items-table');
    expect(find.text('Description'), findsOneWidget);
    expect(find.text('Unit Price'), findsOneWidget);
    await _scroll(tester, 'invoice-financial-summary');
    expect(find.text('Deposit Paid'), findsOneWidget);
    expect(find.text('Amount Due'), findsOneWidget);
    await _scroll(tester, 'invoice-create-save');
    expect(find.text('Create Invoice'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Selected job client, received deposit and completed lines save',
      (tester) async {
    final repo = _Invoices();
    var dateIndex = 0;
    InvoiceRecord? returned;
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: Builder(builder: (context) => TextButton(
        onPressed: () async {
          returned = await Navigator.of(context).push<InvoiceRecord>(
            MaterialPageRoute<InvoiceRecord>(
              builder: (_) => AddInvoiceScreen(
                repository: repo, depositRepository: _Deposits(),
                jobs: [LabourDemoJobs.riverside],
                initialIban: 'CH93 0076 2011 6238 5295 7',
                vatBasisPoints: 1000,
                initialItems: const [
                  InvoiceLineItem(
                    description: 'Labour', quantity: 1, unitPriceMinor: 10000),
                ],
                datePicker: (_, _) async =>
                    DateTime(2026, 8, 25 + dateIndex++),
              ),
            ),
          );
        },
        child: const Text('Open invoice'),
      )),
    )));
    await tester.tap(find.text('Open invoice'));
    await tester.pumpAndSettle();
    await _scroll(tester, 'invoice-create-job');
    await tester.tap(find.byKey(const Key('invoice-create-job')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(
      Key('invoice-pick-job-${LabourDemoJobs.riverside.id}')));
    await tester.pumpAndSettle();
    await _scroll(tester, 'invoice-create-date');
    await tester.tap(find.byKey(const Key('invoice-create-date')));
    await tester.pumpAndSettle();
    await _scroll(tester, 'invoice-create-due-date');
    await tester.tap(find.byKey(const Key('invoice-create-due-date')));
    await tester.pumpAndSettle();
    await _scroll(tester, 'invoice-financial-summary');
    expect(find.text('CHF 12.50'), findsOneWidget);
    expect(find.text('CHF 97.50'), findsOneWidget);
    await _scroll(tester, 'invoice-create-save');
    await tester.tap(find.byKey(const Key('invoice-create-save')));
    await tester.pumpAndSettle();
    expect(repo.saved?.status, InvoiceStatus.draft);
    expect(returned?.jobId, LabourDemoJobs.riverside.id);
    expect(returned?.amount, 110);
    expect(returned?.depositPaidMinor, 1250);
    expect(returned?.amountDueMinor, 9750);
    expect(returned?.dueDate, DateTime(2026, 8, 26));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Incomplete prices cannot create a draft',
      (tester) async {
    final repo = _Invoices();
    await _launch(tester, AddInvoiceScreen(repository: repo,
      initialItems: const [
        InvoiceLineItem(description: 'Material', quantity: 1),
      ]));
    await _scroll(tester, 'invoice-unpriced-notice');
    expect(find.textContaining('Unpriced items'), findsOneWidget);
    await _scroll(tester, 'invoice-create-save');
    await tester.tap(find.byKey(const Key('invoice-create-save')));
    await tester.pump();
    expect(find.byKey(const Key('invoice-create-error')), findsOneWidget);
    expect(repo.saved, isNull);
  });

  testWidgets('Invoice voice uses shared dialog and preserves typed values',
      (tester) async {
    final voice = _Voice();
    final recorder = _Recorder();
    await _launch(tester, AddInvoiceScreen(
      voiceRecorderFactory: () => recorder,
      voiceExtractionService: voice,
    ));
    await tester.tap(find.byKey(const Key('create-with-ai-voice-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Record Invoice Details'), findsOneWidget);
    expect(find.byKey(const Key('invoice-ai-key')), findsNothing);
    expect(recorder.started, isTrue);
    await tester.tap(find.byKey(const Key('voice-save')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('AI is Processing your Voice'), findsOneWidget);
    voice.completer.complete(const InvoiceVoiceSuggestion(
      clientName: 'Jean Dupont',
      notes: 'Work completed',
    ));
    await tester.pumpAndSettle();
    await _scroll(tester, 'invoice-create-client');
    expect(find.text('Jean Dupont'), findsOneWidget);
    await _scroll(tester, 'invoice-create-notes');
    expect(find.text('Work completed'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final size in [
    const Size(320, 568), const Size(390, 844),
    const Size(768, 1024), const Size(1024, 768),
  ]) {
    testWidgets('Invoice table and save remain reachable at $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _launch(tester, const AddInvoiceScreen());
      await _scroll(tester, 'invoice-items-table');
      await _scroll(tester, 'invoice-create-save');
      expect(find.byKey(const Key('invoice-create-save')), findsOneWidget);
      expect(tester.takeException(), isNull, reason: '$size');
    });
  }
}
