/// Source information gathered by Create Quote. This is NOT an AI-generated
/// quote, invoice, priced line item, or saved document.
enum QuoteInputMethod { voice, text, handwrittenPhoto }

class QuoteDraftInput {
  const QuoteDraftInput({
    required this.method,
    required this.createdAt,
    this.clientId,
    this.jobId,
    this.sourceNoteId,
    this.description,
    this.audioPath,
    this.photoPath,
  });

  final QuoteInputMethod method;
  final DateTime createdAt;
  final String? clientId;
  final String? jobId;
  final String? sourceNoteId;
  final String? description;
  final String? audioPath;
  final String? photoPath;
}
