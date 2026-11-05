import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sign2digital/core/services/active_company_session.dart';
import 'package:sign2digital/core/services/sign_api_client.dart';
import 'package:sign2digital/features/reminders/data/m20_push_api.dart';

void main() {
  setUp(() => ActiveCompanySession.set(17));
  tearDown(ActiveCompanySession.clear);

  test('M20 preferences and device writes are authenticated and tenant-scoped', () async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.url.path.endsWith('/notification-preferences') &&
          request.method == 'GET') {
        return http.Response(jsonEncode({'data': {'preferences': {
          'in_app_enabled': true, 'push_enabled': false,
          'push_available': true, 'locale': 'fr', 'timezone': 'UTC',
        }}}), 200);
      }
      if (request.url.path.endsWith('/notification-preferences') &&
          request.method == 'PUT') {
        return http.Response(jsonEncode({'data': {'preferences': {
          'in_app_enabled': true, 'push_enabled': true,
          'push_available': true, 'locale': 'fr', 'timezone': 'UTC',
        }}}), 200);
      }
      if (request.url.path.endsWith('/push-devices') &&
          request.method == 'POST') {
        return http.Response('{"data":{"registered":true}}', 200);
      }
      if (request.url.path.endsWith('/push-devices') &&
          request.method == 'DELETE') {
        return http.Response('{"data":{"revoked":1}}', 200);
      }
      return http.Response('{"message":"Not found"}', 404);
    });
    final api = M20PushApi(api: SignApiClient(
      baseUrl: Uri.parse('https://example.test'),
      tokenProvider: () async => 'a-token',
      activeCompanyId: () => ActiveCompanySession.companyId,
      httpClient: client,
    ));
    final current = await api.preferences();
    expect(current.pushEnabled, false);
    expect(current.pushAvailable, true);
    expect(current.locale, 'fr');
    await api.register(installationId: '56c74f2a-d7f7-4d34-b7cb-9e17f7d319f2',
      platform: 'android', fid: 'FIREBASE_INSTALLATION_ID_PRIVATE');
    final next = await api.update(current, pushEnabled: true);
    expect(next.pushEnabled, true);
    await api.revoke(installationId: '56c74f2a-d7f7-4d34-b7cb-9e17f7d319f2');
    expect(requests, hasLength(4));
    for (final request in requests) {
      expect(request.headers['authorization'], 'Bearer a-token');
      expect(request.url.scheme, 'https');
    }
    expect(requests[1].headers['x-company-id'], '17');
    expect(requests[2].headers['x-company-id'], '17');
    final payload = jsonDecode(requests[1].body) as Map<String, dynamic>;
    expect(payload['platform'], 'android');
    expect(payload['fid'], 'FIREBASE_INSTALLATION_ID_PRIVATE');
    expect(jsonDecode(requests[2].body)['push_enabled'], true);
    expect(requests[3].headers.containsKey('x-company-id'), false);
    client.close();
  });

  test('M20 push endpoints reject missing company context before sending', () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      return http.Response('{}', 200);
    });
    final api = M20PushApi(api: SignApiClient(
      baseUrl: Uri.parse('https://example.test'),
      tokenProvider: () async => 'bearer',
      activeCompanyId: () => ActiveCompanySession.companyId,
      httpClient: client,
    ));
    ActiveCompanySession.clear();
    await expectLater(api.preferences(), throwsA(isA<SignApiException>()));
    await expectLater(api.register(installationId: '56c74f2a-d7f7-4d34-b7cb-9e17f7d319f2',
      platform: 'ios', fid: 'firebase-installation-id'), throwsA(isA<SignApiException>()));
    expect(calls, 0);
    client.close();
  });
}
