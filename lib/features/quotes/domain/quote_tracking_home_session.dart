import '../../../core/services/active_company_session.dart';
import 'quote_review_models.dart';
import 'quote_document_tracking.dart';

/// The most recently opened quote in this app session.
///
/// This does not prove document delivery or create a signature request.
/// It is only used to show the selected quote in the Home tracking view.
class QuoteTrackingHomeSession {
  QuoteTrackingHomeSession._();

  static QuoteReviewDraft? _currentQuote;
  static final Map<String, QuoteDocumentTracking> _tracking = {};
  static bool _listeningForCompanyChanges = false;

  static void _ensureCompanyIsolation() {
    if (_listeningForCompanyChanges) return;
    _listeningForCompanyChanges = true;
    ActiveCompanySession.selected.addListener(clear);
  }

  /// Retains only statuses explicitly returned by a connected service.
  /// It must not be called just because a native share sheet was opened.
  static void rememberVerifiedTracking(QuoteDocumentTracking tracking) {
    _ensureCompanyIsolation();
    _tracking[tracking.quoteId] = QuoteDocumentTracking(
      quoteId: tracking.quoteId,
      requestId: tracking.requestId,
      secureUrl: tracking.secureUrl,
      expiresAt: tracking.expiresAt,
      events: List<QuoteDocumentEvent>.unmodifiable(tracking.events),
    );
  }

  static QuoteDocumentTracking? trackingFor(String quoteId) {
    _ensureCompanyIsolation();
    return _tracking[quoteId];
  }

  static QuoteReviewDraft? get currentQuote {
    _ensureCompanyIsolation();
    return _currentQuote?.copy();
  }

  static void remember(QuoteReviewDraft quote) {
    _ensureCompanyIsolation();
    _currentQuote = quote.copy();
  }

  static void clear() {
    _currentQuote = null;
    _tracking.clear();
  }
}
