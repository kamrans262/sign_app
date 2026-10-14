import '../../jobs/data/local_job_photo_source.dart';

class DepositHistoryEvent {
  const DepositHistoryEvent({
    required this.id, required this.title, required this.occurredAt,
    this.description,
  });
  final String id, title;
  final DateTime occurredAt;
  final String? description;
}

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
    this.history = const [],
    this.receivedBy,
    this.receivedAt,
    this.refundedAt,
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
  final List<DepositHistoryEvent> history;
  final String? receivedBy;
  final DateTime? receivedAt;
  final DateTime? refundedAt;
  final bool demoOnly;

  DepositRecord copyWith({
    String? title, String? clientName, double? amount, DateTime? date,
    DepositStatus? status, String? jobId, String? jobReference,
    String? paymentMethod, String? referenceNumber, String? notes,
    List<LocalJobPhotoSelection>? photos,
    List<DepositHistoryEvent>? history, String? receivedBy,
    DateTime? receivedAt, DateTime? refundedAt,
  }) => DepositRecord(
    id: id, title: title ?? this.title,
    clientName: clientName ?? this.clientName,
    amount: amount ?? this.amount, date: date ?? this.date,
    status: status ?? this.status, jobId: jobId ?? this.jobId,
    jobReference: jobReference ?? this.jobReference,
    paymentMethod: paymentMethod ?? this.paymentMethod,
    referenceNumber: referenceNumber ?? this.referenceNumber,
    notes: notes ?? this.notes, photos: photos ?? this.photos,
    history: history ?? this.history,
    receivedBy: receivedBy ?? this.receivedBy,
    receivedAt: receivedAt ?? this.receivedAt,
    refundedAt: refundedAt ?? this.refundedAt,
    demoOnly: demoOnly,
  );

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
  const DepositRepository();
  Future<List<DepositRecord>> listDeposits();

  Future<void> saveDeposit(DepositRecord deposit) =>
      Future<void>.error(UnsupportedError('Deposit saving is unavailable.'));

  Future<DepositRecord> updateDeposit(DepositRecord updated) =>
      Future<DepositRecord>.error(
          UnsupportedError('Deposit editing is unavailable.'));

  Future<void> deleteDeposit(String id) =>
      Future<void>.error(
          UnsupportedError('Deposit deletion is unavailable.'));

  Future<DepositRecord> refundDeposit(String id) =>
      Future<DepositRecord>.error(
          UnsupportedError('Deposit refunding is unavailable.'));
}
