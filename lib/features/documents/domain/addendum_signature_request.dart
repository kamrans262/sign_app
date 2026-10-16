import 'addendum_draft.dart';
import 'document_record.dart';

/// A service-confirmed request for a particular *addendum*, never its
/// underlying signed quote. Client-side share sheets cannot create receipts.
class AddendumSignatureRequest {
  const AddendumSignatureRequest({
    required this.requestId,
    required this.addendumId,
    required this.originalDocumentId,
    required this.secureUrl,
    required this.expiresAt,
    required this.confirmedSentAt,
  });

  final String requestId;
  final String addendumId;
  final String originalDocumentId;
  final Uri secureUrl;
  final DateTime expiresAt;
  /// Must be a genuine service-issued delivery receipt; null means unsent.
  final DateTime? confirmedSentAt;

  bool get valid => requestId.trim().isNotEmpty &&
      addendumId.trim().isNotEmpty &&
      originalDocumentId.trim().isNotEmpty &&
      secureUrl.scheme == 'https' && secureUrl.host.isNotEmpty &&
      expiresAt.isAfter(DateTime.now());

  String get status => expiresAt.isBefore(DateTime.now())
      ? 'Expired'
      : confirmedSentAt == null ? 'Draft' : 'Awaiting Signature';
}

typedef AddendumSignatureRequestService =
    Future<AddendumSignatureRequest?> Function(
      AddendumDraft draft, DocumentRecord original);

/// Session-local service receipts only. A signature cannot be marked signed
/// here; a trusted backend must provide a finalized signed addendum and audit.
abstract final class AddendumSignatureRequestSession {
  static final Map<String, AddendumSignatureRequest> _requests = {};

  static AddendumSignatureRequest? forAddendum(String id) => _requests[id];

  static void remember(
    AddendumDraft draft,
    DocumentRecord original,
    AddendumSignatureRequest request,
  ) {
    if (!draft.isCreatedLocally || !request.valid ||
        request.addendumId != draft.id ||
        request.originalDocumentId != original.id ||
        draft.linkedDocumentId != original.id) {
      throw const FormatException('Signing request does not match addendum.');
    }
    _requests[draft.id] = request;
  }

  static void clear() => _requests.clear();
}
