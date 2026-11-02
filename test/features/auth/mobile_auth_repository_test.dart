import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:sign2digital/core/services/sign_api_client.dart';
import 'package:sign2digital/features/auth/data/mobile_auth_repository.dart';
import 'package:sign2digital/features/auth/data/remote_account_repository.dart';
import 'package:sign2digital/features/auth/domain/account_profile.dart';

class MemoryAuthStorage implements AuthTokenStorage {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String token) async { value = token; }
  @override
  Future<void> delete() async { value = null; }
}

void main() {
  final base = Uri.parse('https://forestgreen-pigeon-673192.hostingersite.com');

  test('password validation starts OTP but does not sign in', () async {
    final memory = MemoryAuthStorage();
    final api = SignApiClient(
      baseUrl: base,
      httpClient: MockClient((request) async {
        expect(request.url.path, '/api/v1/auth/login');
        expect(request.headers['Authorization'], isNull);
        final data = jsonDecode(request.body) as Map<String, dynamic>;
        expect(data['email'], 'demo@example.test');
        return http.Response(jsonEncode({'data': {
          'challenge_id': '11111111-1111-4111-8111-111111111111',
          'purpose': 'login',
        }}), 200);
      }),
    );
    final repository = MobileAuthRepository(api: api, tokenStorage: memory);
    final challenge = await repository.beginLogin('demo@example.test', 'test-password');
    expect(challenge.purpose, 'login');
    expect(repository.isSignedIn, false);
    expect(memory.value, isNull);
  });

  test('only correct OTP response creates a remembered authenticated session', () async {
    final memory = MemoryAuthStorage();
    final api = SignApiClient(
      baseUrl: base,
      httpClient: MockClient((request) async {
        expect(request.url.path, '/api/v1/auth/otp/verify');
        expect(request.headers['Authorization'], isNull);
        final data = jsonDecode(request.body) as Map<String, dynamic>;
        expect(data['code'], '123456');
        return http.Response(jsonEncode({'data': {
          'purpose': 'login',
          'access_token': 'secure-token-issued-after-otp',
          'token_type': 'Bearer',
        }}), 200);
      }),
    );
    final repo = MobileAuthRepository(api: api, tokenStorage: memory);
    final outcome = await repo.verify(
      const EmailOtpChallenge(
        id: '11111111-1111-4111-8111-111111111111',
        purpose: 'login',
      ),
      '123456',
      rememberMe: true,
    );
    expect(outcome.accessToken, 'secure-token-issued-after-otp');
    expect(repo.isSignedIn, true);
    expect(memory.value, 'secure-token-issued-after-otp');
  });

  test('unremembered session never saves a bearer token to storage', () async {
    final storage = MemoryAuthStorage()..value = 'stale-token';
    final api = SignApiClient(
      baseUrl: base,
      httpClient: MockClient((request) async => http.Response(
        jsonEncode({'data': {'purpose': 'login', 'access_token': 'new-token'}}),
        200,
      )),
    );
    final repo = MobileAuthRepository(api: api, tokenStorage: storage);
    await repo.verify(
      const EmailOtpChallenge(id: '11111111-1111-4111-8111-111111111111', purpose: 'login'),
      '123456',
      rememberMe: false,
    );
    expect(repo.isSignedIn, true);
    expect(storage.value, isNull);
  });

  test('password reset verification never issues or saves a login token', () async {
    final storage = MemoryAuthStorage();
    final api = SignApiClient(
      baseUrl: base,
      httpClient: MockClient((request) async => http.Response(
        jsonEncode({'data': {'purpose': 'reset', 'reset_token': 'reset-grant'}}),
        200,
      )),
    );
    final repo = MobileAuthRepository(api: api, tokenStorage: storage);
    final result = await repo.verify(
      const EmailOtpChallenge(id: '11111111-1111-4111-8111-111111111111', purpose: 'reset'),
      '123456',
      rememberMe: false,
    );
    expect(result.resetToken, 'reset-grant');
    expect(result.accessToken, isNull);
    expect(repo.isSignedIn, false);
    expect(storage.value, isNull);
  });

  test('invalid OTP fails and never opens a session', () async {
    final storage = MemoryAuthStorage();
    final api = SignApiClient(
      baseUrl: base,
      httpClient: MockClient((request) async => http.Response(
        jsonEncode({'message': 'Invalid or expired code.'}),
        422,
      )),
    );
    final repo = MobileAuthRepository(api: api, tokenStorage: storage);
    await expectLater(
      repo.verify(
        const EmailOtpChallenge(id: '11111111-1111-4111-8111-111111111111', purpose: 'login'),
        '000000',
        rememberMe: true,
      ),
      throwsA(isA<SignApiException>().having((e) => e.statusCode, 'HTTP', 422)),
    );
    expect(repo.isSignedIn, false);
    expect(storage.value, isNull);
  });

  test('resend returns a new challenge id without exposing a secret code', () async {
    final api = SignApiClient(
      baseUrl: base,
      httpClient: MockClient((request) async => http.Response(
        jsonEncode({'data': {
          'challenge_id': '22222222-2222-4222-8222-222222222222',
          'purpose': 'login',
        }}),
        200,
      )),
    );
    final repo = MobileAuthRepository(api: api, tokenStorage: MemoryAuthStorage());
    final resent = await repo.resend(
      const EmailOtpChallenge(id: '11111111-1111-4111-8111-111111111111', purpose: 'login'),
    );
    expect(resent.id, '22222222-2222-4222-8222-222222222222');
  });

  test('profile uses authenticated user API, not a hardcoded demo identity', () async {
    final storage = MemoryAuthStorage();
    final api = SignApiClient(
      baseUrl: base,
      tokenProvider: () async => 'injected-test-token',
      httpClient: MockClient((request) async {
        if (request.url.path == '/api/v1/auth/otp/verify') {
          return http.Response(jsonEncode({'data': {'purpose': 'login', 'access_token': 'session-token'}}), 200);
        }
        if (request.method == 'GET' && request.url.path == '/api/v1/me') {
          return http.Response(jsonEncode({'data': {'user': {
            'id': 42,
            'name': 'Verified Customer',
            'email': 'verified@example.test',
            'phone_number': '0712345678',
            'country_iso_code': 'CH',
            'dialing_code': '+41',
          }}}), 200);
        }
        if (request.method == 'PATCH' && request.url.path == '/api/v1/me') {
          final data = jsonDecode(request.body) as Map<String, dynamic>;
          expect(data['name'], 'Updated Customer');
          return http.Response(jsonEncode({'data': {'user': data}}), 200);
        }
        return http.Response(jsonEncode({'message': 'Not found'}), 404);
      }),
    );
    final mobile = MobileAuthRepository(api: api, tokenStorage: storage);
    await mobile.verify(
      const EmailOtpChallenge(id: '11111111-1111-4111-8111-111111111111', purpose: 'login'),
      '123456',
      rememberMe: true,
    );
    final profiles = RemoteAccountRepository(auth: mobile);
    final account = await profiles.currentAccount();
    expect(account?.fullName, 'Verified Customer');
    expect(account?.email, 'verified@example.test');
    expect(account?.id, '42');
    await profiles.saveDraft(
      AccountProfile(
        id: '42',
        fullName: 'Updated Customer',
        email: 'verified@example.test',
        countryIsoCode: 'CH',
        dialingCode: '+41',
        phoneNumber: '0712345678',
      ),
    );
  });

  test('logout clears stored token after verified sign-in', () async {
    final storage = MemoryAuthStorage();
    final api = SignApiClient(
      baseUrl: base,
      tokenProvider: () async => 'session-token',
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/otp/verify')) {
          return http.Response(jsonEncode({'data': {'purpose': 'login', 'access_token': 'session-token'}}), 200);
        }
        expect(request.url.path, '/api/v1/auth/logout');
        return http.Response(jsonEncode({'message': 'Signed out.'}), 200);
      }),
    );
    final auth = MobileAuthRepository(api: api, tokenStorage: storage);
    await auth.verify(
      const EmailOtpChallenge(id: '11111111-1111-4111-8111-111111111111', purpose: 'login'),
      '123456',
      rememberMe: true,
    );
    expect(storage.value, 'session-token');
    await auth.logout();
    expect(auth.isSignedIn, false);
    expect(storage.value, isNull);
  });
}
