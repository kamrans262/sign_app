import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:sign2digital/core/services/sign_api_client.dart';

void main() {
  final base = Uri.parse('https://forestgreen-pigeon-673192.hostingersite.com');

  test('health check is public and never adds an authentication token', () async {
    final client = SignApiClient(
      baseUrl: base,
      httpClient: MockClient((request) async {
        expect(request.url.path, '/api/health');
        expect(request.headers['Authorization'], isNull);
        return http.Response(jsonEncode({'status': 'ok'}), 200);
      }),
    );
    expect((await client.health())['status'], 'ok');
    client.dispose();
  });

  test('account request attaches a supplied token, not an embedded secret', () async {
    final client = SignApiClient(
      baseUrl: base,
      tokenProvider: () async => 'test-token',
      httpClient: MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer test-token');
        expect(request.headers['X-Company-Id'], isNull);
        expect(request.url.path, '/api/v1/me');
        return http.Response(jsonEncode({'data': {'user': {'id': 1}}}), 200);
      }),
    );
    expect((await client.currentAccount())['data'], isA<Map>());
  });

  test('company requests carry a specific company ID', () async {
    final client = SignApiClient(
      baseUrl: base,
      tokenProvider: () async => 'test-token',
      activeCompanyId: () => 18,
      httpClient: MockClient((request) async {
        expect(request.headers['X-Company-Id'], '18');
        return http.Response(jsonEncode({'data': {'id': 18}}), 200);
      }),
    );
    expect((await client.currentCompany())['data']['id'], 18);
  });

  test('no API request is made without authentication', () async {
    var called = false;
    final client = SignApiClient(
      baseUrl: base,
      httpClient: MockClient((request) async {
        called = true;
        return http.Response('{}', 200);
      }),
    );
    await expectLater(client.currentAccount(), throwsA(isA<SignApiException>()));
    expect(called, false);
  });

  test('403 is not turned into a successful response', () async {
    final client = SignApiClient(
      baseUrl: base,
      tokenProvider: () async => 'test-token',
      activeCompanyId: () => 99,
      httpClient: MockClient((request) async {
        return http.Response(jsonEncode({'message': 'Company access denied.'}), 403);
      }),
    );
    await expectLater(
      client.currentCompany(),
      throwsA(isA<SignApiException>().having((e) => e.statusCode, 'code', 403)),
    );
  });

  test('insecure API origins are rejected', () {
    expect(
      () => SignApiClient(baseUrl: Uri.parse('http://example.com')),
      throwsArgumentError,
    );
  });
}
