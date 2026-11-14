import 'dart:io';

import '../../../core/services/active_company_session.dart';
import '../../../core/services/sign_api_client.dart';
import '../../auth/data/mobile_auth_repository.dart';
import '../../quotes/data/remote_quote_repository.dart';
import '../../quotes/domain/quote_review_models.dart';
import '../domain/addendum_draft.dart';
import '../domain/addendum_signature_request.dart';
import '../domain/document_record.dart';
import '../services/addendum_voice_extraction_service.dart';

/// M10 server-owned addenda. Neither approval nor signing is inferred locally.
class RemoteAddendumRepository {
  RemoteAddendumRepository({SignApiClient? api})
      : _api = api ?? MobileAuthRepository.shared.api;

  static final shared = RemoteAddendumRepository();
  final SignApiClient _api;

  int _company() {
    final company = ActiveCompanySession.companyId;
    if (company == null || company <= 0) {
      throw const SignApiException('Select an active company first.');
    }
    return company;
  }

  void _check(int id) {
    if (ActiveCompanySession.companyId != id) {
      throw const SignApiException('Company changed during addendum operation.');
    }
  }

  static int _int(Object? value) =>
      value is int ? value : int.tryParse('$value') ?? 0;

  static Map<String, dynamic> _payload(Map<String, dynamic> result) {
    final raw = result['data'];
    if (raw is! Map<String, dynamic>) {
      throw const SignApiException('Invalid addendum response.');
    }
    return raw;
  }

  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static AddendumDraft _parse(Object? raw, int company, {int? expectedId}) {
    if (raw is! Map<String, dynamic> ||
        _int(raw['company_id']) != company ||
        _int(raw['id']) <= 0 ||
        expectedId != null && _int(raw['id']) != expectedId) {
      throw const SignApiException('Invalid or cross-company addendum data.');
    }
    final source = (raw['source_document_id'] ?? '').toString();
    if (!RegExp(r'^signed-[1-9][0-9]*$').hasMatch(source)) {
      throw const SignApiException('Invalid signed-original reference.');
    }
    final id = _int(raw['id']);
    final revision = _int(raw['revision']);
    final minor = raw['unit_price_minor'];
    final cents = _int(minor);
    final unit = minor == null ? '' :
        '${cents ~/ 100}.${(cents % 100).toString().padLeft(2, '0')}';
    final draft = AddendumDraft(
      id: 'addendum-$id',
      serverId: id, serverRevision: revision,
      serverStatus: (raw['status'] ?? '').toString(),
      currency: (raw['currency'] ?? 'CHF').toString(),
      quoteServerId: _int(raw['quote_id']) > 0 ? _int(raw['quote_id']) : null,
      number: (raw['number'] ?? '').toString(),
      title: (raw['title'] ?? '').toString(),
      description: (raw['change_description'] ?? '').toString(),
      additionalWork: (raw['additional_work'] ?? '').toString(),
      quantity: raw['quantity'] == null ? '' : raw['quantity'].toString(),
      unitPrice: unit, vatBasisPoints: _int(raw['vat_basis_points']),
      linkedDocumentId: source,
      linkedJobId: raw['job_id']?.toString(),
      linkedClientId: raw['client_id']?.toString(),
      effectiveDate: DateTime.tryParse((raw['effective_date'] ?? '').toString()),
      isCreatedLocally: true,
    );
    if (revision < 1 || draft.validationIssues.isNotEmpty ||
        !['draft', 'approved', 'sent', 'signed'].contains(draft.serverStatus) ||
        draft.totalMinor != _int(raw['total_minor'])) {
      throw const SignApiException('Inconsistent saved addendum.');
    }
    AddendumDraftSession.rememberRemote(draft);
    return draft;
  }

  Future<AddendumDraft> get(int id) async {
    final company = _company();
    final response = await _api.get(
      '/api/v1/addenda/$id', companyScoped: true);
    _check(company);
    return _parse(_payload(response)['addendum'], company, expectedId: id);
  }

  Future<AddendumDraft> save(AddendumDraft draft) async {
    final company = _company();
    if (draft.validationIssues.isNotEmpty) {
      throw SignApiException(draft.validationIssues.first);
    }
    if (draft.serverId == null &&
        !RegExp(r'^signed-[1-9][0-9]*$')
            .hasMatch(draft.linkedDocumentId ?? '')) {
      throw const SignApiException('Choose a verified signed original.');
    }
    final body = <String, dynamic>{
      'title': draft.title.trim(),
      'change_description': draft.description.trim(),
      'effective_date': _date(draft.effectiveDate!),
      'additional_work': draft.additionalWork.trim().isEmpty
          ? null : draft.additionalWork.trim(),
      'quantity': draft.hasPricedWork ? int.parse(draft.quantity.trim()) : null,
      'unit_price_minor': draft.hasPricedWork
          ? parseQuoteMinorUnits(draft.unitPrice) : null,
      'vat_basis_points': draft.vatBasisPoints,
      if (draft.serverId == null) 'source_signed_artifact_id':
          int.parse(draft.linkedDocumentId!.substring('signed-'.length)),
      if (draft.serverId != null) 'expected_revision': draft.serverRevision,
    };
    final response = draft.serverId == null
        ? await _api.post('/api/v1/addenda', data: body, companyScoped: true)
        : await _api.request('PATCH', '/api/v1/addenda/${draft.serverId}', data: body, companyScoped: true);
    _check(company);
    return _parse(_payload(response)['addendum'], company,
        expectedId: draft.serverId);
  }

