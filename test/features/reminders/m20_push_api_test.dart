import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sign2digital/core/services/active_company_session.dart';
import 'package:sign2digital/core/services/sign_api_client.dart';
import 'package:sign2digital/features/reminders/data/m20_push_api.dart';
import 'package:sign2digital/features/reminders/data/remote_notification_repository.dart';
import 'package:sign2digital/features/reminders/presentation/screens/notification_inbox_screen.dart';
import 'package:sign2digital/features/reminders/services/m20_push_coordinator.dart';

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

  test('M20 first-launch consent handles Android 13 and never re-prompts', () {
    bool request(AuthorizationStatus status, {
      bool android = false, bool requested = false,
    }) => M20PushCoordinator.shouldRequestPermission(status,
        isAndroid: android, previouslyRequested: requested);

    expect(request(AuthorizationStatus.notDetermined), isTrue);
    expect(request(AuthorizationStatus.notDetermined, requested: true), isFalse);
    // Android 13+ can return denied before its FIRST permission dialog.
    expect(request(AuthorizationStatus.denied, android: true), isTrue);
    expect(request(AuthorizationStatus.denied, android: true,
        requested: true), isFalse);
    expect(request(AuthorizationStatus.denied), isFalse);
    expect(request(AuthorizationStatus.deniedPermanently,
        android: true), isFalse);
    expect(request(AuthorizationStatus.authorized), isFalse);
    expect(request(AuthorizationStatus.provisional), isFalse);
    expect(M20PushCoordinator.hasPushPermission(
        AuthorizationStatus.authorized), isTrue);
    expect(M20PushCoordinator.hasPushPermission(
        AuthorizationStatus.provisional), isTrue);
    expect(M20PushCoordinator.hasPushPermission(
        AuthorizationStatus.denied), isFalse);
    expect(M20PushCoordinator.hasPushPermission(
        AuthorizationStatus.deniedPermanently), isFalse);
    expect(M20PushCoordinator.hasPushPermission(
        AuthorizationStatus.notDetermined), isFalse);
  });

  testWidgets('M20 inbox has no manual push permission switch or demo rows',
      (tester) async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      expect(request.url.path, '/api/v1/notifications');
      expect(request.headers['x-company-id'], '17');
      return http.Response(jsonEncode({'data': {
        'records': [], 'unread_count': 0, 'page': 1, 'last_page': 1,
      }}), 200);
    });
    final api = SignApiClient(baseUrl: Uri.parse('https://example.test'),
        tokenProvider: () async => 'signed-in-token',
        activeCompanyId: () => ActiveCompanySession.companyId,
        httpClient: client);
    await tester.pumpWidget(MaterialApp(home: NotificationInboxScreen(
      repository: RemoteNotificationRepository(api: api),
    )));
    await tester.pumpAndSettle();
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('No notifications'), findsOneWidget);
    expect(find.text('0 unread'), findsOneWidget);
    expect(find.text('Push notifications'), findsNothing);
    expect(find.byType(Switch), findsNothing);
    expect(find.byType(ListTile), findsNothing);
    expect(requests, hasLength(1));
    api.dispose();
  });

  testWidgets('M20 inbox displays genuine company notifications from the API only',
      (tester) async {
    final client = MockClient((request) async =>
        http.Response(jsonEncode({'data': {
          'records': [{
            'id': 58, 'company_id': 17, 'recipient_user_id': 5,
            'title': 'Real server notification',
            'body': 'A document was signed.',
            'created_at': '2026-11-10T12:00:00Z',
            'read_at': null,
          }],
          'unread_count': 1, 'page': 1, 'last_page': 1,
        }}), 200));
    final api = SignApiClient(baseUrl: Uri.parse('https://example.test'),
        tokenProvider: () async => 'signed-in-token',
        activeCompanyId: () => ActiveCompanySession.companyId,
        httpClient: client);
    await tester.pumpWidget(MaterialApp(home: NotificationInboxScreen(
      repository: RemoteNotificationRepository(api: api),
    )));
    await tester.pumpAndSettle();
    expect(find.text('Real server notification'), findsOneWidget);
    expect(find.text('A document was signed.'), findsOneWidget);
    expect(find.byKey(const Key('notification-58')), findsOneWidget);
    expect(find.text('Push notifications'), findsNothing);
    expect(find.byType(Switch), findsNothing);
    api.dispose();
  });
}
