import '../../../core/utils/sign2digital_server_timestamp.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import '../../../core/services/active_company_session.dart';
import '../../../core/services/sign_api_client.dart';
import '../../auth/data/mobile_auth_repository.dart';
import '../domain/quote_document_tracking.dart';
import '../domain/quote_review_models.dart';
import '../domain/quote_signature_draft.dart';

/// M8 signing requests are issued, validated and audited by Laravel.
/// The app never mints signing tokens or marks a PDF as signed locally.
class RemoteSignatureRequestRepository {
  RemoteSignatureRequestRepository({SignApiClient? api})
      : _api = api ?? MobileAuthRepository.shared.api;

  static final shared = RemoteSignatureRequestRepository();
  final SignApiClient _api;

  int _company() {
    final company = ActiveCompanySession.companyId;
    if (company == null || company <= 0) {
      throw const SignApiException('Select your company before requesting a signature.');
    }
    return company;
  }

  static Map<String, dynamic> _data(Map<String, dynamic> source) {
    final data = source['data'];
    if (data is! Map) {
      throw const SignApiException('Invalid signature service response.');
    }
    return Map<String, dynamic>.from(data);
  }

  static Map<String, dynamic> _map(Object? source) {
    if (source is! Map) {
      throw const SignApiException('Invalid signing request details.');
    }
    return Map<String, dynamic>.from(source);
  }

