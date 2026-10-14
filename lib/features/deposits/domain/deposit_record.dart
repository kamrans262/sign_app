import '../../jobs/data/local_job_photo_source.dart';

enum DepositStatus {
  pending('Pending'),
  received('Received'),
  refunded('Refunded');

  const DepositStatus(this.label);
  final String label;
}

/// CHF amounts and real status values when a live repository is connected.
class DepositRecord {
  const DepositRecord({
    required this.id,
    required this.title,
    required this.clientName,
    required this.amount,
    required this.date,
    required this.status,
    this.jobReference,
    this.jobId,
    this.paymentMethod = '',
    this.referenceNumber = '',
    this.notes = '',
    this.photos = const [],
    this.demoOnly = true,
  });

  final String id;
  final String title;
  final String clientName;
  final double amount;
  final DateTime date;
  final DepositStatus status;
  final String? jobReference;
  final String? jobId;
  final String paymentMethod;
  final String referenceNumber;
  final String notes;
  final List<LocalJobPhotoSelection> photos;
  final bool demoOnly;

  String get formattedAmount => 'CHF ${amount.toStringAsFixed(2)}';

  bool matches(String input) {
    final query = input.trim().toLowerCase();
    if (query.isEmpty) { return true; }
    return [
      id, title, clientName, status.label, formattedAmount,
      paymentMethod, referenceNumber, notes,
      ?jobReference,
    ].any((value) => value.toLowerCase().contains(query));
  }
}

abstract class DepositRepository {
  Future<List<DepositRecord>> listDeposits();

  Future<void> saveDeposit(DepositRecord deposit) =>
      Future<void>.error(UnsupportedError('Deposit saving is unavailable.'));
}
