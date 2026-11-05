import '../../jobs/data/local_job_photo_source.dart';
import '../../quotes/domain/quote_review_models.dart';

enum InvoiceStatus {
  draft('Draft'), sent('Sent'), pending('Payment Pending'),
  paid('Paid'), overdue('Overdue'),
  partiallyPaid('Partially Paid'), voided('Voided');

  const InvoiceStatus(this.label);
  final String label;
  bool get canMarkPaid =>
      this == InvoiceStatus.sent || this == InvoiceStatus.pending ||
      this == InvoiceStatus.overdue ||
      this == InvoiceStatus.partiallyPaid;
}

/// Minor currency units for precise invoice calculations.
class InvoiceLineItem {
  const InvoiceLineItem({
    required this.description,
    required this.quantity,
    this.unitPriceMinor,
  });
  final String description;
  final int quantity;
  /// Null is unpriced, distinct from zero.
  final int? unitPriceMinor;
  int? get totalMinor => unitPriceMinor == null
      ? null : quantity * unitPriceMinor!;

  bool get valid => description.trim().isNotEmpty &&
      quantity > 0 && quantity <= 100000 &&
      (unitPriceMinor == null ||
          (unitPriceMinor! >= 0 && unitPriceMinor! <= 99999999999));
}

/// A recorded payment associated with this exact invoice.
class InvoicePaymentRecord {
  const InvoicePaymentRecord({
    required this.id,
    required this.amountMinor,
    required this.paidAt,
    required this.method,
    required this.status,
    this.referenceNumber,
  });
  final String id, method, status;
  final int amountMinor;
  final DateTime paidAt;
  final String? referenceNumber;
}

/// Only recorded events appear in Invoice History.
class InvoiceHistoryEvent {
  const InvoiceHistoryEvent({
    required this.id,
    required this.title,
    required this.occurredAt,
    this.description,
  });
  final String id, title;
  final DateTime occurredAt;
  final String? description;
}

class InvoiceRecord {
  const InvoiceRecord({
    required this.id, required this.number, required this.project,
    required this.clientName, required this.amount, required this.date,
    required this.status, this.jobId, this.manuallyPaidAt,
    this.demoOnly = true,
    this.iban = '', this.dueDate, this.notes = '',
    this.currency = 'CHF', this.vatBasisPoints = 0,
    this.depositPaidMinor = 0, this.items = const [],
    this.payments = const [], this.history = const [], this.sentAt,
    this.billingAddress = '', this.clientEmail = '',
    this.clientPhone = '', this.terms = '', this.payment,
    this.photos = const [],
    this.lockVersion = 0, this.invoiceType = 'final',
    this.sourceQuoteId, this.lifecycleStatus = 'draft',
  });

  final String id, number, project, clientName;
  final String? jobId;
  final double amount;
  /// Existing issue/invoice date.
  final DateTime date;
  final InvoiceStatus status;
  final DateTime? manuallyPaidAt;
  final bool demoOnly;
  final String iban, notes, currency;
  final DateTime? dueDate;
  final int vatBasisPoints;
  final int depositPaidMinor;
  final List<InvoiceLineItem> items;
  final List<InvoicePaymentRecord> payments;
  final List<InvoiceHistoryEvent> history;
  final DateTime? sentAt;
  final String billingAddress, clientEmail, clientPhone, terms;
  final QuotePaymentDetails? payment;
  final List<LocalJobPhotoSelection> photos;
  final int lockVersion;
  final String invoiceType, lifecycleStatus;
  final int? sourceQuoteId;

  int get receivedMinor => payments.where((p) =>
      p.status.toLowerCase() == 'paid').fold<int>(0,
      (sum, payment) => sum + payment.amountMinor);

  String get formattedAmount => quoteMoney((amount * 100).round(), currency);

  bool matches(String text) {
    final query = text.trim().toLowerCase();
    if (query.isEmpty) { return true; }
    return [number, project, clientName, formattedAmount, status.label]
        .any((part) => part.toLowerCase().contains(query));
  }

