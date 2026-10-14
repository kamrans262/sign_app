enum InvoiceStatus {
  draft('Draft'),
  sent('Sent'),
  pending('Payment Pending'),
  paid('Paid'),
  overdue('Overdue');

  const InvoiceStatus(this.label);
  final String label;
  bool get canMarkPaid =>
      this == InvoiceStatus.sent || this == InvoiceStatus.pending ||
      this == InvoiceStatus.overdue;
}

class InvoiceRecord {
  const InvoiceRecord({
    required this.id, required this.number, required this.project,
    required this.clientName, required this.amount, required this.date,
    required this.status, this.jobId, this.manuallyPaidAt,
    this.demoOnly = true,
  });

  final String id, number, project, clientName;
  final String? jobId;
  final double amount;
  final DateTime date;
  final InvoiceStatus status;
  final DateTime? manuallyPaidAt;
  final bool demoOnly;

  String get formattedAmount => 'CHF ${amount.toStringAsFixed(2)}';

  bool matches(String text) {
    final query = text.trim().toLowerCase();
    if (query.isEmpty) { return true; }
    return [number, project, clientName, formattedAmount, status.label]
        .any((part) => part.toLowerCase().contains(query));
  }

  InvoiceRecord withStatus(InvoiceStatus next, {DateTime? paidAt}) =>
      InvoiceRecord(
        id: id, number: number, project: project,
        clientName: clientName, amount: amount, date: date,
        status: next, jobId: jobId, demoOnly: demoOnly,
        manuallyPaidAt: paidAt ?? manuallyPaidAt,
      );
}

abstract class InvoiceRepository {
  Future<List<InvoiceRecord>> listInvoices();
  Future<InvoiceRecord> markAsPaid(String invoiceId);

  Future<void> saveDraft(InvoiceRecord invoice) =>
      Future<void>.error(UnsupportedError('Invoice creation is not available.'));
}
