import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sign2digital/core/services/active_company_session.dart';
import 'package:sign2digital/core/services/sign_api_client.dart';
import 'package:sign2digital/features/company/data/remote_company_repository.dart';
import 'package:sign2digital/features/company/domain/company_profile.dart';

void main() {
  final base = Uri.parse('https://forestgreen-pigeon-673192.hostingersite.com');

  setUp(ActiveCompanySession.clear);
  tearDown(ActiveCompanySession.clear);

  final example = CompanyProfile(
    id: 'demo-current-company',
    companyName: 'Swiss Workshop',
    address: 'Zürich', countryIsoCode: 'CH',
    dialingCode: '+41', phoneNumber: '791234567',
    email: 'info@workshop.ch', swissCompanyId: 'CHE-123',
    vatNumber: 'CHE-123 MWST', iban: 'CH9300762011623852957',
    qrIban: 'CH9300762011623852957',
    documentNumbering: 'Q-2026',
  );

  Map<String, dynamic> serverCompany(int id, {String name = 'Swiss Workshop'}) => {
    'id': id, 'name': name, 'address': 'Zürich',
    'country_iso_code': 'CH', 'dialing_code': '+41',
    'phone_number': '791234567', 'email': 'info@workshop.ch',
    'swiss_company_id': 'CHE-123', 'vat_number': 'CHE-123 MWST',
    'iban': 'CH9300762011623852957',
    'qr_iban': 'CH9300762011623852957',
    'document_numbering': 'Q-2026',
    'role': 'owner',
  };

  test('company setup sends every existing Swiss company field and persists returned ID', () async {
    final api = SignApiClient(
      baseUrl: base,
      tokenProvider: () async => 'verified-mobile-token',
      httpClient: MockClient((request) async {
        expect(request.url.path, '/api/v1/companies');
        expect(request.method, 'POST');
        expect(request.headers['Authorization'], 'Bearer verified-mobile-token');
        final payload = jsonDecode(request.body) as Map<String, dynamic>;
        expect(payload['name'], 'Swiss Workshop');
        expect(payload['swiss_company_id'], 'CHE-123');
        expect(payload['document_numbering'], 'Q-2026');
        expect(payload['iban'], 'CH9300762011623852957');
        expect(payload['qr_iban'], 'CH9300762011623852957');
        expect(payload['vat_number'], 'CHE-123 MWST');
        return http.Response(jsonEncode({'data': {
          'active_company_id': 17, 'company': serverCompany(17),
        }}), 201);
      }),
    );
    final repository = RemoteCompanyRepository(api: api);
    final saved = await repository.save(example);
    expect(saved.id, '17');
    expect(saved.role, 'owner');
    expect(ActiveCompanySession.companyId, 17);
  });

  test('list loads companies and preserves server selected company ID', () async {
    final api = SignApiClient(baseUrl: base,
      tokenProvider: () async => 'token',
      httpClient: MockClient((request) async => http.Response(jsonEncode({
        'data': {'active_company_id': 6, 'companies': [
          serverCompany(3, name: 'First'),
          serverCompany(6, name: 'Second'),
        ]},
      }), 200)),
    );
    final list = await RemoteCompanyRepository(api: api).list();
    expect(list.map((e) => e.companyName).toList(), ['First', 'Second']);
    expect(ActiveCompanySession.companyId, 6);
  });

  test('switch requests backend authorization before updating active tenant', () async {
    ActiveCompanySession.set(3);
    final api = SignApiClient(baseUrl: base,
      tokenProvider: () async => 'token',
      httpClient: MockClient((request) async {
        expect(request.url.path, '/api/v1/companies/9/switch');
        return http.Response(jsonEncode({
          'data': {'active_company_id': 9, 'company': serverCompany(9)},
        }), 200);
      }),
    );
    final c = await RemoteCompanyRepository(api: api).switchTo('9');
    expect(c.id, '9');
    expect(ActiveCompanySession.companyId, 9);
  });

  test('failed backend switch cannot change current company', () async {
    ActiveCompanySession.set(3);
    final api = SignApiClient(baseUrl: base,
      tokenProvider: () async => 'token',
      httpClient: MockClient((request) async => http.Response(
        jsonEncode({'message': 'Company access denied.'}), 403)),
    );
    await expectLater(RemoteCompanyRepository(api: api).switchTo('5'),
      throwsA(isA<SignApiException>()));
    expect(ActiveCompanySession.companyId, 3);
  });

  test('company invitation sends email and role but never a client-generated token', () async {
    final api = SignApiClient(baseUrl: base,
      tokenProvider: () async => 'token',
      httpClient: MockClient((request) async {
        expect(request.url.path, '/api/v1/companies/7/invitations');
        final data = jsonDecode(request.body) as Map<String, dynamic>;
        expect(data['email'], 'team@example.test');
        expect(data['role'], 'member');
        expect(data['permissions'], ['clients.read']);
        expect(data.containsKey('token_hash'), false);
        return http.Response(jsonEncode({'data': {
          'invitation': {'id': 2, 'email': 'team@example.test', 'role': 'member', 'status': 'pending'},
        }}), 201);
      }),
    );
    await RemoteCompanyRepository(api: api).invite('7', 'team@example.test',
      permissions: ['clients.read']);
  });

  test('terms upload uses authenticated multipart without public URL or fake saving', () async {
    final api = SignApiClient(baseUrl: base,
      tokenProvider: () async => 'token',
      httpClient: MockClient((request) async {
        expect(request.url.path, '/api/v1/companies/11/files/terms');
        expect(request.headers['Authorization'], 'Bearer token');
        expect(request.headers['content-type'], contains('multipart/form-data'));
        expect(request.bodyBytes, containsAll([37, 80, 68, 70]));
        return http.Response(jsonEncode({'data': {'company': serverCompany(11)}}), 200);
      }),
    );
    await RemoteCompanyRepository(api: api).uploadFile('11', 'terms',
      PlatformFile(name: 'terms.pdf', size: 8, bytes: Uint8List.fromList(
        [37, 80, 68, 70, 45, 49, 46, 55])));
  });

  test('invitation acceptance sends email-delivered code and updates tenant only on success', () async {
    final code = List.filled(64, 'a').join();
    final api = SignApiClient(baseUrl: base,
      tokenProvider: () async => 'token',
      httpClient: MockClient((request) async {
        expect(request.url.path, '/api/v1/companies/invitations/accept');
        expect((jsonDecode(request.body) as Map)['code'], code);
        return http.Response(jsonEncode({
          'data': {'active_company_id': 19, 'company': serverCompany(19)},
        }), 200);
      }),
    );
    await RemoteCompanyRepository(api: api).acceptInvite(code);
    expect(ActiveCompanySession.companyId, 19);
  });

  test('offline company refresh does not discard last verified selection', () async {
    ActiveCompanySession.set(6);
    final api = SignApiClient(baseUrl: base,
      tokenProvider: () async => 'token',
      httpClient: MockClient((request) async => http.Response(
        jsonEncode({'message': 'Service temporarily unavailable'}), 503)),
    );
    await expectLater(RemoteCompanyRepository(api: api).list(),
      throwsA(isA<SignApiException>()));
    expect(ActiveCompanySession.companyId, 6);
  });

  test('malformed company listing cannot overwrite the active tenant', () async {
    ActiveCompanySession.set(6);
    final api = SignApiClient(baseUrl: base,
      tokenProvider: () async => 'token',
      httpClient: MockClient((request) async => http.Response(jsonEncode({
        'data': {'active_company_id': 8, 'companies': [serverCompany(6)]},
      }), 200)),
    );
    await expectLater(RemoteCompanyRepository(api: api).list(),
      throwsA(isA<SignApiException>()));
    expect(ActiveCompanySession.companyId, 6);
  });

  test('unverified server switch response cannot change tenant context', () async {
    ActiveCompanySession.set(6);
    final api = SignApiClient(baseUrl: base,
      tokenProvider: () async => 'token',
      httpClient: MockClient((request) async => http.Response(jsonEncode({
        'data': {'active_company_id': 7, 'company': serverCompany(9)},
      }), 200)),
    );
    await expectLater(RemoteCompanyRepository(api: api).switchTo('9'),
      throwsA(isA<SignApiException>()));
    expect(ActiveCompanySession.companyId, 6);
  });

  test('invalid invitation response never selects an unrelated company', () async {
    ActiveCompanySession.set(6);
    final api = SignApiClient(baseUrl: base,
      tokenProvider: () async => 'token',
      httpClient: MockClient((request) async => http.Response(jsonEncode({
        'data': {'active_company_id': 12, 'company': serverCompany(14)},
      }), 200)),
    );
    await expectLater(RemoteCompanyRepository(api: api).acceptInvite(
      List.filled(64, 'b').join()), throwsA(isA<SignApiException>()));
    expect(ActiveCompanySession.companyId, 6);
  });

  test('valid empty company listing clears a revoked former selection', () async {
    ActiveCompanySession.set(6);
    final api = SignApiClient(baseUrl: base,
      tokenProvider: () async => 'token',
      httpClient: MockClient((request) async => http.Response(jsonEncode({
        'data': {'active_company_id': null, 'companies': <dynamic>[]},
      }), 200)),
    );
    final items = await RemoteCompanyRepository(api: api).list();
    expect(items, isEmpty);
    expect(ActiveCompanySession.companyId, isNull);
  });
}