  /// Incomplete items do not masquerade as priced zero-valued items.
  int? get subtotalMinor => items.isEmpty ||
      items.any((item) => !item.valid || item.totalMinor == null)
      ? null
      : items.fold<int>(0, (sum, item) => sum + item.totalMinor!);
  int? get vatMinor => subtotalMinor == null
      ? null : percentOfMinor(subtotalMinor!, vatBasisPoints);
  int? get totalMinor => subtotalMinor == null
      ? null : subtotalMinor! + vatMinor!;
  int? get amountDueMinor => totalMinor == null
      ? null : (totalMinor! - depositPaidMinor - receivedMinor)
          .clamp(0, totalMinor!).toInt();

  /// Preserves all invoice accounting fields when attachments are edited.
  InvoiceRecord withPhotos(List<LocalJobPhotoSelection> next) =>
      InvoiceRecord(
        id: id, number: number, project: project,
        clientName: clientName, amount: amount, date: date,
        status: status, jobId: jobId, demoOnly: demoOnly,
        manuallyPaidAt: manuallyPaidAt, iban: iban,
        dueDate: dueDate, notes: notes, currency: currency,
        vatBasisPoints: vatBasisPoints, depositPaidMinor: depositPaidMinor,
        items: items, payments: payments, history: history, sentAt: sentAt,
        billingAddress: billingAddress, clientEmail: clientEmail,
        clientPhone: clientPhone, terms: terms, payment: payment,
        photos: List<LocalJobPhotoSelection>.unmodifiable(next),
        lockVersion: lockVersion, invoiceType: invoiceType,
        sourceQuoteId: sourceQuoteId, lifecycleStatus: lifecycleStatus,
      );

  InvoiceRecord withStatus(InvoiceStatus next, {DateTime? paidAt}) =>
      InvoiceRecord(
        id: id, number: number, project: project,
        clientName: clientName, amount: amount, date: date,
        status: next, jobId: jobId, demoOnly: demoOnly,
        manuallyPaidAt: paidAt ?? manuallyPaidAt,
        iban: iban, dueDate: dueDate, notes: notes,
        currency: currency, vatBasisPoints: vatBasisPoints,
        depositPaidMinor: depositPaidMinor, items: items,
        payments: payments, history: history, sentAt: sentAt,
        billingAddress: billingAddress, clientEmail: clientEmail,
        clientPhone: clientPhone, terms: terms, payment: payment,
        photos: photos,
        lockVersion: lockVersion, invoiceType: invoiceType,
        sourceQuoteId: sourceQuoteId, lifecycleStatus: lifecycleStatus,
      );
}

abstract class InvoiceRepository {
  const InvoiceRepository();
  Future<List<InvoiceRecord>> listInvoices();
  Future<InvoiceRecord> markAsPaid(String invoiceId);
  Future<InvoiceRecord> approveInvoice(String id) =>
      Future<InvoiceRecord>.error(
        UnsupportedError('Invoice approval is unavailable.'));
  Future<InvoiceRecord> invoiceDetail(String id) =>
      Future<InvoiceRecord>.error(
        UnsupportedError('Invoice details are unavailable.'));

  Future<InvoiceRecord> updateAttachments(String invoiceId,
      List<LocalJobPhotoSelection> photos) =>
      Future<InvoiceRecord>.error(
        UnsupportedError('Invoice attachments are unavailable.'));

  Future<InvoiceRecord> updateInvoice(InvoiceRecord updated) =>
      Future<InvoiceRecord>.error(
        UnsupportedError('Invoice editing is unavailable.'));

  Future<void> saveDraft(InvoiceRecord invoice) =>
      Future<void>.error(UnsupportedError('Invoice creation is not available.'));
}

/// Standard IBAN modulo-97 validation, without inventing company settings.
bool isValidInvoiceIban(String raw) {
  final value = raw.replaceAll(RegExp(r'\s+'), '').toUpperCase();
  if (value.length < 15 || value.length > 34 ||
      !RegExp(r'^[A-Z]{2}[0-9]{2}[A-Z0-9]+$').hasMatch(value)) {
    return false;
  }
  final rearranged = value.substring(4) + value.substring(0, 4);
  var remainder = 0;
  for (final rune in rearranged.runes) {
    final digits = rune >= 65 && rune <= 90
        ? (rune - 55).toString() : String.fromCharCode(rune);
    for (final digit in digits.codeUnits) {
      remainder = (remainder * 10 + digit - 48) % 97;
    }
  }
  return remainder == 1;
}
