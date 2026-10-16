import 'dart:typed_data';

import '../domain/quote_review_models.dart';
import '../domain/quote_signed_display_data.dart';

/// The browser cannot write to the native app's job document directory.
/// Authoritative storage must be handled by the trusted signing API.
class SavedSignedQuoteFile {
  const SavedSignedQuoteFile({
    required this.documentId,
    required this.quoteId,
    required this.quoteNumber,
    required this.jobId,
    required this.signedAt,
    required this.fileName,
  });
  final String documentId;
  final String quoteId;
  final String quoteNumber;
  final String jobId;
  final DateTime signedAt;
  final String fileName;
}

class SignedQuoteFileStore {
  SignedQuoteFileStore();
  static final SignedQuoteFileStore shared = SignedQuoteFileStore();

  static bool isPdf(Uint8List bytes) =>
      bytes.length >= 5 &&
      bytes[0] == 0x25 && bytes[1] == 0x50 &&
      bytes[2] == 0x44 && bytes[3] == 0x46 && bytes[4] == 0x2d;

  Future<List<SavedSignedQuoteFile>> list() async => const [];
  Future<List<SavedSignedQuoteFile>> forJob(String jobId) async => const [];
  Future<Uint8List> read(SavedSignedQuoteFile record) async =>
      throw UnsupportedError('Signed PDF storage is server-managed on web.');

  /// An HTTPS service stores and finalizes the signed PDF; the browser
  /// intentionally never claims to have cached an immutable job copy.
  Future<bool> storeVerified(
    QuoteReviewDraft quote,
    QuoteSignedDisplayData receipt,
  ) async {
    if (receipt.signedPdfBytes != null &&
        !isPdf(receipt.signedPdfBytes!)) {
      throw const FormatException('Invalid signed PDF.');
    }
    return false;
  }
}
