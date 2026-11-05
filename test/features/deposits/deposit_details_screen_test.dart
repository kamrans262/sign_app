import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/features/deposits/data/demo_deposit_repository.dart';
import 'package:sign2digital/features/deposits/domain/deposit_record.dart';
import 'package:sign2digital/features/deposits/presentation/screens/deposit_details_screen.dart';
import 'package:sign2digital/features/deposits/presentation/screens/add_deposit_screen.dart';
import 'package:sign2digital/features/deposits/presentation/screens/deposits_screen.dart';
import 'package:sign2digital/features/jobs/data/local_job_photo_source.dart';

DepositRecord _record({
  DepositStatus status = DepositStatus.received,
  List<LocalJobPhotoSelection> photos = const [],
  List<DepositHistoryEvent> history = const [],
}) => DepositRecord(
  id: 'deposit-test',
  title: 'Riverside Villa',
  clientName: 'Jean Dupont',
  amount: 78.80,
  date: DateTime(2026, 8, 23),
  status: status,
  jobId: 'labour-demo-riverside',
  paymentMethod: 'Bank transfer',
  referenceNumber: 'TRX-2026-0098',
  photos: photos,
  history: history,
);

class _Repository extends DepositRepository {
  _Repository(this.record);
  DepositRecord? record;
  bool fail = false;
  int deletes = 0, refunds = 0, updates = 0, receives = 0;
  @override
  Future<List<DepositRecord>> listDeposits() async =>
      record == null ? [] : [record!];

  @override
  Future<void> deleteDeposit(String id) async {
    deletes++;
    if (fail) { throw StateError('Unsuccessful deletion'); }
    if (record?.id != id) { throw StateError('Not found'); }
    record = null;
  }

  @override
  Future<DepositRecord> receiveDeposit(String id) async {
    receives++;
    if(fail||record?.id!=id||record?.status!=DepositStatus.pending){
      throw StateError('Manual confirmation failed');
    }
    record=record!.copyWith(status:DepositStatus.received);
    return record!;
  }

  @override
  Future<DepositRecord> refundDeposit(String id) async {
    refunds++;
    if (fail) { throw StateError('Unsuccessful refund'); }
    if (record?.id != id || record?.status != DepositStatus.received) {
      throw StateError('Invalid refund');
    }
    record = record!.copyWith(status: DepositStatus.refunded);
    return record!;
  }

  @override
  Future<DepositRecord> updateDeposit(DepositRecord updated) async {
    updates++;
    if (fail) { throw StateError('Unsuccessful edit'); }
    record = updated;
    return updated;
  }
}

Future<void> _show(WidgetTester tester, DepositRecord deposit,
    DepositRepository repo, {
      DepositReceiptShare? share,
      DepositReceiptDownload? download,
    }) async {
  await tester.pumpWidget(MaterialApp(
    home: DepositDetailsScreen(
      deposit: deposit, repository: repo,
      onReceiptShare: share, onReceiptDownload: download,
    ),
  ));
  await tester.pumpAndSettle();
}

Future<void> _reach(WidgetTester tester, String id) async {
  final target = find.byKey(Key(id));
  await tester.scrollUntilVisible(target, 130,
    scrollable: find.descendant(
      of: find.byKey(const Key('deposit-details-scroll')),
      matching: find.byType(Scrollable)).first);
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}