  Future<AddendumDraft> approve(AddendumDraft draft) async {
    if (draft.serverId == null || draft.serverRevision == null ||
        draft.serverStatus != 'draft') {
      throw const SignApiException('Save and review the unsigned addendum first.');
    }
    final company = _company();
    final response = await _api.post(
      '/api/v1/addenda/${draft.serverId}/approve',
      data: {'confirmed': true, 'expected_revision': draft.serverRevision},
      companyScoped: true,
    );
    _check(company);
    final approved = _parse(_payload(response)['addendum'],
        company, expectedId: draft.serverId);
    if (approved.serverStatus != 'approved') {
      throw const SignApiException('Server did not approve this addendum.');
    }
    return approved;
  }

  /// Send the frozen approved Addendum by email. The signing receipt is valid
  /// when Laravel confirms SMTP transport acceptance, even without a raw URL.
  /// Explicit reissue rotates only a previous unsent and unviewed link.
  Future<AddendumSignatureRequest?> requestSignature(
      AddendumDraft draft, DocumentRecord source, {
      bool replaceReadyLink = false,
  }) async {
    if (draft.serverId == null || draft.quoteServerId == null ||
        draft.linkedDocumentId != source.id ||
        !['approved', 'sent'].contains(draft.serverStatus) ||
        !RegExp(r'^signed-[1-9][0-9]*$').hasMatch(source.id) ||
        !source.verifiedSignedPdfAvailable) {
      throw const SignApiException('A verified signed source and approved addendum are required.');
    }
    final company = _company();
    final quote = await RemoteQuoteRepository(api: _api)
        .getQuote(draft.quoteServerId!);
    _check(company);
    if (quote.clientName.trim().isEmpty || quote.clientEmail.trim().isEmpty) {
      throw const SignApiException('Original quote has no verified customer email.');
    }
    final response = await _api.post(
      '/api/v1/addenda/${draft.serverId}/signature-requests',
      companyScoped: true,
      data: {
        'signer_name': quote.clientName,
        'signer_email': quote.clientEmail,
        'delivery': 'email',
        if (replaceReadyLink) 'replace_ready_link': true,
      },
    );
    _check(company);
    final result = _payload(response);
    final request = result['request'];
    if (request is! Map<String, dynamic> || _int(request['id']) <= 0 ||
        _int(request['addendum_id']) != draft.serverId ||
        (request['request_id'] ?? '').toString().trim().isEmpty) {
      throw const SignApiException('Server did not confirm the signing request.');
    }
    final sentAt = DateTime.tryParse((request['sent_at'] ?? '').toString());
    final expires = DateTime.tryParse((request['expires_at'] ?? '').toString());
    // Email delivery deliberately returns NO raw capability URL: the token
    // has already been sent to the verified original-quote customer.
    if (result['transport_accepted'] != true ||
        request['status'] != 'sent' || sentAt == null ||
        result['secure_link'] != null || expires == null ||
        !expires.isAfter(DateTime.now())) {
      throw const SignApiException(
          'Server did not confirm email acceptance for this addendum.');
    }
    return AddendumSignatureRequest(
      requestId: request['request_id'].toString(),
      addendumId: draft.id, originalDocumentId: source.id,
      secureUrl: null, expiresAt: expires,
      confirmedSentAt: sentAt,
    );
  }

  /// Authoritative server state used only when a new request is rejected as
  /// already active. No raw signing tokens or private URLs are returned.
  Future<String?> activeSignatureRequestStatus(int addendumId) async {
    final company = _company();
    final response = await _api.get(
      '/api/v1/addenda/$addendumId/signature-requests',
      companyScoped: true,
    );
    _check(company);
    final rows = _payload(response)['requests'];
    if (rows is! List) {
      throw const SignApiException('Invalid signing request history.');
    }
    for (final raw in rows) {
      if (raw is! Map<String, dynamic> ||
          _int(raw['addendum_id']) != addendumId) continue;
      final status = (raw['status'] ?? '').toString();
      final expiry = DateTime.tryParse((raw['expires_at'] ?? '').toString());
      if (expiry != null && expiry.isAfter(DateTime.now()) &&
          ['ready', 'sent', 'viewed'].contains(status)) {
        return status;
      }
    }
    return null;
  }

  Future<AddendumVoiceSuggestion> prepareVoice(String audioPath) async {
    final company = _company();
    final audio = File(audioPath);
    if (!await audio.exists()) throw const SignApiException('Recording was not saved.');
    final bytes = await audio.readAsBytes();
    if (bytes.isEmpty || bytes.length > 25 * 1024 * 1024) {
      throw const SignApiException('Recording exceeds 25 MB.');
    }
    final response = await _api.postMultipart(
      '/api/v1/addenda/prepare/voice',
      filename: 'addendum-recording.m4a', bytes: bytes,
      maxBytes: 25 * 1024 * 1024, companyScoped: true,
    );
    _check(company);
    final fields = _payload(response)['fields'];
    if (fields is! Map<String, dynamic>) {
      throw const SignApiException('Invalid voice extraction response.');
    }
    return AddendumVoiceSuggestion.fromJson(fields);
  }
}
