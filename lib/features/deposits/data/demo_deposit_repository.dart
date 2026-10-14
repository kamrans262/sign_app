import '../domain/deposit_record.dart';

/// UI-only reference records until a Laravel deposit repository is connected.
class DemoDepositRepository implements DepositRepository {
  const DemoDepositRepository();

  static final Map<String, DepositRecord> _saved = {};

  static void clearLocalDeposits() => _saved.clear();

  @override
  Future<List<DepositRecord>> listDeposits() async =>
      List<DepositRecord>.unmodifiable([
        for (var index = 1; index <= 4; index++)
          DepositRecord(
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
    _saved[deposit.id] = deposit;
  }
}
