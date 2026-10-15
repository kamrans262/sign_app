import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/features/invoices/domain/invoice_record.dart';
import 'package:sign2digital/features/invoices/presentation/screens/invoice_preview_screen.dart';
import 'package:sign2digital/features/invoices/presentation/screens/invoice_details_screen.dart';
import 'package:sign2digital/features/jobs/data/local_job_photo_source.dart';

const _line = InvoiceLineItem(
  description: 'Kitchen Installation', quantity: 2, unitPriceMinor: 12500);

InvoiceRecord _invoice({List<LocalJobPhotoSelection> photos = const []}) =>
  InvoiceRecord(
    id: 'invoice-preview-test',
    number: 'INV-2026-0125',
    project: 'Riverside Villa',
    clientName: 'Jean Dupont',
    date: DateTime(2026, 8, 23),
    dueDate: DateTime(2026, 9, 23),
    amount: 270.25,
    currency: 'CHF',
    status: InvoiceStatus.draft,
    vatBasisPoints: 810,
    depositPaidMinor: 3000,
    iban: 'CH93 0076 2011 6238 5295 7',
    billingAddress: 'Riverside Villa, Geneva',
    clientEmail: 'test@example.com',
    clientPhone: '+41 00 000 00 00',
    terms: '1. Payment within 30 days.',
    items: const [_line],
    photos: photos,
  );

class _Repo extends InvoiceRepository {
  _Repo(this.record);
  InvoiceRecord record;
  int attachmentUpdates = 0;

  @override
  Future<List<InvoiceRecord>> listInvoices() async => [record];

  @override
  Future<InvoiceRecord> markAsPaid(String id) async =>
      throw StateError('Not supported by the preview test');

  @override
  Future<InvoiceRecord> updateAttachments(
      String invoiceId, List<LocalJobPhotoSelection> photos) async {
    expect(invoiceId, record.id);
    attachmentUpdates++;
    record = record.withPhotos(photos);
    return record;
  }
}

class _Photos implements JobPhotoSource {
  final bytes = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/SqsAAAAASUVORK5CYII=');
  @override
  Future<List<LocalJobPhotoSelection>> upload() async =>
    [LocalJobPhotoSelection(
      name: 'invoice.jpg', bytes: bytes, sourceKey: 'photo-1')];
  @override
  Future<LocalJobPhotoSelection?> camera() async => null;
}

Future<void> _reach(WidgetTester tester, String id) async {
  final target = find.byKey(Key(id));
  await tester.scrollUntilVisible(target, 170,
    scrollable: find.descendant(
      of: find.byKey(const Key('invoice-preview-scroll')),
      matching: find.byType(Scrollable)).first);
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Invoice uses real record data and shared quote sections',
      (tester) async {
    final repo = _Repo(_invoice());
    await tester.pumpWidget(MaterialApp(
      home: InvoicePreviewScreen(invoice: repo.record, repository: repo)));
    await tester.pumpAndSettle();
    expect(find.text('Invoice Preview'), findsOneWidget);
    expect(find.text('INV-2026-0125'), findsOneWidget);
    expect(find.text('Invoice'), findsOneWidget);
    expect(find.text('Jean Dupont'), findsOneWidget);
    await _reach(tester, 'quote-preview-items-table');
    expect(find.text('Kitchen Installation'), findsOneWidget);
    await _reach(tester, 'invoice-preview-photo-grid');
    expect(find.text('General Terms & Conditions'), findsOneWidget);
    expect(find.text('Payment QR unavailable'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Share and PDF download receive real valid PDF bytes',
      (tester) async {
    final repo = _Repo(_invoice());
    var shares = 0;
    var downloads = 0;
    await tester.pumpWidget(MaterialApp(home: InvoicePreviewScreen(
      invoice: repo.record, repository: repo,
      onShare: (invoice, bytes) async {
        shares++;
        expect(invoice.number, 'INV-2026-0125');
        expect(bytes.sublist(0, 4), [37, 80, 68, 70]);
      },
      onDownload: (invoice, bytes) async {
        downloads++;
        expect(invoice.id, repo.record.id);
        expect(bytes.length, greaterThan(200));
      },
    )));
    await tester.pumpAndSettle();
    await _reach(tester, 'invoice-preview-share');
    await tester.tap(find.byKey(const Key('invoice-preview-share')));
    await tester.pumpAndSettle();
    await _reach(tester, 'invoice-preview-download');
    await tester.tap(find.byKey(const Key('invoice-preview-download')));
    await tester.pumpAndSettle();
    expect(shares, 1);
    expect(downloads, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Cancel photo selection leaves saved invoice untouched',
      (tester) async {
    final repo = _Repo(_invoice());
    await tester.pumpWidget(MaterialApp(home: InvoicePreviewScreen(
      invoice: repo.record, repository: repo, photoSource: _Photos())));
    await tester.pumpAndSettle();
    await _reach(tester, 'invoice-preview-add-photo');
    await tester.tap(find.byKey(const Key('invoice-preview-add-photo')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('invoice-preview-camera')));
    await tester.pumpAndSettle();
    expect(repo.attachmentUpdates, 0);
    expect(repo.record.photos, isEmpty);
  });

  testWidgets('Invoice Details opens preview of the selected record',
      (tester) async {
    final repo = _Repo(_invoice());
    await tester.pumpWidget(MaterialApp(home: InvoiceDetailsScreen(
      invoice: repo.record, repository: repo)));
    await tester.pumpAndSettle();
    final action = find.byKey(const Key('invoice-details-preview'));
    await tester.scrollUntilVisible(action, 160,
      scrollable: find.descendant(
        of: find.byKey(const Key('invoice-details-scroll')),
        matching: find.byType(Scrollable)).first);
    await tester.ensureVisible(action);
    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(find.byType(InvoicePreviewScreen), findsOneWidget);
    expect(find.text('INV-2026-0125'), findsOneWidget);
  });

  for (final size in [
    const Size(320, 568), const Size(390, 844),
    const Size(768, 1024),
  ]) {
    testWidgets('Invoice Preview fits at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = _Repo(_invoice());
      await tester.pumpWidget(MaterialApp(
        home: InvoicePreviewScreen(invoice: repo.record, repository: repo)));
      await tester.pumpAndSettle();
      await _reach(tester, 'invoice-preview-download');
      expect(tester.takeException(), isNull, reason: '$size');
    });
  }
}
