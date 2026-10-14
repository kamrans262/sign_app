import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/core/widgets/sign2digital_bottom_navigation_bar.dart';
import 'package:sign2digital/features/expenses/data/demo_expense_repository.dart';
import 'package:sign2digital/features/expenses/domain/expense_record.dart';
import 'package:sign2digital/features/expenses/presentation/screens/receipt_screen.dart';
import 'package:sign2digital/features/jobs/data/local_job_photo_source.dart';

final _imageBytes = Uint8List.fromList(base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJ'
  'AAAADUlEQVQIHWP4z8DwHwAFgAI/ScL/nwAAAABJRU5ErkJggg=='));

LocalJobPhotoSelection _photo(int n) => LocalJobPhotoSelection(
  name: 'receipt-$n.png', sourceKey: 'receipt-$n',
  bytes: _imageBytes,
);

ExpenseRecord _expense(List<LocalJobPhotoSelection> photos) =>
  ExpenseRecord(id: 'demo-expense-1',
    title: 'Fuel', category: ExpenseCategory.fuel,
    job: 'Kitchen renovation', report: 'Site report',
    amount: 78.8, date: DateTime(2026,8,23),
    status: ExpenseStatus.approved, photos: photos);

class _PhotoSource implements JobPhotoSource {
  @override
  Future<List<LocalJobPhotoSelection>> upload() async => [_photo(3)];
  @override
  Future<LocalJobPhotoSelection?> camera() async => _photo(4);
}

void main() {
  setUp(DemoExpenseRepository.clearDrafts);

  testWidgets('Receipt has correct preview, all thumbnails and upload control',
      (tester) async {
    await tester.pumpWidget(MaterialApp(home: ReceiptScreen(
      expense: _expense([_photo(0), _photo(1), _photo(2)]),
      repository: const DemoExpenseRepository(),
    )));
    expect(find.text('Receipt'), findsOneWidget);
    expect(find.byKey(const Key('receipt-preview-panel')), findsOneWidget);
    expect(find.byKey(const Key('receipt-preview-image')), findsOneWidget);
    for (var n=0; n<3; n++) {
      expect(find.byKey(Key('receipt-thumbnail-$n')), findsOneWidget);
    }
    expect(find.byKey(const Key('receipt-add-photo')), findsOneWidget);
    expect(find.byKey(const Key('receipt-share')), findsOneWidget);
    expect(find.byKey(const Key('receipt-download')), findsOneWidget);
    expect(tester.widget<Sign2DigitalBottomNavigationBar>(
      find.byType(Sign2DigitalBottomNavigationBar)).selectedIndex, 4);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Selecting a thumbnail changes which file Share receives',
      (tester) async {
    String? shared;
    await tester.pumpWidget(MaterialApp(home: ReceiptScreen(
      expense: _expense([_photo(0), _photo(1), _photo(2)]),
      repository: const DemoExpenseRepository(),
      onShare: (file) async { shared = file.name; },
    )));
    await tester.ensureVisible(find.byKey(const Key('receipt-thumbnail-1')));
    await tester.tap(find.byKey(const Key('receipt-thumbnail-1')));
    await tester.ensureVisible(find.byKey(const Key('receipt-share')));
    await tester.tap(find.byKey(const Key('receipt-share')));
    await tester.pump();
    expect(shared, 'receipt-1.png');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Photo gallery upload persists and selects newest receipt',
      (tester) async {
    const repo = DemoExpenseRepository();
    ExpenseRecord? changed;
    await tester.pumpWidget(MaterialApp(home: ReceiptScreen(
      expense: _expense([_photo(0)]), repository: repo,
      photoSource: _PhotoSource(),
      onExpenseChanged: (value) => changed = value,
    )));
    await tester.ensureVisible(find.byKey(const Key('receipt-add-photo')));
    await tester.tap(find.byKey(const Key('receipt-add-photo')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('receipt-pick-gallery')));
    await tester.pumpAndSettle();
    expect(changed?.photos.length, 2);
    expect(changed!.photos.last.name, 'receipt-3.png');
    expect(find.byKey(const Key('receipt-thumbnail-1')), findsOneWidget);
    final stored = (await repo.listExpenses()).firstWhere(
      (e) => e.id == 'demo-expense-1');
    expect(stored.photos.length, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Remove asks permission, saves changes and shows empty state',
      (tester) async {
    const repo = DemoExpenseRepository();
    await tester.pumpWidget(MaterialApp(home: ReceiptScreen(
      expense: _expense([_photo(0)]), repository: repo,
    )));
    final remove = find.descendant(
      of: find.byKey(const Key('receipt-thumbnail-0')),
      matching: find.byType(IconButton));
    await tester.ensureVisible(remove);
    await tester.tap(remove);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('receipt-confirm-remove')), findsOneWidget);
    await tester.tap(find.byKey(const Key('receipt-confirm-remove')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('receipt-preview-empty')), findsOneWidget);
    expect(find.byKey(const Key('receipt-add-photo')), findsOneWidget);
    expect(find.byKey(const Key('receipt-thumbnail-0')), findsNothing);
    final stored = (await repo.listExpenses()).firstWhere(
      (e) => e.id == 'demo-expense-1');
    expect(stored.photos, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Download uses chosen file and acknowledges only successful save',
      (tester) async {
    String? downloaded;
    await tester.pumpWidget(MaterialApp(home: ReceiptScreen(
      expense: _expense([_photo(1)]),
      repository: const DemoExpenseRepository(),
      onDownload: (file) async { downloaded = file.name; return true; },
    )));
    await tester.ensureVisible(find.byKey(const Key('receipt-download')));
    await tester.tap(find.byKey(const Key('receipt-download')));
    await tester.pump();
    expect(downloaded, 'receipt-1.png');
    expect(find.text('Receipt saved.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Without receipts, Share/Download are honest and upload remains',
      (tester) async {
    await tester.pumpWidget(MaterialApp(home: ReceiptScreen(
      expense: _expense([]), repository: const DemoExpenseRepository(),
    )));
    expect(find.byKey(const Key('receipt-preview-empty')), findsOneWidget);
    expect(find.byKey(const Key('receipt-add-photo')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('receipt-share')));
    await tester.tap(find.byKey(const Key('receipt-share')));
    await tester.pump();
    expect(find.text('No receipt available to share.'), findsOneWidget);
  });

  testWidgets('Read-only receipt hides mutation controls',
      (tester) async {
    await tester.pumpWidget(MaterialApp(home: ReceiptScreen(
      expense: _expense([_photo(0)]),
      repository: const DemoExpenseRepository(),
      canEdit: false,
    )));
    expect(find.byKey(const Key('receipt-add-photo')), findsNothing);
    expect(find.descendant(
      of: find.byKey(const Key('receipt-thumbnail-0')),
      matching: find.byType(IconButton)), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final size in [
    const Size(320,650), const Size(375,667),
    const Size(390,844), const Size(430,932),
    const Size(600,900), const Size(768,1024),
    const Size(1024,768), const Size(720,390),
  ]) {
    testWidgets('Receipt layout scales and buttons remain reachable $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(home: ReceiptScreen(
        expense: _expense([_photo(0),_photo(1),_photo(2)]),
        repository: const DemoExpenseRepository(),
      )));
      expect(find.byKey(const Key('receipt-preview-panel')), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('receipt-download')));
      await tester.pump();
      expect(find.byKey(const Key('receipt-share')), findsOneWidget);
      expect(find.byKey(const Key('receipt-add-photo')), findsOneWidget);
      expect(tester.takeException(), isNull, reason: '$size');
    });
  }
}
