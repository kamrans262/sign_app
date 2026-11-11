import '../../../core/services/active_company_session.dart';
import '../../../core/services/sign_api_client.dart';
import '../../auth/data/mobile_auth_repository.dart';
import '../domain/client_draft.dart';
import '../domain/client_details_model.dart';
import '../domain/client_profile.dart';
import 'client_repository.dart';

/// M4: authenticated, company-scoped records. Demo repositories remain for
/// isolated UI previews and existing widget test injection.
class RemoteClientRepository implements ClientRepository {
  RemoteClientRepository({SignApiClient? api})
      : _api = api ?? MobileAuthRepository.shared.api;

  static final RemoteClientRepository shared = RemoteClientRepository();
  final SignApiClient _api;

  static Map<String, dynamic> _data(Map<String, dynamic> response) {
    final raw = response['data'];
    if (raw is! Map<String, dynamic>) {
      throw const SignApiException('Invalid client server response.');
    }
    return raw;
  }

  static int _id(Object? value) =>
      value is int ? value : int.tryParse(value.toString()) ?? 0;

  static ClientProfile _parse(Map<String, dynamic> raw) {
    final id = _id(raw['id']);
    if (id <= 0 || _id(raw['company_id']) <= 0) {
      throw const SignApiException('Invalid client identity returned by server.');
    }
    final fullName = (raw['full_name'] ?? '').toString();
    final companyName = (raw['company_name'] ?? '').toString();
    final dial = (raw['dialing_code'] ?? '').toString();
    final number = (raw['phone_number'] ?? '').toString();
    final isBusiness = companyName.trim().isNotEmpty;
    return ClientProfile(
      id: id.toString(),
      companyName: isBusiness ? companyName : fullName,
      companyType: isBusiness ? 'Client' : 'Individual client',
      fullName: fullName,
      address: (raw['address'] ?? '').toString(),
      email: (raw['email'] ?? '').toString(),
      phone: number.isEmpty ? '' : [dial, number]
          .where((part) => part.trim().isNotEmpty).join(' '),
      jobCount: _id(raw['job_count']),
      notes: (raw['notes'] ?? '').toString(),
      countryIsoCode: (raw['country_iso_code'] ?? '').toString(),
      dialingCode: dial,
      nationalPhoneNumber: number,
    );
  }

  static Map<String, dynamic> _payload(ClientDraft draft) => {
    'full_name': draft.fullName,
    'company_name': draft.companyName,
    'address': draft.address,
    'country_iso_code': draft.countryIsoCode,
    'dialing_code': draft.dialingCode,
    'phone_number': draft.phoneNumber,
    'email': draft.email,
    'notes': draft.notes,
  };

  int _company() {
    final id = ActiveCompanySession.companyId;
    if (id == null || id <= 0) {
      throw const SignApiException('Select a company before managing clients.');
    }
    return id;
  }

  @override
  Future<List<ClientProfile>> listClients() async {
    final current = _company();
    final result = <ClientProfile>[];
    var page = 1;
    while (true) {
      final data = _data(await _api.get('/api/v1/clients',
        companyScoped: true,
        queryParameters: {'page': page.toString(), 'per_page': '100'}));
      if (ActiveCompanySession.companyId != current) {
        throw const SignApiException('Company changed while loading clients.');
      }
      final raw = data['clients'];
      if (raw is! List || raw.any((item) => item is! Map<String, dynamic>)) {
        throw const SignApiException('Invalid client list.');
      }
      result.addAll(raw.cast<Map<String, dynamic>>().map((entry) {
        if (_id(entry['company_id']) != current) {
          throw const SignApiException('Client returned for another company.');
        }
        return _parse(entry);
      }));
      final pagination = data['pagination'];
      if (pagination is! Map<String, dynamic>) {
        throw const SignApiException('Missing client pagination.');
      }
      final last = _id(pagination['last_page']);
      if (last < page || last > 10000) {
        throw const SignApiException('Invalid client pagination.');
      }
      if (page == last) break;
      page++;
    }
    if (ActiveCompanySession.companyId != current) {
      throw const SignApiException('Company changed while loading clients.');
    }
    return result;
  }

  @override
  Future<ClientProfile> createClient(ClientDraft draft) async {
    final current = _company();
    final data = _data(await _api.post('/api/v1/clients',
      data: {
        ..._payload(draft),
        if (draft.requestKey != null) 'request_key': draft.requestKey,
      }, companyScoped: true));
    final raw = data['client'];
    if (raw is! Map<String, dynamic> || _id(raw['company_id']) != current ||
        ActiveCompanySession.companyId != current) {
      throw const SignApiException('Invalid saved client response.');
    }
    return _parse(raw);
  }

  @override
  Future<ClientProfile> updateClient(String id, ClientDraft draft) async {
    final clientId = int.tryParse(id);
    if (clientId == null || clientId <= 0) {
      throw const SignApiException('Invalid client identifier.');
    }
    final current = _company();
    final data = _data(await _api.request('PATCH', '/api/v1/clients/$clientId',
      data: _payload(draft), companyScoped: true));
    final raw = data['client'];
    if (raw is! Map<String, dynamic> || _id(raw['id']) != clientId ||
        _id(raw['company_id']) != current ||
        ActiveCompanySession.companyId != current) {
      throw const SignApiException('Invalid updated client response.');
    }
    return _parse(raw);
  }