  static int _int(Object? value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 0;

  static int _serverId(QuoteReviewDraft quote) {
    if (quote.isDemo || quote.serverId == null || quote.serverId! <= 0 ||
        !quote.approvedLocally) {
      throw const SignApiException('Approve a real quote before requesting a signature.');
    }
    return quote.serverId!;
  }

  static QuoteDocumentTracking _tracking(
    QuoteReviewDraft quote, Map<String, dynamic> request,
    List<dynamic> rawEvents, {String? secureLink}
  ) {
    final requestId = (request['request_id'] ?? '').toString();
    final expiresAt = Sign2DigitalServerTimestamp.tryParse(request['expires_at']);
    if (requestId.isEmpty || expiresAt == null) {
      throw const SignApiException('The signature request is incomplete.');
    }
    final events = <QuoteDocumentEvent>[];
    for (final raw in rawEvents) {
      if (raw is! Map) continue;
      final event = _map(raw);
      final types = QuoteDocumentEventType.values.where(
        (type) => type.name == event['type'],
      );
      final when = Sign2DigitalServerTimestamp.tryParse(event['occurredAt']);
      if (types.isEmpty || when == null) continue;
      events.add(QuoteDocumentEvent(
        id: (event['id'] ?? '').toString(),
        type: types.first,
        occurredAt: when,
      ));
    }
    final link = secureLink == null ? null : Uri.tryParse(secureLink);
    if (link != null && (link.scheme != 'https' || link.host.isEmpty)) {
      throw const SignApiException('The server returned an unsafe signing link.');
    }
    return QuoteDocumentTracking(
      quoteId: quote.id, requestId: requestId,
      secureUrl: link, expiresAt: expiresAt, events: events,
    );
  }

  Future<RemoteSigningRequest?> latest(QuoteReviewDraft quote) async {
    final serverId = _serverId(quote);
    final company = _company();
    final response = _data(await _api.request(
      'GET', '/api/v1/quotes/$serverId/signature-requests',
      companyScoped: true,
    ));
    if (ActiveCompanySession.companyId != company) {
      throw const SignApiException('Company changed during request loading.');
    }
    final list = response['requests'];
    if (list is! List || list.isEmpty) return null;
    final all = list.whereType<Map>().map(_map).toList();
    final selected = all.firstWhere(
      (record) => ['ready', 'sent', 'viewed'].contains(record['status']),
      orElse: () => all.first,
    );
    return show(quote, _int(selected['id']));
  }

  Future<RemoteSigningRequest> show(QuoteReviewDraft quote, int id) async {
    _serverId(quote);
    final company = _company();
    final data = _data(await _api.request(
      'GET', '/api/v1/signature-requests/$id', companyScoped: true,
    ));
    if (ActiveCompanySession.companyId != company) {
      throw const SignApiException('Company changed during signing request.');
    }
    final record = _map(data['request']);
    if (_int(record['quote_id']) != quote.serverId) {
      throw const SignApiException('Signing request belongs to another quote.');
    }
    return RemoteSigningRequest(
      id: _int(record['id']),
      status: (record['status'] ?? 'ready').toString(),
      tracking: _tracking(quote, record,
        data['events'] is List ? List<dynamic>.from(data['events']) : []),
      approvedRevision: _int(record['approved_revision']),
      businessSignerName: (record['business_signer_name'] ?? '').toString(),
      businessSignedAt: Sign2DigitalServerTimestamp.tryParse(
          record['business_signed_at']),
      businessSignatureSha256:
          (record['business_signature_sha256'] ?? '').toString(),
    );
  }

  /// Reads the actual issuer signature from private tenant storage and
  /// independently checks its checksum. Never infer business signing from a
  /// locally captured image or from an unsigned request.
  Future<VerifiedQuoteBusinessSignature?> verifiedBusinessSignature(
    QuoteReviewDraft quote, {RemoteSigningRequest? signingRequest}
  ) async {
    final request = signingRequest ?? await latest(quote);
    if (request == null || request.businessSignedAt == null) return null;
    if (!request.hasVerifiedBusinessSignature ||
        (quote.serverRevision != null &&
         request.approvedRevision != quote.serverRevision)) {
      throw const SignApiException(
          'Verified business signature metadata does not match this quotation.');
    }
    final company = _company();
    final bytes = await _api.getPrivateAttachment(
      '/api/v1/signature-requests/${request.id}/business-signature',
      mimeType: 'image/png', companyScoped: true, maxBytes: 300 * 1024,
    );
    if (company != ActiveCompanySession.companyId) {
      throw const SignApiException('Company changed during signature preview.');
    }
    if (sha256.convert(bytes).toString() != request.businessSignatureSha256) {
      throw const SignApiException('Business signature integrity check failed.');
    }
    return VerifiedQuoteBusinessSignature(
      requestId: request.id, signerName: request.businessSignerName,
      signedAt: request.businessSignedAt!, pngBytes: bytes,
    );
  }

  /// Server-minted, short-lived context. No fabricated signer IDs in Flutter.
  Future<BusinessSignatureContext> prepareBusiness(QuoteReviewDraft quote) async {
    final id = _serverId(quote);
    final company = _company();
    final response = _data(await _api.request(
      'GET', '/api/v1/quotes/$id/business-signature-context',
      companyScoped: true,
    ));
    if (company != ActiveCompanySession.companyId) {
      throw const SignApiException('Company changed during issuer signing.');
    }
    final context = _map(response['context']);
    if (context['quote_id'] != '$id' ||
        ['document_id', 'request_id', 'signer_id', 'document_version',
         'consent_reference', 'authorization']
          .any((key) => (context[key] ?? '').toString().isEmpty)) {
      throw const SignApiException('Invalid issuer signing authorization.');
    }
    return BusinessSignatureContext(
      quoteId: context['quote_id'] as String,
      documentId: context['document_id'] as String,
      requestId: context['request_id'] as String,
      signerId: context['signer_id'] as String,
      documentVersion: context['document_version'] as String,
      consentReference: context['consent_reference'] as String,
      authorization: context['authorization'] as String,
    );
  }

  Future<RemoteSigningRequest> create(
    QuoteReviewDraft quote, {
    required String signerName,
    required String signerEmail,
    required String delivery,
    String? message,
    bool attachPdf = false,
    BusinessSignatureContext? businessContext,
    QuoteSignatureDraft? businessSignature,
  }) async {
    final serverId = _serverId(quote);
    if ((businessContext == null) != (businessSignature == null)) {
      throw const SignApiException('Issuer authorization and signature must be provided together.');
    }
    if (businessContext != null && businessSignature != null && (
        businessContext.quoteId != '$serverId' ||
        businessContext.documentId != businessSignature.documentId ||
        businessContext.requestId != businessSignature.requestId ||
        businessContext.signerId != businessSignature.signerId ||
        businessContext.documentVersion != businessSignature.documentVersion ||
        businessContext.consentReference != businessSignature.consentReference ||
        !businessSignature.consentAccepted ||
        businessSignature.pngBytes.isEmpty)) {
      throw const SignApiException('Issuer signature does not match the approved quote.');
    }
    if (!['email', 'link'].contains(delivery)) {
      throw const SignApiException('Invalid signature delivery method.');
    }
    final company = _company();
    final data = _data(await _api.post(
      '/api/v1/quotes/$serverId/signature-requests',
      data: {
        'signer_name': signerName.trim(),
        'signer_email': signerEmail.trim(),
        'delivery': delivery,
        'expires_in_days': 7,
        'message': message?.trim(),
        'attach_pdf': attachPdf,
        if (businessContext != null) ...{
          'business_authorization': businessContext.authorization,
          'business_signature_png_base64': base64Encode(businessSignature!.pngBytes),
          'business_signature_method': businessSignature.method.name,
          'business_signature_typed_name': businessSignature.typedName,
          'business_consent_accepted': true,
        },
      },
      companyScoped: true,
    ));
    if (ActiveCompanySession.companyId != company) {
      throw const SignApiException('Company changed during signing request.');
    }
    final record = _map(data['request']);
    if (_int(record['quote_id']) != serverId) {
      throw const SignApiException('Signing response belongs to another quote.');
    }
    final link = data['secure_link'] as String?;
    final id = _int(record['id']);
    if (id <= 0) throw const SignApiException('Signing request has no server ID.');
    // Use only server-recorded events and timestamps, never fabricate them.
    final fresh = await show(quote, id);
    final parsedLink = link == null ? null : Uri.tryParse(link);
    if (parsedLink != null &&
        (parsedLink.scheme != 'https' || parsedLink.host.isEmpty)) {
      throw const SignApiException('The server returned an unsafe signing link.');
    }
    return RemoteSigningRequest(
      id: id,
      status: fresh.status,
      approvedRevision: fresh.approvedRevision,
      businessSignerName: fresh.businessSignerName,
      businessSignedAt: fresh.businessSignedAt,
      businessSignatureSha256: fresh.businessSignatureSha256,
      tracking: QuoteDocumentTracking(
        quoteId: quote.id,
        requestId: fresh.tracking.requestId,
        secureUrl: parsedLink,
        expiresAt: fresh.tracking.expiresAt,
        events: fresh.tracking.events,
      ),
    );
  }

  Future<RemoteSigningRequest> rotateLink(
    QuoteReviewDraft quote, int id,
  ) async {
    final company=_company();
    final data=_data(await _api.post(
      '/api/v1/signature-requests/$id/rotate-link',
      data:const {},companyScoped:true,
    ));
    if(company!=ActiveCompanySession.companyId) {
      throw const SignApiException('Company changed while rotating the link.');
    }
    final record=_map(data['request']);
    if(_int(record['quote_id'])!=quote.serverId || data['delivered']!=false) {
      throw const SignApiException('Invalid signing link response.');
    }
    final link=data['secure_link'];
    if(link is! String || !link.startsWith('https://')) {
      throw const SignApiException('The new link was not verified.');
    }
    final fresh=await show(quote,id);
    return RemoteSigningRequest(
      id:id,
      status:fresh.status,
      tracking:QuoteDocumentTracking(
        quoteId:quote.id,
        requestId:fresh.tracking.requestId,
        secureUrl:Uri.parse(link),
        expiresAt:fresh.tracking.expiresAt,
        events:fresh.tracking.events,
      ),
    );
  }

  Future<RemoteSigningRequest> resend(
    QuoteReviewDraft quote, int id,
  ) async {
    final company = _company();
    await _api.post('/api/v1/signature-requests/$id/resend',
        data: const {}, companyScoped: true);
    if (company != ActiveCompanySession.companyId) {
      throw const SignApiException('Company changed during reminder delivery.');
    }
    return show(quote, id);
  }

  Future<void> revoke(QuoteReviewDraft quote, int id) async {
    _serverId(quote);
    await _api.post('/api/v1/signature-requests/$id/revoke',
      data: const {}, companyScoped: true);
  }
}

class RemoteSigningRequest {
  const RemoteSigningRequest({
    required this.id,
    required this.status,
    required this.tracking,
    this.approvedRevision = 0,
    this.businessSignerName = '',
    this.businessSignedAt,
    this.businessSignatureSha256 = '',
  });
  final int id;
  final String status;
  final QuoteDocumentTracking tracking;
  final int approvedRevision;
  final String businessSignerName;
  final DateTime? businessSignedAt;
  final String businessSignatureSha256;
  bool get hasVerifiedBusinessSignature =>
      businessSignedAt != null && businessSignerName.trim().isNotEmpty &&
      RegExp(r'^[a-f0-9]{64}$').hasMatch(businessSignatureSha256);
}

class VerifiedQuoteBusinessSignature {
  const VerifiedQuoteBusinessSignature({
    required this.requestId,
    required this.signerName,
    required this.signedAt,
    required this.pngBytes,
  });
  final int requestId;
  final String signerName;
  final DateTime signedAt;
  final Uint8List pngBytes;
}


/// Ephemeral issuer signing authorization issued by Laravel for one quote revision.
class BusinessSignatureContext {
  const BusinessSignatureContext({
    required this.quoteId, required this.documentId, required this.requestId,
    required this.signerId, required this.documentVersion,
    required this.consentReference, required this.authorization,
  });
  final String quoteId;
  final String documentId;
  final String requestId;
  final String signerId;
  final String documentVersion;
  final String consentReference;
  final String authorization;
}
