import '../../../core/services/active_company_session.dart';
import '../../../core/services/sign_api_client.dart';
import '../../auth/data/mobile_auth_repository.dart';
import '../domain/quote_document_tracking.dart';
import '../domain/quote_review_models.dart';

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
    final expiresAt = DateTime.tryParse((request['expires_at'] ?? '').toString());
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
      final when = DateTime.tryParse((event['occurredAt'] ?? '').toString());
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
    );
  }

  Future<RemoteSigningRequest> create(
    QuoteReviewDraft quote, {
    required String signerName,
    required String signerEmail,
    required String delivery,
  }) async {
    final serverId = _serverId(quote);
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
      '/api/v1/signature-requests/${id}/rotate-link',
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
  });
  final int id;
  final String status;
  final QuoteDocumentTracking tracking;
}
