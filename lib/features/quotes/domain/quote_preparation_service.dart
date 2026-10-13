import 'quote_draft_input.dart';
import 'quote_extraction_models.dart';

/// A future OpenAI/Laravel adapter can supply real progress and extraction.
/// Subscribe only after source input is collected and validated.
abstract interface class QuotePreparationService {
  Stream<QuotePreparationSnapshot> prepare(QuoteDraftInput input);
}