void main() {
  setUp(DemoDepositRepository.clearLocalDeposits);

  testWidgets('Details use one record and reused information table',
      (tester) async {
    final original = _record();
    await _show(tester, original, _Repository(original));
    expect(find.text('Deposits'), findsOneWidget);
    expect(find.byKey(const Key('deposit-detail-summary')), findsOneWidget);
    expect(find.byKey(const Key('deposit-detail-amount')), findsOneWidget);
    expect(find.text('CHF 78.80'), findsWidgets);
    expect(find.byKey(const Key('deposit-details-table')), findsOneWidget);
    expect(find.text('TRX-2026-0098'), findsOneWidget);
    expect(find.text('Bank transfer'), findsOneWidget);
    expect(find.text('Received'), findsWidgets);
    expect(find.text('Received Date'), findsNothing);
    expect(find.text('Received By'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Receipt and history tabs never invent attached data',
      (tester) async {
    final record = _record();
    await _show(tester, record, _Repository(record));
    await tester.tap(find.byKey(const Key('details-tab-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('deposit-receipts-empty')), findsOneWidget);
    await tester.tap(find.byKey(const Key('details-tab-2')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('deposit-history-empty')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Attached receipt supports preview, download and share',
      (tester) async {
    final bytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/SqsAAAAASUVORK5CYII=');
    final image = LocalJobPhotoSelection(
      name: 'receipt.png', bytes: bytes, sourceKey: 'receipt-1');
    var shared = 0, downloaded = 0;
    final record = _record(photos: [image]);
    await _show(tester, record, _Repository(record),
      share: (photo) async {
        expect(photo.sourceKey, 'receipt-1');
        shared++;
      }, download: (photo) async {
        expect(photo.name, 'receipt.png');
        downloaded++;
        return true;
      });
    await tester.tap(find.byKey(const Key('details-tab-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('deposit-receipt-0')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('deposit-receipt-close')), findsOneWidget);
    await tester.tap(find.byKey(const Key('deposit-receipt-close')));
    await tester.pumpAndSettle();
    await _reach(tester, 'deposit-receipt-share-0');
    await tester.tap(find.byKey(const Key('deposit-receipt-share-0')));
    await tester.pumpAndSettle();
    await _reach(tester, 'deposit-receipt-download-0');
    await tester.tap(find.byKey(const Key('deposit-receipt-download-0')));
    await tester.pumpAndSettle();
    expect(shared, 1);
    expect(downloaded, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Delete requires confirmation and updates repository only then',
      (tester) async {
    final record = _record(status:DepositStatus.pending);
    final repo = _Repository(record);
    await _show(tester, record, repo);
    await _reach(tester, 'deposit-detail-delete');
    await tester.tap(find.byKey(const Key('deposit-detail-delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel').last);
    await tester.pumpAndSettle();
    expect(repo.deletes, 0);
    await tester.tap(find.byKey(const Key('deposit-detail-delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('deposit-confirm-delete')));
    await tester.pumpAndSettle();
    expect(repo.deletes, 1);
    expect(repo.record, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Pending deposit requires explicit manual receipt confirmation',
      (tester) async {
    final original=_record(status:DepositStatus.pending);
    final repo=_Repository(original);
    await _show(tester,original,repo);
    await _reach(tester,'deposit-detail-refund');
    expect(find.text('Mark Received'),findsOneWidget);
    await tester.tap(find.byKey(const Key('deposit-detail-refund')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel').last);
    await tester.pumpAndSettle();
    expect(repo.receives,0);
    await tester.tap(find.byKey(const Key('deposit-detail-refund')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('deposit-confirm-receive')));
    await tester.pumpAndSettle();
    expect(repo.record!.status,DepositStatus.received);
    expect(repo.receives,1);
    expect(tester.takeException(),isNull);
  });

  testWidgets('Refund only after confirmation and successful update',
      (tester) async {
    final original = _record();
    final repo = _Repository(original)..fail = true;
    await _show(tester, original, repo);
    await _reach(tester, 'deposit-detail-refund');
    await tester.tap(find.byKey(const Key('deposit-detail-refund')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel').last);
    await tester.pumpAndSettle();
    expect(repo.refunds, 0);
    await tester.tap(find.byKey(const Key('deposit-detail-refund')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('deposit-confirm-refund')));
    await tester.pumpAndSettle();
    expect(repo.record!.status, DepositStatus.received);
    expect(find.textContaining('not changed'), findsOneWidget);
    repo.fail = false;
    await tester.tap(find.byKey(const Key('deposit-detail-refund')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('deposit-confirm-refund')));
    await tester.pumpAndSettle();
    expect(repo.record!.status, DepositStatus.refunded);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Edit opens existing Create Deposit populated without ID change',
      (tester) async {
    final record = _record(status:DepositStatus.pending);
    await _show(tester, record, _Repository(record));
    await _reach(tester, 'deposit-detail-edit');
    await tester.tap(find.byKey(const Key('deposit-detail-edit')));
    await tester.pumpAndSettle();
    final form = tester.widget<AddDepositScreen>(
      find.byType(AddDepositScreen));
    expect(form.initialDeposit?.id, record.id);
    expect(form.initialDeposit?.amount, record.amount);
    await tester.scrollUntilVisible(
      find.byKey(const Key('deposit-form-save')), 130,
      scrollable: find.descendant(
        of: find.byKey(const Key('deposit-entry-form-scroll')),
        matching: find.byType(Scrollable)).first);
    await tester.pumpAndSettle();
    expect(find.text('Save Changes'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('Local repository records edit/refund and keeps status consistent',
      () async {
    const repo = DemoDepositRepository();
    await repo.saveDeposit(DepositRecord(
      id: 'new-one', title: 'Riverside Villa',
      clientName: 'Jean Dupont', amount: 12,
      date: DateTime(2026, 8, 23), status: DepositStatus.pending,
      jobId: 'labour-demo-riverside', paymentMethod: 'Bank transfer'));
    var saved = (await repo.listDeposits()).singleWhere(
      (item) => item.id == 'new-one');
    expect(saved.history.single.title, 'Deposit created');
    saved = await repo.updateDeposit(saved.copyWith(amount: 14));
    expect(saved.amount, 14);
    expect(saved.history.last.title, 'Deposit updated');
    await expectLater(repo.refundDeposit('new-one'), throwsStateError);
    final received = (await repo.listDeposits()).firstWhere(
      (item) => item.status == DepositStatus.received);
    final refunded = await repo.refundDeposit(received.id);
    expect(refunded.status, DepositStatus.refunded);
    expect(refunded.history.single.title, 'Deposit refunded');
    await repo.deleteDeposit('new-one');
    expect((await repo.listDeposits()).any(
      (item) => item.id == 'new-one'), isFalse);
  });

  testWidgets('Deposits listing opens actual Deposit Details route',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: DepositsScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('deposit-card-demo-deposit-1')));
    await tester.pumpAndSettle();
    expect(find.byType(DepositDetailsScreen), findsOneWidget);
    expect(find.text('Deposits'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final size in [
    const Size(320, 568), const Size(390, 844),
    const Size(768, 1024), const Size(1024, 768),
  ]) {
    testWidgets('Deposit Details tabs and actions fit at $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final record = _record();
      await _show(tester, record, _Repository(record));
      await tester.ensureVisible(find.byKey(const Key('details-tab-2')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('details-tab-2')));
      await tester.pumpAndSettle();
      await _reach(tester, 'deposit-detail-edit');
      expect(find.byKey(const Key('deposit-detail-delete')), findsOneWidget);
      expect(find.byKey(const Key('deposit-detail-refund')), findsOneWidget);
      expect(tester.takeException(), isNull, reason: '$size');
    });
  }
}
