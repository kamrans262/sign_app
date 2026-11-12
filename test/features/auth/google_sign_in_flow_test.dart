import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:sign2digital/core/services/sign_api_client.dart';
import 'package:sign2digital/features/auth/data/mobile_auth_repository.dart';
import 'package:sign2digital/features/auth/presentation/screens/mobile_auth_gateway.dart';
import 'package:sign2digital/features/auth/presentation/screens/two_factor_login_screen.dart';

class _MemoryTokens implements AuthTokenStorage {
  String? saved;
  @override
  Future<void> delete() async => saved = null;
  @override
  Future<String?> read() async => saved;
  @override
  Future<void> write(String token) async => saved = token;
}

void main() {
  testWidgets('Google button sends signed ID token and opens company invitation',
      (tester) async {
    final storage = _MemoryTokens();
    var requested = false;
    final api = SignApiClient(
      baseUrl: Uri.parse('https://example.test'),
      tokenProvider: () async => storage.saved,
      httpClient: MockClient((request) async {
        if (request.url.path == '/api/v1/auth/google') {
          expect(request.headers.containsKey('Authorization'), isFalse);
          expect((jsonDecode(request.body) as Map)['id_token'],
              'signed-id-token-from-google');
          requested = true;
          return http.Response(jsonEncode({'data': {
            'purpose': 'login', 'access_token': 'server-issued-bearer',
          }}), 200);
        }
        if (request.url.path == '/api/v1/companies') {
          expect(request.headers['Authorization'],
              'Bearer server-issued-bearer');
          return http.Response('{"data":{"companies":[],"active_company_id":null}}', 200);
        }
        if (request.url.path == '/api/v1/companies/invitations/mine') {
          return http.Response(jsonEncode({'data': {'invitations': [
            {'id': 1, 'company_name': 'Existing Owner Company',
              'role': 'member', 'role_name': 'Member',
              'expires_at': '2026-11-25T00:00:00Z'}
          ]}}), 200);
        }
        return http.Response('{"message":"unexpected"}', 404);
      }),
    );
    final repository = MobileAuthRepository(
      api: api, tokenStorage: storage);
    await tester.pumpWidget(MaterialApp(home: MobileAuthGateway(
      repository: repository,
      googleIdTokenProvider: () async => 'signed-id-token-from-google',
    )));
    await tester.tap(find.text('Continue with Google'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(requested, isTrue);
    expect(storage.saved, 'server-issued-bearer');
    expect(find.text('Existing Owner Company'), findsOneWidget);
    expect(find.text('Create Your Company'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('user-canceled Google login does not touch API or replace login',
      (tester) async {
    var called = false;
    final repository = MobileAuthRepository(
      tokenStorage: _MemoryTokens(),
      api: SignApiClient(
        baseUrl: Uri.parse('https://example.test'),
        httpClient: MockClient((request) async {
          called = true;
          return http.Response('{"message":"unexpected"}', 500);
        }),
      ),
    );
    await tester.pumpWidget(MaterialApp(home: MobileAuthGateway(
      repository: repository, googleIdTokenProvider: () async => null,
    )));
    await tester.tap(find.text('Continue with Google'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(called, false);
    expect(find.text('Welcome Back'), findsOneWidget);
    expect(repository.isSignedIn, false);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Google login cannot bypass authenticator 2FA',
      (tester) async {
    final storage = _MemoryTokens();
    var secondFactorVerified = false;
    final repository = MobileAuthRepository(
      tokenStorage: storage,
      api: SignApiClient(
        baseUrl: Uri.parse('https://example.test'),
        tokenProvider: () async => storage.saved,
        httpClient: MockClient((request) async {
          if (request.url.path == '/api/v1/auth/google') {
            return http.Response(jsonEncode({'data': {
              'purpose': 'login', 'requires_two_factor': true,
              'two_factor_ticket': 'a' * 64,
            }}), 200);
          }
          if (request.url.path == '/api/v1/auth/2fa/verify') {
            secondFactorVerified = true;
            expect((jsonDecode(request.body) as Map)['ticket'], 'a' * 64);
            return http.Response(jsonEncode({'data': {
              'purpose': 'login', 'access_token': 'two-factor-bearer',
            }}), 200);
          }
          if (request.url.path == '/api/v1/companies') {
            return http.Response('{"data":{"companies":[],"active_company_id":null}}', 200);
          }
          if (request.url.path == '/api/v1/companies/invitations/mine') {
            return http.Response('{"data":{"invitations":[]}}', 200);
          }
          return http.Response('{"message":"unknown"}', 404);
        }),
      ),
    );

    await tester.pumpWidget(MaterialApp(home: MobileAuthGateway(
      repository: repository, googleIdTokenProvider: () async => 'id-token',
    )));
    await tester.tap(find.text('Continue with Google'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byType(TwoFactorLoginScreen), findsOneWidget);
    expect(repository.isSignedIn, false);
    expect(storage.saved, isNull);

    await tester.enterText(find.byKey(const Key('m24-login-code')), '123456');
    await tester.tap(find.byKey(const Key('m24-login-verify')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(secondFactorVerified, isTrue);
    expect(repository.isSignedIn, true);
    expect(storage.saved, 'two-factor-bearer');
    expect(tester.takeException(), isNull);
  });

  test('Google API error never stores a forged or unverified bearer', () async {
    final tokens = _MemoryTokens();
    final repository = MobileAuthRepository(
      tokenStorage: tokens, api: SignApiClient(
        baseUrl: Uri.parse('https://example.test'),
        httpClient: MockClient((request) async =>
          http.Response('{"message":"Invalid Google login."}', 422)),
      ),
    );
    await expectLater(repository.signInWithGoogle('fake-id-token',
      rememberMe: true), throwsA(isA<SignApiException>()));
    expect(repository.isSignedIn, false);
    expect(tokens.saved, isNull);
  });
}
