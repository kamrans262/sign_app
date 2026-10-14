import '../domain/invoice_record.dart';

/// Session-local reference records. Not actual remote payment confirmations.
class DemoInvoiceRepository extends InvoiceRepository {
  const DemoInvoiceRepository();

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
    final now = DateTime.now();
    // Manually marked paid is a local accounting assertion, not a bank event.
    final minor = (current.amount * 100).round();
    final remaining = (minor - current.depositPaidMinor -
        current.receivedMinor).clamp(0, minor).toInt();
    final updated = InvoiceRecord(
      id: current.id, number: current.number,
      project: current.project, clientName: current.clientName,
      amount: current.amount, date: current.date, status: InvoiceStatus.paid,
      jobId: current.jobId, manuallyPaidAt: now,
      demoOnly: current.demoOnly, iban: current.iban,
      dueDate: current.dueDate, notes: current.notes,
      currency: current.currency, vatBasisPoints: current.vatBasisPoints,
      depositPaidMinor: current.depositPaidMinor, items: current.items,
      sentAt: current.sentAt,
      payments: [
        ...current.payments,
        if (remaining > 0)
          InvoicePaymentRecord(
            id: 'manual-${current.id}-${now.microsecondsSinceEpoch}',
            amountMinor: remaining, paidAt: now,
            method: 'Manual record', status: 'Paid',
          ),
      ],
      history: [
        ...current.history,
        InvoiceHistoryEvent(
          id: 'marked-paid-${now.microsecondsSinceEpoch}',
          title: 'Invoice marked paid', occurredAt: now,
          description: 'Locally recorded manual payment status',
        ),
      ],
    );
    _saved[invoiceId] = updated;
    return updated;
  }

  @override
  Future<InvoiceRecord> updateInvoice(InvoiceRecord next) async {
    final records = await listInvoices();
    InvoiceRecord? original;
    for (final item in records) {
      if (item.id == next.id) { original = item; break; }
    }
    if (original == null) { throw StateError('Invoice not found.'); }
    if (original.status == InvoiceStatus.paid ||
        original.status != next.status ||
        next.number.trim().isEmpty || next.project.trim().isEmpty ||
        next.clientName.trim().isEmpty ||
        (await listInvoices()).any((item) =>
            item.id != next.id && item.number == next.number) ||
        !next.amount.isFinite || next.amount <= 0 ||
        next.items.isEmpty || next.totalMinor == null ||
        next.totalMinor != (next.amount * 100).round() ||
        next.dueDate == null || next.dueDate!.isBefore(next.date) ||
        !isValidInvoiceIban(next.iban)) {
      throw StateError('Invoice changes are not valid or editable.');
    }
    final now = DateTime.now();
    final updated = InvoiceRecord(
      id: original.id, number: next.number,
      project: next.project, clientName: next.clientName,
      amount: next.amount, date: next.date, status: original.status,
      jobId: next.jobId, dueDate: next.dueDate,
      iban: next.iban, notes: next.notes, currency: next.currency,
      vatBasisPoints: next.vatBasisPoints,
      depositPaidMinor: next.depositPaidMinor, items: next.items,
      sentAt: original.sentAt, manuallyPaidAt: original.manuallyPaidAt,
      demoOnly: original.demoOnly,
      payments: original.payments,
      history: [
        ...original.history,
        InvoiceHistoryEvent(id: 'edited-${now.microsecondsSinceEpoch}',
          title: 'Invoice updated', occurredAt: now),
      ],
    );
    _saved[updated.id] = updated;
    return updated;
  }

  @override
  Future<void> saveDraft(InvoiceRecord invoice) async {
    if (invoice.id.trim().isEmpty || invoice.number.trim().isEmpty ||
        invoice.project.trim().isEmpty || invoice.clientName.trim().isEmpty ||
        invoice.status != InvoiceStatus.draft ||
        !invoice.amount.isFinite || invoice.amount <= 0 ||
        invoice.amount > 999999999 ||
        (invoice.items.isNotEmpty && (
          invoice.totalMinor == null ||
          invoice.totalMinor != (invoice.amount * 100).round() ||
          invoice.dueDate == null ||
          invoice.dueDate!.isBefore(invoice.date) ||
          !isValidInvoiceIban(invoice.iban) ||
          invoice.vatBasisPoints < 0 ||
          invoice.vatBasisPoints > 10000
        )) ||
        (await listInvoices()).any((item) =>
            item.id == invoice.id || item.number == invoice.number)) {
      throw ArgumentError('Invalid or duplicate invoice draft.');
    }
    final now = DateTime.now();
    _saved[invoice.id] = InvoiceRecord(
      id: invoice.id, number: invoice.number,
      project: invoice.project, clientName: invoice.clientName,
      amount: invoice.amount, date: invoice.date,
      status: invoice.status, jobId: invoice.jobId,
      manuallyPaidAt: invoice.manuallyPaidAt,
      demoOnly: invoice.demoOnly, iban: invoice.iban,
      dueDate: invoice.dueDate, notes: invoice.notes,
      currency: invoice.currency, vatBasisPoints: invoice.vatBasisPoints,
      depositPaidMinor: invoice.depositPaidMinor, items: invoice.items,
      payments: invoice.payments, sentAt: invoice.sentAt,
      history: [
        ...invoice.history,
        InvoiceHistoryEvent(
          id: 'created-${now.microsecondsSinceEpoch}',
          title: 'Invoice created', occurredAt: now),
      ],
    );
  }
}
