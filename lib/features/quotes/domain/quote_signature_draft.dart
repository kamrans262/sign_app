import 'dart:typed_data';
import 'package:flutter/painting.dart';

enum QuoteSignatureMethod { draw, type, upload }

/// Unsubmitted capture. This is NOT a signed document or an audit record.
/// Authoritative signer verification and storage belong to a trusted service.
class QuoteSignatureDraft {
  const QuoteSignatureDraft({
    required this.quoteId,
    required this.documentId,
    required this.requestId,
    required this.signerId,
    required this.documentVersion,
    required this.consentReference,
    required this.method,
    required this.pngBytes,
    required this.capturedAt,
    required this.consentAccepted,
    this.typedName,
    this.normalizedStrokes = const [],
  });

  final String quoteId;
  final String documentId;
  final String requestId;
  final String signerId;
  final String documentVersion;
  final String consentReference;
  final QuoteSignatureMethod method;
  final Uint8List pngBytes;
  final DateTime capturedAt;
  final bool consentAccepted;
  final String? typedName;
  /// Each point lies in [0, 1] in both axes, independent of device size.
  final List<List<Offset>> normalizedStrokes;
}

/// Screen-only draft state. Kept in RAM, never written to logs or disk.
/// These drafts are lost when the app process exits.
class QuoteSignatureLocalDraft {
  QuoteSignatureLocalDraft({
    this.method = QuoteSignatureMethod.draw,
    this.typedName = '',
    this.uploadBytes,
    this.uploadName,
    List<List<Offset>>? strokes,
  }) : strokes = strokes ?? <List<Offset>>[];

  QuoteSignatureMethod method;
  String typedName;
  Uint8List? uploadBytes;
  String? uploadName;
  List<List<Offset>> strokes;
}

class QuoteSignatureDraftSession {
  QuoteSignatureDraftSession._();
  static final Map<String, QuoteSignatureLocalDraft> _drafts = {};
  static String key(String quoteId, String documentId, String requestId) =>
      '$quoteId\u0000$documentId\u0000$requestId';
  static QuoteSignatureLocalDraft? retrieve(String key) => _drafts[key];
  static void save(String key, QuoteSignatureLocalDraft draft) {
    _drafts[key] = draft;
  }
  static void clear(String key) {
    _drafts.remove(key);
  }
  static void clearAll() {
    _drafts.clear();
  }
}


/// Two separate local capture records associated with one document.
/// These are NOT verified or server-signed until a trusted service confirms.
class QuoteInPersonSignatureSubmission {
  const QuoteInPersonSignatureSubmission({
    required this.quoteId,
    required this.documentId,
    required this.customerSignerId,
    required this.businessSignerId,
    required this.customerStrokes,
    required this.businessStrokes,
    required this.capturedAt,
    required this.consentAccepted,
  });

  final String quoteId;
  final String documentId;
  final String customerSignerId;
  final String businessSignerId;
  final List<List<Offset>> customerStrokes;
  final List<List<Offset>> businessStrokes;
  final DateTime capturedAt;
  final bool consentAccepted;
}
