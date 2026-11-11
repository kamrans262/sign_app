import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:sign2digital/core/services/sign_api_client.dart';
import 'package:sign2digital/features/auth/data/mobile_auth_repository.dart';
import 'package:sign2digital/features/auth/presentation/screens/two_factor_login_screen.dart';

class _Storage implements AuthTokenStorage {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String token) async { value = token; }
  @override
  Future<void> delete() async { value = null; }
}

void main() {
  test('email OTP with 2FA returns no bearer until authenticator proof', () async {
    final ticket = 'a' * 64;
    final storage = _Storage();
    final seen = <String>[];
    final api = SignApiClient(
      baseUrl: Uri.parse('https://example.test'),
      httpClient: MockClient((request) async {
        seen.add(request.url.path);
        if (request.url.path == '/api/v1/auth/otp/verify') {
          return http.Response(jsonEncode({'data': {
            'purpose': 'login',
            'requires_two_factor': true,
            'two_factor_ticket': ticket,
            'expires_in': 300,
          }}), 200);
        }
        if (request.url.path == '/api/v1/auth/2fa/verify') {
          expect(request.headers['Authorization'], isNull);
          final body = jsonDecode(request.body) as Map<String,dynamic>;
          expect(body['ticket'], ticket);
          if (body['code'] == '999999') {
            return http.Response(jsonEncode({
              'message': 'Invalid authenticator or recovery code.',
            }), 422);
          }
          expect(body['code'], '234567');
          return http.Response(jsonEncode({'data': {
            'purpose': 'login', 'access_token': 'verified-totp-token',
            'token_type': 'Bearer',
          }}), 200);
        }
        throw StateError('Unexpected request: ${request.url.path}');
      }),
    );
    final repository = MobileAuthRepository(api: api, tokenStorage: storage);
    final result = await repository.verify(
      const EmailOtpChallenge(
        id: '11111111-1111-4111-8111-111111111111',
        purpose: 'login'),
      '123456', rememberMe: true);
    expect(result.requiresTwoFactor, true);
    expect(result.twoFactorTicket, ticket);
    expect(result.accessToken, isNull);
    expect(repository.isSignedIn, false);
    expect(storage.value, isNull);
    await expectLater(repository.verifyTwoFactor(ticket, '999999',
      rememberMe: true), throwsA(isA<SignApiException>()));
    expect(repository.isSignedIn, false);
    await repository.verifyTwoFactor(ticket, '234567', rememberMe: true);
    expect(repository.isSignedIn, true);
    expect(storage.value, 'verified-totp-token');
    expect(seen, [
      '/api/v1/auth/otp/verify',
      '/api/v1/auth/2fa/verify',
      '/api/v1/auth/2fa/verify',
    ]);
  });

  testWidgets('authenticator sign-in renders recovery code fallback and checks length',
      (tester) async {
    String? submitted;
    await tester.pumpWidget(MaterialApp(
      home: TwoFactorLoginScreen(onVerify: (code) async {
        submitted = code;
      }),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('recovery codes'), findsWidgets);
    await tester.tap(find.byKey(const Key('m24-login-verify')));
    await tester.pump();
    expect(find.byKey(const Key('m24-login-error')), findsOneWidget);
    expect(submitted, isNull);
    await tester.enterText(find.byType(TextFormField), 'AAAA-BBBB-CCCC-DDDD');
    await tester.tap(find.byKey(const Key('m24-login-verify')));
    await tester.pump();
    expect(submitted, 'AAAA-BBBB-CCCC-DDDD');
    expect(tester.takeException(), isNull);
  });
}
