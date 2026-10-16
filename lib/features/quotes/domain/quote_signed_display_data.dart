import 'dart:typed_data';

/// Information confirmed by a trusted signing service, not created by the UI.
/// signedPdfBytes, when present, must be the finalized PDF from that service.
class QuoteSignedDisplayData {
  const QuoteSignedDisplayData({
    required this.documentId,
    required this.quoteNumber,
    required this.projectName,
    required this.signerName,
    required this.signedAt,
    this.ipAddress,
    this.demoOnly = false,
    this.quoteId,
    this.jobId,
    this.signedPdfBytes,
  });

  final String documentId;
  final String quoteNumber;
  final String projectName;
  final String signerName;
  final DateTime signedAt;
  final String? ipAddress;
  final bool demoOnly;
  final String? quoteId;
  final String? jobId;
  final Uint8List? signedPdfBytes;
}
