import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:sign2digital/core/services/active_company_session.dart';
import 'package:sign2digital/core/services/sign_api_client.dart';
import 'package:sign2digital/features/clients/data/remote_client_repository.dart';
import 'package:sign2digital/features/clients/domain/client_draft.dart';

Map<String, dynamic> client(int id, int companyId) => {
  'id': id,
  'company_id': companyId,
  'full_name': 'Marc Dupont',
  'company_name': 'Dupont Construction SA',
  'address': 'Lausanne',
  'country_iso_code': 'CH',
  'dialing_code': '+41',
  'phone_number': '211234567',
  'email': 'marc@example.ch',
  'notes': 'Call before visiting.',
  'job_count': 0,
};

const draft = ClientDraft(
  fullName: 'Marc Dupont',
  companyName: 'Dupont Construction SA',
  address: 'Lausanne',
  countryIsoCode: 'CH',
  dialingCode: '+41',
  phoneNumber: '211234567',
  email: 'marc@example.ch',
  notes: 'Call before visiting.',
);

SignApiClient mockApi(
    Future<http.Response> Function(http.Request request) callback) =>
    SignApiClient(
      baseUrl: Uri.parse('https://example.test'),
      tokenProvider: () async => 'verified-mobile-token',
      activeCompanyId: () => ActiveCompanySession.companyId,
      httpClient: MockClient(callback),
    );

void main() {
  setUp(() => ActiveCompanySession.set(5));
  tearDown(ActiveCompanySession.clear);

  test('client listing sends company header and maps every existing form field',
      () async {
    final api = mockApi((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, '/api/v1/clients');
      expect(request.headers['X-Company-Id'], '5');
      expect(request.headers['Authorization'], 'Bearer verified-mobile-token');
      expect(request.url.queryParameters['per_page'], '100');
      return http.Response(jsonEncode({'data': {
        'clients': [client(10, 5)],
        'pagination': {'page': 1, 'last_page': 1, 'total': 1},
      }}), 200);
    });
    final records = await RemoteClientRepository(api: api).listClients();
    expect(records, hasLength(1));
    expect(records.single.id, '10');
    expect(records.single.fullName, 'Marc Dupont');
    expect(records.single.companyName, 'Dupont Construction SA');
    expect(records.single.address, 'Lausanne');
    expect(records.single.nationalPhoneNumber, '211234567');
    expect(records.single.notes, 'Call before visiting.');
  });

  test('client creation sends existing fields but never client-chosen tenant id',
      () async {
    final api = mockApi((request) async {
      expect(request.url.path, '/api/v1/clients');
      final json = jsonDecode(request.body) as Map<String, dynamic>;
      expect(json['full_name'], 'Marc Dupont');
      expect(json['company_name'], 'Dupont Construction SA');
      expect(json['phone_number'], '211234567');
      expect(json['country_iso_code'], 'CH');
      expect(json['notes'], 'Call before visiting.');
      expect(json.containsKey('company_id'), isFalse);
      return http.Response(jsonEncode({'data': {'client': client(20, 5)}}), 201);
    });
    final saved = await RemoteClientRepository(api: api).createClient(draft);
    expect(saved.id, '20');
  });

  test('server cannot put a foreign tenant client in list or save response',
      () async {
    final listApi = mockApi((request) async => http.Response(jsonEncode({
      'data': {
        'clients': [client(10, 8)],
        'pagination': {'page': 1, 'last_page': 1, 'total': 1},
      },
    }), 200));
    await expectLater(RemoteClientRepository(api: listApi).listClients(),
        throwsA(isA<SignApiException>()));
    final saveApi = mockApi((request) async => http.Response(jsonEncode({
      'data': {'client': client(20, 8)},
    }), 201));
    await expectLater(RemoteClientRepository(api: saveApi).createClient(draft),
        throwsA(isA<SignApiException>()));
    expect(ActiveCompanySession.companyId, 5);
  });

  test('company switch during pending list invalidates old response', () async {
    final api = mockApi((request) async {
      ActiveCompanySession.set(6);
      return http.Response(jsonEncode({'data': {
        'clients': [client(10, 5)],
        'pagination': {'page': 1, 'last_page': 1, 'total': 1},
      }}), 200);
    });
    await expectLater(RemoteClientRepository(api: api).listClients(),
        throwsA(isA<SignApiException>()));
    expect(ActiveCompanySession.companyId, 6);
  });

  test('list fetches all server pages without truncating company clients',
      () async {
    var count = 0;
    final api = mockApi((request) async {
      count++;
      return http.Response(jsonEncode({'data': {
        'clients': [client(count, 5)],
        'pagination': {'page': count, 'last_page': 2, 'total': 2},
      }}), 200);
    });
    final clients = await RemoteClientRepository(api: api).listClients();
    expect(clients.map((c) => c.id), ['1', '2']);
    expect(count, 2);
  });

  test('reviewed contacts are imported only through explicit batch call',
      () async {
    final api = mockApi((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/api/v1/clients/import');
      expect(request.headers['X-Company-Id'], '5');
      final payload = jsonDecode(request.body) as Map<String, dynamic>;
      final drafts = payload['clients'] as List<dynamic>;
      expect(drafts, hasLength(1));
      expect((drafts.first as Map<String, dynamic>)['full_name'], 'Marc Dupont');
      expect((drafts.first as Map<String, dynamic>).containsKey('company_id'),
          isFalse);
      return http.Response(jsonEncode({'data': {
        'clients': [client(15, 5)], 'imported_count': 1,
      }}), 201);
    });
    expect(await RemoteClientRepository(api: api).importReviewed([draft]), 1);
  });

  test('client management rejects missing selected company', () async {
    ActiveCompanySession.clear();
    final api = mockApi((request) async =>
        throw StateError('Should not attempt HTTP without tenant'));
    await expectLater(RemoteClientRepository(api: api).listClients(),
        throwsA(isA<SignApiException>()));
  });
}
