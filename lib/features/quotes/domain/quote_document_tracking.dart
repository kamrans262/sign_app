/// Verified document activity only. A native share sheet is not a send receipt.
enum QuoteDocumentEventType {
  quoteCreated,
  documentSent,
  documentViewed,
  signatureRequested,
  documentSigned,
  documentCompleted,
  reminderSent,
}

class QuoteDocumentEvent {
  const QuoteDocumentEvent({
    required this.id,
    required this.type,
    required this.occurredAt,
  });

  final String id;
  final QuoteDocumentEventType type;
  final DateTime occurredAt;

  String get title => switch (type) {
    QuoteDocumentEventType.quoteCreated => 'Quote Created',
    QuoteDocumentEventType.documentSent => 'Document Sent',
    QuoteDocumentEventType.documentViewed => 'Document Viewed',
    QuoteDocumentEventType.signatureRequested => 'Signature Requested',
    QuoteDocumentEventType.documentSigned => 'Document Signed',
    QuoteDocumentEventType.documentCompleted => 'Completed',
    QuoteDocumentEventType.reminderSent => 'Reminder Sent',
  };
}

class QuoteDocumentTracking {
  const QuoteDocumentTracking({
    required this.quoteId,
    this.requestId,
    this.secureUrl,
    this.expiresAt,
    this.events = const [],
  });

  final String quoteId;
  final String? requestId;
  final Uri? secureUrl;
  final DateTime? expiresAt;
  final List<QuoteDocumentEvent> events;

  DateTime? timeOf(QuoteDocumentEventType type) {
    final matches = events.where((event) => event.type == type).toList()
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    return matches.isEmpty ? null : matches.first.occurredAt;
  }

  bool get sent => timeOf(QuoteDocumentEventType.documentSent) != null;
  bool get viewed => timeOf(QuoteDocumentEventType.documentViewed) != null;
  bool get signed => timeOf(QuoteDocumentEventType.documentSigned) != null;
  bool get completed => timeOf(QuoteDocumentEventType.documentCompleted) != null;

  bool get requestIsActive => requestId != null && sent && !signed && !completed;

  Uri? usableUrl(DateTime now) {
    final url = secureUrl;
    if (url == null || url.scheme != 'https' || url.host.isEmpty) return null;
    if (expiresAt != null && !now.isBefore(expiresAt!)) return null;
    return url;
  }

  List<QuoteDocumentEvent> get latestFirst => List.of(events)
    ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));

  QuoteDocumentTracking withEvent(QuoteDocumentEvent event) =>
      QuoteDocumentTracking(
        quoteId: quoteId,
        requestId: requestId,
        secureUrl: secureUrl,
        expiresAt: expiresAt,
        events: [...events, event],
      );

  /// Screenshot testing only, never used to claim real delivery.
  factory QuoteDocumentTracking.figmaFixture(String id) => QuoteDocumentTracking(
    quoteId: id,
    requestId: 'figma-only-request',
    events: [
      QuoteDocumentEvent(id: 'demo-created',
        type: QuoteDocumentEventType.quoteCreated,
        occurredAt: DateTime(2026, 8, 12, 9)),
      QuoteDocumentEvent(id: 'demo-sent',
        type: QuoteDocumentEventType.documentSent,
        occurredAt: DateTime(2026, 8, 12, 10, 15)),
      QuoteDocumentEvent(id: 'demo-viewed',
        type: QuoteDocumentEventType.documentViewed,
        occurredAt: DateTime(2026, 8, 12, 10, 25)),
    ],
  );
}

/// Local reminder preference, NOT a server-side scheduled reminder.
class QuoteReminderPreferences {
  QuoteReminderPreferences._();
  static final Map<String, bool> _enabled = {};
  static bool getEnabled(String quoteId) => _enabled[quoteId] ?? false;
  static void setEnabled(String quoteId, bool value) => _enabled[quoteId] = value;
  static void clear() => _enabled.clear();
}
