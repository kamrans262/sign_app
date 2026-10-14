import '../domain/deposit_record.dart';

/// UI-only reference records until a Laravel deposit repository is connected.
class DemoDepositRepository extends DepositRepository {
  const DemoDepositRepository();

  static final Map<String, DepositRecord> _saved = {};
  static final Set<String> _deleted = {};

  static void clearLocalDeposits() {
    _saved.clear();
    _deleted.clear();
  }

  @override
  Future<List<DepositRecord>> listDeposits() async =>
      List<DepositRecord>.unmodifiable([
        for (var index = 1; index <= 4; index++)
          if (!_deleted.contains('demo-deposit-$index')) DepositRecord(
            id: 'demo-deposit-$index',
            title: 'Riverside Villa',
            clientName: 'Jean Dupont',
            amount: 78.80,
            date: DateTime(2026, 8, 23),
            status: DepositStatus.received,
            jobReference: 'JOB-L-001',
          ),
        ..._saved.values,
      ]);

  @override
  Future<void> saveDeposit(DepositRecord deposit) async {
    if (deposit.id.trim().isEmpty || !deposit.demoOnly ||
        deposit.status != DepositStatus.pending ||
        deposit.title.trim().isEmpty || deposit.clientName.trim().isEmpty ||
        deposit.jobId?.trim().isEmpty != false ||
        deposit.date.year < 2000 || deposit.date.year > 2100 ||
        !deposit.amount.isFinite || deposit.amount <= 0 ||
        deposit.amount > 999999999 ||
        deposit.paymentMethod.trim().isEmpty) {
      throw ArgumentError('Invalid pending deposit.');
    }
    if (_saved.containsKey(deposit.id) ||
        List.generate(4, (index) => 'demo-deposit-${index + 1}')
            .contains(deposit.id)) {
      throw StateError('Deposit already exists.');
    }
    final now = DateTime.now();
    _saved[deposit.id] = deposit.copyWith(history: [
      ...deposit.history,
      DepositHistoryEvent(
        id: 'created-${now.microsecondsSinceEpoch}',
        title: 'Deposit created', occurredAt: now),
    ]);
  }

  @override
  Future<DepositRecord> updateDeposit(DepositRecord updated) async {
    final records = await listDeposits();
    DepositRecord? original;
    for (final item in records) {
      if (item.id == updated.id) { original = item; break; }
    }
    if (original == null ||
        original.status != updated.status ||
        original.receivedAt != updated.receivedAt ||
        original.refundedAt != updated.refundedAt ||
        original.receivedBy != updated.receivedBy ||
        original.status == DepositStatus.refunded ||
        !updated.demoOnly || updated.title.trim().isEmpty ||
        updated.clientName.trim().isEmpty ||
        !updated.amount.isFinite || updated.amount <= 0 ||
        updated.amount > 999999999 ||
        updated.paymentMethod.trim().isEmpty) {
      throw StateError('Invalid or ineligible deposit update.');
    }
    final now = DateTime.now();
    final saved = updated.copyWith(history: [
      ...original.history,
      DepositHistoryEvent(
        id: 'updated-${now.microsecondsSinceEpoch}',
        title: 'Deposit updated', occurredAt: now),
    ]);
    _saved[saved.id] = saved;
    return saved;
  }

  @override
  Future<void> deleteDeposit(String id) async {
    if (!(await listDeposits()).any((item) => item.id == id)) {
      throw StateError('Deposit not found.');
    }
    _saved.remove(id);
    _deleted.add(id);
  }

  @override
  Future<DepositRecord> refundDeposit(String id) async {
    final records = await listDeposits();
    DepositRecord? original;
    for (final item in records) {
      if (item.id == id) { original = item; break; }
    }
    if (original == null || original.status != DepositStatus.received) {
      throw StateError('Only received deposits can be refunded.');
    }
    final now = DateTime.now();
    final result = original.copyWith(
      status: DepositStatus.refunded,
      refundedAt: now,
      history: [
        ...original.history,
        DepositHistoryEvent(
          id: 'refunded-${now.microsecondsSinceEpoch}',
          title: 'Deposit refunded', occurredAt: now,
          description: 'Local demo refund; no bank transaction performed.'),
      ],
    );
    _saved[result.id] = result;
    return result;
  }
}
