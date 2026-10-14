import '../domain/deposit_record.dart';

/// UI-only reference records until a Laravel deposit repository is connected.
class DemoDepositRepository implements DepositRepository {
  const DemoDepositRepository();

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
      ]);
