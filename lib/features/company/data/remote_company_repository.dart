import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';

import '../../../core/services/active_company_session.dart';
import '../../../core/services/sign_api_client.dart';
import '../../auth/data/mobile_auth_repository.dart';
import '../domain/company_profile.dart';
import 'company_repository.dart';

int _asInt(Object? v) => v is int ? v : int.tryParse(v.toString()) ?? 0;
List<String> _asPermissions(Object? v) => v is List
    ? v.map((e) => e.toString()).toList(growable: false) : const [];

Map<String, dynamic> _data(Map<String, dynamic> r) {
  final v = r['data'];
  if (v is! Map<String, dynamic>) {
    throw const SignApiException('Invalid company server response.');
  }
  return v;
}

class CompanyMember {
  const CompanyMember({required this.id, required this.name, required this.email,
    required this.role, required this.status, required this.permissions});
  final int id;
  final String name, email, role, status;
  final List<String> permissions;
  factory CompanyMember.fromJson(Map<String, dynamic> m) => CompanyMember(
    id: _asInt(m['id']), name: (m['name'] ?? '').toString(),
    email: (m['email'] ?? '').toString(), role: (m['role'] ?? 'member').toString(),
    status: (m['status'] ?? '').toString(), permissions: _asPermissions(m['permissions']));
}

class CompanyInvite {
  const CompanyInvite({required this.id, required this.email, required this.role,
    required this.status});
  final int id;
  final String email, role, status;
  factory CompanyInvite.fromJson(Map<String, dynamic> m) => CompanyInvite(
    id: _asInt(m['id']), email: (m['email'] ?? '').toString(),
    role: (m['role'] ?? 'member').toString(),
    status: (m['status'] ?? 'pending').toString());
}

/// Real API repository for M3. The demo repository remains available for
/// isolated UI/widget previews only.
class RemoteCompanyRepository implements CompanyRepository {
  RemoteCompanyRepository({SignApiClient? api}) : _api = api ?? MobileAuthRepository.shared.api;
  static final RemoteCompanyRepository shared = RemoteCompanyRepository();
  final SignApiClient _api;

  static CompanyProfile _parse(Map<String, dynamic> m) => CompanyProfile(
    id: _asInt(m['id']).toString(),
    companyName: (m['name'] ?? '').toString(),
    address: (m['address'] ?? '').toString(),
    countryIsoCode: (m['country_iso_code'] ?? 'CH').toString(),
    dialingCode: (m['dialing_code'] ?? '+41').toString(),
    phoneNumber: (m['phone_number'] ?? '').toString(),
    email: (m['email'] ?? '').toString(),
    swissCompanyId: (m['swiss_company_id'] ?? '').toString(),
    vatNumber: (m['vat_number'] ?? '').toString(),
    iban: (m['iban'] ?? '').toString(),
    qrIban: (m['qr_iban'] ?? '').toString(),
    documentNumbering: (m['document_numbering'] ?? '').toString(),
    logoFileName: m['logo_file_name']?.toString(),
    termsFileName: m['terms_file_name']?.toString(),
  );
  static Map<String, dynamic> _payload(CompanyProfile c) => {
    'name': c.companyName, 'address': c.address,
    'country_iso_code': c.countryIsoCode, 'dialing_code': c.dialingCode,
    'phone_number': c.phoneNumber, 'email': c.email,
    'swiss_company_id': c.swissCompanyId, 'vat_number': c.vatNumber,
    'iban': c.iban, 'qr_iban': c.qrIban,
    'document_numbering': c.documentNumbering,
  };

  @override
  Future<CompanyProfile> save(CompanyProfile company) async {
    final id = int.tryParse(company.id);
    final response = id == null || id <= 0
        ? await _api.post('/api/v1/companies', data: _payload(company))
        : await _api.request('PATCH', '/api/v1/companies/$id', data: _payload(company));
    final data = _data(response);
    final raw = data['company'];
    if (raw is! Map<String, dynamic>) {
      throw const SignApiException('Company was not saved.');
    }
    if (id == null && data['active_company_id'] != null) {
      ActiveCompanySession.set(_asInt(data['active_company_id']));
    }
    return _parse(raw);
  }

  @override
  Future<CompanyProfile?> byId(String id) async {
    final n = int.tryParse(id);
    if (n == null || n <= 0) return null;
    final raw = _data(await _api.get('/api/v1/companies/$n'))['company'];
    if (raw is! Map<String, dynamic>) {
      throw const SignApiException('Invalid company response.');
    }
    return _parse(raw);
  }

  @override
  Future<List<CompanyProfile>> list() async {
    final data = _data(await _api.get('/api/v1/companies'));
    ActiveCompanySession.set(_asInt(data['active_company_id']));
    final records = data['companies'];
    if (records is! List) throw const SignApiException('Invalid company listing.');
    return records.whereType<Map<String, dynamic>>().map(_parse).toList();
  }

  Future<CompanyProfile> switchTo(String id) async {
    final n = int.tryParse(id);
    if (n == null || n <= 0) throw const SignApiException('Invalid company selection.');
    final data = _data(await _api.post('/api/v1/companies/$n/switch'));
    final raw = data['company'];
    if (raw is! Map<String, dynamic>) {
      throw const SignApiException('Unable to switch companies.');
    }
    ActiveCompanySession.set(_asInt(data['active_company_id']));
    return _parse(raw);
  }

  Future<List<CompanyMember>> members(String id) async {
    final raw = _data(await _api.get('/api/v1/companies/$id/members'))['members'];
    if (raw is! List) throw const SignApiException('Unable to load company team.');
    return raw.whereType<Map<String, dynamic>>().map(CompanyMember.fromJson).toList();
  }

  Future<List<CompanyInvite>> invitations(String id) async {
    final raw = _data(await _api.get('/api/v1/companies/$id/invitations'))['invitations'];
    if (raw is! List) throw const SignApiException('Unable to load invitations.');
    return raw.whereType<Map<String, dynamic>>().map(CompanyInvite.fromJson).toList();
  }

  Future<void> invite(String id, String email, {String role = 'member',
    List<String> permissions = const []}) async {
    await _api.post('/api/v1/companies/$id/invitations', data: {
      'email': email, 'role': role, 'permissions': permissions,
    });
  }

  Future<void> updateMember(String id, int user, String role,
      {List<String> permissions = const []}) async {
    await _api.request('PATCH', '/api/v1/companies/$id/members/$user',
      data: {'role': role, 'permissions': permissions});
  }

  Future<void> removeMember(String id, int user) async =>
      _api.delete('/api/v1/companies/$id/members/$user').then((_) {});

  Future<void> revokeInvite(String id, int invitationId) async =>
      _api.delete('/api/v1/companies/$id/invitations/$invitationId').then((_) {});

  Future<void> acceptInvite(String code) async {
    final result = _data(await _api.post('/api/v1/companies/invitations/accept',
      data: {'code': code.trim()}));
    ActiveCompanySession.set(_asInt(result['active_company_id']));
  }

  Future<void> uploadFile(String companyId, String kind, PlatformFile file) async {
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      throw const SignApiException('Select the file again to upload.');
    }
    if (file.size > 2 * 1024 * 1024) {
      throw const SignApiException('The file must be 2 MB or smaller.');
    }
    await _api.postMultipart('/api/v1/companies/$companyId/files/$kind',
      filename: file.name, bytes: Uint8List.fromList(bytes));
  }

  Future<void> deleteFile(String companyId, String kind) async {
    await _api.delete('/api/v1/companies/$companyId/files/$kind');
  }
}
