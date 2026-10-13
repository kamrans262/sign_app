import 'quote_review_models.dart';

/// The most recently opened quote in this app session.
///
/// This does not prove document delivery or create a signature request.
/// It is only used to show the selected quote in the Home tracking view.
class QuoteTrackingHomeSession {
  QuoteTrackingHomeSession._();

  static QuoteReviewDraft? _currentQuote;

  static QuoteReviewDraft? get currentQuote => _currentQuote?.copy();

  static void remember(QuoteReviewDraft quote) {
    _currentQuote = quote.copy();
  }

  static void clear() {
    _currentQuote = null;
  }
}
