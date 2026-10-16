/// Authorization identifiers issued by the trusted signing-request service.
/// A client record or a share-sheet action cannot create these values.
class QuoteSigningContext {
  const QuoteSigningContext({
    required this.documentId,
    required this.signerId,
    required this.documentVersion,
    required this.consentReference,
  });

  final String documentId;
  final String signerId;
  final String documentVersion;
  final String consentReference;
}