  /// Resolves a result using its original tenant-scoped API identity.
  Future<ClientProfile> getClient(int id) async {
    if (id <= 0) throw const SignApiException('Invalid client ID.');
    final company = _company();
    final data = _data(await _api.get('/api/v1/clients/$id',
      companyScoped: true));
    if (ActiveCompanySession.companyId != company ||
        data['client'] is! Map<String, dynamic>) {
      throw const SignApiException('Invalid client details.');
    }
    final raw = data['client'] as Map<String, dynamic>;
    if (_id(raw['company_id']) != company || _id(raw['id']) != id) {
      throw const SignApiException('Client belongs to another company.');
    }
    return _parse(raw);
  }

  /// Loads a complete, company-scoped client dossier. No locally fabricated
  /// counts or related records may appear for an authenticated user.
  Future<ClientDetailsModel> details(String clientId) async {
    final id = int.tryParse(clientId);
    if (id == null || id <= 0) {
      throw const SignApiException('Select a saved client.');
    }
    final company = _company();
    final data = _data(await _api.get('/api/v1/clients/$id',
        companyScoped: true));
    if (ActiveCompanySession.companyId != company) {
      throw const SignApiException('Company changed while loading client.');
    }
    final raw = data['client'];
    if (raw is! Map<String, dynamic> || _id(raw['id']) != id ||
        _id(raw['company_id']) != company) {
      throw const SignApiException('Invalid client dossier.');
    }
    List<Map<String, dynamic>> records(String key) {
      final list = data[key];
      if (list is! List || list.any((item) => item is! Map)) {
        throw SignApiException('Invalid $key history.');
      }
      return [for (final item in list) Map<String, dynamic>.from(item as Map)];
    }
    final client = _parse(raw);
    final jobs = [
      for (final row in records('jobs'))
        ClientRelatedRecord(
          id: '${_id(row['id'])}',
          title: '${row['title'] ?? ''}',
          description: '${row['reference_number'] ?? ''}',
          meta: '${row['due_date'] ?? ''}',
          status: '${row['status'] ?? ''}',
        ),
    ];
    final quotes = [
      for (final row in records('quotes'))
        ClientRelatedRecord(
          id: 'quote-${_id(row['id'])}',
          title: '${row['reference_number'] ?? ''}',
          description: '${row['currency'] ?? 'CHF'} '
              '${(_id(row['total_minor']) / 100).toStringAsFixed(2)}',
          meta: 'Quote', status: '${row['status'] ?? ''}',
        ),
    ];
    final documents = [
      for (final row in records('documents'))
        ClientRelatedRecord(
          id: '${row['id'] ?? ''}',
          title: '${row['title'] ?? ''}',
          description: '${row['number'] ?? ''}',
          meta: '${row['project'] ?? ''}',
          status: '${row['status'] ?? ''}',
        ),
    ];
    final invoices = [
      for (final row in records('invoices'))
        ClientRelatedRecord(
          id: 'invoice-${_id(row['id'])}',
          title: '${row['number'] ?? ''}',
          description: '${row['currency'] ?? 'CHF'} '
              '${(_id(row['total_minor']) / 100).toStringAsFixed(2)}',
          meta: '${row['invoice_date'] ?? ''}',
          status: '${row['status'] ?? ''}',
        ),
    ];
    final notes = [
      for (final row in records('notes_history'))
        ClientRelatedRecord(
          id: '${row['id'] ?? ''}',
          title: '${row['title'] ?? ''}',
          description: '${row['description'] ?? ''}',
          meta: '${row['created_at'] ?? ''}',
        ),
    ];
    return ClientDetailsModel(
      client: client, status: 'Active',
      displayAddress: client.address,
      totalQuotes: quotes.length,
      totalDocuments: documents.length,
      totalInvoices: invoices.length,
      jobs: jobs, quotes: quotes, documents: documents,
      invoices: invoices, notes: notes,
    );
  }

  /// Caller must obtain permission, allow selection, and show explicit review
  /// before calling this method. Never silently sync the address book.
  Future<int> importReviewed(List<ClientDraft> drafts) async {
    if (drafts.isEmpty || drafts.length > 100) {
      throw const SignApiException('Choose between 1 and 100 contacts.');
    }
    final company = _company();
    final result = _data(await _api.post('/api/v1/clients/import',
      data: {'clients': drafts.map(_payload).toList()},
      companyScoped: true));
    final raw = result['clients'];
    if (raw is! List || _id(result['imported_count']) != drafts.length ||
        ActiveCompanySession.companyId != company ||
        raw.any((item) => item is! Map<String, dynamic> ||
          _id(item['company_id']) != company)) {
      throw const SignApiException('Invalid contact import response.');
    }
    return raw.length;
  }
}
