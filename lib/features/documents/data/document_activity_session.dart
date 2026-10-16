import '../../quotes/domain/quote_review_models.dart';
import '../domain/document_record.dart';

/// Explicit actions from the current app session, not an authoritative
/// server audit trail. Verified delivery/views/signatures are sourced
/// separately from the signing service's event records.
abstract final class DocumentActivitySession {
  static final Map<String, List<DocumentHistoryEvent>> _history = {};
  static final Map<String, String> _savedContent = {};
  static final Map<String, String> _approvedContent = {};
  static final Map<String, int> _versions = {};

  static String _fingerprint(QuoteReviewDraft quote) => [
    quote.clientId ?? '', quote.jobId ?? '', quote.clientName,
    quote.quoteNumber, quote.date.toUtc().toIso8601String(),
    quote.validUntil?.toUtc().toIso8601String() ?? '',
    quote.terms, quote.currency, quote.billingAddress,
    quote.clientEmail, quote.clientPhone,
    quote.vatBasisPoints, quote.depositBasisPoints,
    for (final item in quote.items)
      [item.id, item.title, item.description, item.quantity,
        item.unitPrice, item.dimensions ?? ''].join('\u001f'),
  ].join('\u001e');

  static void _append(String id, DocumentHistoryType type,
      {String? description}) {
    final now = DateTime.now().toUtc();
    final events = _history.putIfAbsent(id, () => <DocumentHistoryEvent>[]);
    events.add(DocumentHistoryEvent(
      id: '${type.name}-${now.microsecondsSinceEpoch}-${events.length}',
      documentId: id, type: type, occurredAt: now,
      description: description,
    ));
  }

  static void saved(QuoteReviewDraft quote) {
    if (quote.isDemo || quote.id.isEmpty) return;
    final fingerprint = _fingerprint(quote);
    final previous = _savedContent[quote.id];
    if (previous == fingerprint) return;
    _savedContent[quote.id] = fingerprint;
    if (previous == null && !_history.containsKey(quote.id)) {
      _append(quote.id, DocumentHistoryType.created,
        description: 'Draft saved in this app session');
    } else {
      _append(quote.id, DocumentHistoryType.edited,
        description: 'Updated draft saved in this app session');
    }
  }

  static void approved(QuoteReviewDraft quote) {
    if (quote.isDemo || quote.id.isEmpty) return;
    saved(quote);
    final current = _fingerprint(quote);
    final previous = _approvedContent[quote.id];
    if (previous == current) return;
    final oldVersion = _versions[quote.id] ?? 0;
    _versions[quote.id] = oldVersion + 1;
    _approvedContent[quote.id] = current;
    if (oldVersion > 0) {
      _append(quote.id, DocumentHistoryType.versionChanged,
        description: 'Locally approved revision ${oldVersion + 1}; '
            'not a server-issued version');
    }
  }

  static void downloaded(String documentId, {bool demoOnly = false}) {
    if (documentId.isEmpty || demoOnly) return;
    _append(documentId, DocumentHistoryType.downloaded,
      description: 'PDF export completed on this device');
  }

  static void deliveryConfirmed(String quoteId) {
    if (quoteId.isEmpty) return;
    _append(quoteId, DocumentHistoryType.sent,
      description: 'Delivery confirmed by the connected sender');
  }

  static int versionFor(String quoteId) => _versions[quoteId] ?? 1;

  static List<DocumentHistoryEvent> forDocument(String documentId) =>
      List<DocumentHistoryEvent>.unmodifiable(_history[documentId] ?? []);

  static void clear() {
    _history.clear();
    _savedContent.clear();
    _approvedContent.clear();
    _versions.clear();
  }
}
