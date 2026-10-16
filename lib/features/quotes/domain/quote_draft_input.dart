/// Source information gathered by Create Quote. This is NOT an AI-generated
/// quote, invoice, priced line item, or saved document.
enum QuoteInputMethod { voice, text, handwrittenPhoto }

class QuoteDraftInput {
  const QuoteDraftInput({
    required this.method,
    required this.createdAt,
    this.clientId,
    this.jobId,
    this.companyId,
    this.clientName,
    this.clientEmail,
    this.clientPhone,
    this.clientAddress,
    this.sourceNoteId,
    this.description,
    this.audioPath,
    this.photoPath,
  });

  final QuoteInputMethod method;
  final DateTime createdAt;
  final String? clientId;
  final String? jobId;
  /// The currently selected issuing company, when known.
  final String? companyId;
  final String? clientName;
  final String? clientEmail;
  final String? clientPhone;
  final String? clientAddress;
  final String? sourceNoteId;
  final String? description;
  final String? audioPath;
  final String? photoPath;
}
