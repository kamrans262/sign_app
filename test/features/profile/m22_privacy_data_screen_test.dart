import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sign2digital/core/services/sign_api_client.dart';
import 'package:sign2digital/features/profile/presentation/screens/privacy_data_screen.dart';

void main() {
  testWidgets('personal export reports explicit scope, copies only returned fields',
      (tester) async {
    var calls = 0;
    String? copied;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map)['text'] as String?;
      }
      return null;
    });
    addTearDown(() =>
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    final api = SignApiClient(
      baseUrl: Uri.parse('https://example.test'),
      tokenProvider: () async => 'test-token',
      httpClient: MockClient((request) async {
        calls++;
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/me/export');
        expect(request.headers['Authorization'], 'Bearer test-token');
        return http.Response(jsonEncode({'data': {
          'account': {'id': 7, 'name': 'Test Account'},
          'preferences': {'language': 'English'},
          'support_ticket_references': <String>[],
          'scope': 'personal_account_only_company_documents_not_included',
        }}), 200);
      }),
    );
    await tester.pumpWidget(MaterialApp(
      home: PrivacyDataScreen(api: api)));
    await tester.tap(find.byKey(const Key('m22-privacy-export')));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(copied, contains('Test Account'));
    expect(find.textContaining('Personal account data copied'), findsOneWidget);
  });

  testWidgets('deactivation never sends an action without explicit confirmation',
      (tester) async {
    var writes = 0;
    final api = SignApiClient(
      baseUrl: Uri.parse('https://example.test'),
      tokenProvider: () async => 'test-token',
      httpClient: MockClient((request) async {
        writes++;
        return http.Response('{}', 403);
      }),
    );
    await tester.pumpWidget(MaterialApp(
      home: PrivacyDataScreen(api: api)));
    await tester.tap(find.byKey(const Key('m22-privacy-deactivate')));
    await tester.pumpAndSettle();
    expect(find.text('Deactivate Account?'), findsOneWidget);
    await tester.tap(find.text('Keep Account'));
    await tester.pumpAndSettle();
    expect(writes, 0);
    expect(find.byKey(const Key('m22-privacy-scroll')), findsOneWidget);
  });

  testWidgets('account deletion requires explicit phrase and password',
      (tester) async {
    var writes = 0;
    final api = SignApiClient(
      baseUrl: Uri.parse('https://example.test'),
      tokenProvider: () async => 'test-token',
      httpClient: MockClient((request) async {
        writes++;
        return http.Response('{}', 403);
      }),
    );
    await tester.pumpWidget(MaterialApp(home: PrivacyDataScreen(api: api)));
    await tester.ensureVisible(find.byKey(const Key('m22-privacy-delete')));
    await tester.tap(find.byKey(const Key('m22-privacy-delete')));
    await tester.pumpAndSettle();
    expect(find.text('Permanently Delete Account?'), findsOneWidget);
    TextButton button = tester.widget<TextButton>(
        find.byKey(const Key('m22-delete-confirm')));
    expect(button.onPressed, isNull);
    await tester.enterText(find.byKey(const Key('m22-delete-type')), 'DELETE');
    await tester.enterText(find.byKey(const Key('m22-delete-password')),
      'sample-password');
    await tester.pumpAndSettle();
    button = tester.widget<TextButton>(
        find.byKey(const Key('m22-delete-confirm')));
    expect(button.onPressed, isNotNull);
    await tester.tap(find.text('Keep Account'));
    await tester.pumpAndSettle();
    expect(writes, 0);
  });
}
