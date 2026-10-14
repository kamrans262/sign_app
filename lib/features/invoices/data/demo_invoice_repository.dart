import '../domain/invoice_record.dart';

/// Session-local reference records. Not actual remote payment confirmations.
class DemoInvoiceRepository extends InvoiceRepository {
  DemoInvoiceRepository();

  static final Map<String, InvoiceRecord> _saved = {};
  static void clearLocalChanges() => _saved.clear();

  static final List<InvoiceRecord> _examples = List.unmodifiable([
    InvoiceRecord(
      id: 'invoice-demo-paid-1', number: 'INV-2026-0098',
      project: 'Riverside Villa', clientName: 'John Smith',
      amount: 78.80, date: DateTime(2026, 8, 23),
      status: InvoiceStatus.paid),
    InvoiceRecord(
      id: 'invoice-demo-pending-1', number: 'INV-2026-0099',
      project: 'Riverside Villa', clientName: 'John Smith',
      amount: 78.80, date: DateTime(2026, 8, 22),
      status: InvoiceStatus.pending),
    InvoiceRecord(
      id: 'invoice-demo-paid-2', number: 'INV-2026-0100',
      project: 'Riverside Villa', clientName: 'John Smith',
      amount: 78.80, date: DateTime(2026, 8, 21),
      status: InvoiceStatus.paid),
    InvoiceRecord(
      id: 'invoice-demo-sent-1', number: 'INV-2026-0101',
      project: 'Site renovation', clientName: 'Jean Dupont',
      amount: 540.25, date: DateTime(2026, 8, 20),
      status: InvoiceStatus.sent),
    InvoiceRecord(
      id: 'invoice-demo-overdue-1', number: 'INV-2026-0102',
      project: 'Riverside Villa', clientName: 'Jean Dupont',
      amount: 186.00, date: DateTime(2026, 7, 10),
      status: InvoiceStatus.overdue),
    InvoiceRecord(
      id: 'invoice-demo-draft-1', number: 'INV-2026-0103',
      project: 'Site renovation', clientName: 'John Smith',
      amount: 92.00, date: DateTime(2026, 8, 19),
      status: InvoiceStatus.draft),
  ]);

  @override
  Future<List<InvoiceRecord>> listInvoices() async => [
    for (final original in _examples) _saved[original.id] ?? original,
    for (final record in _saved.values)
      if (!_examples.any((example) => example.id == record.id)) record,
  ];

  @override
  Future<InvoiceRecord> markAsPaid(String invoiceId) async {
    final records = await listInvoices();
    InvoiceRecord? current;
    for (final invoice in records) {
      if (invoice.id == invoiceId) {
        current = invoice;
        break;
      }
    }
    if (current == null) { throw StateError('Invoice not found.'); }
    if (!current.status.canMarkPaid) {
      throw StateError('Only sent, pending or overdue invoices can be marked paid.');
    }
    final updated = current.withStatus(
      InvoiceStatus.paid, paidAt: DateTime.now());
    _saved[invoiceId] = updated;
    return updated;
  }

  @override
  Future<void> saveDraft(InvoiceRecord invoice) async {
    if (invoice.id.trim().isEmpty || invoice.number.trim().isEmpty ||
        invoice.project.trim().isEmpty || invoice.clientName.trim().isEmpty ||
        invoice.status != InvoiceStatus.draft ||
        !invoice.amount.isFinite || invoice.amount <= 0 ||
        invoice.amount > 999999999 ||
        (await listInvoices()).any((item) =>
            item.id == invoice.id || item.number == invoice.number)) {
      throw ArgumentError('Invalid or duplicate invoice draft.');
    }
    _saved[invoice.id] = invoice;
  }
}
