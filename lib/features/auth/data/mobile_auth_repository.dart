import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/services/sign_api_client.dart';
import '../../../core/services/active_company_session.dart';
import '../../../core/services/profile_photo_session.dart';
import '../presentation/screens/create_account_screen.dart';
import '../../reminders/services/m20_push_coordinator.dart';

/// Passwords and OTP codes are never saved in Flutter preferences or logs.
abstract class AuthTokenStorage {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> delete();
}

class SecureAuthTokenStorage implements AuthTokenStorage {
  const SecureAuthTokenStorage();

  static const _key = 'sign2digital.mobile.auth.bearer';
  static const _secure = FlutterSecureStorage();

  @override
  Future<String?> read() => _secure.read(key: _key);

  @override
  Future<void> write(String token) => _secure.write(key: _key, value: token);

  @override
  Future<void> delete() => _secure.delete(key: _key);
}

class EmailOtpChallenge {
  const EmailOtpChallenge({required this.id, required this.purpose});

  final String id;
  final String purpose;

  factory EmailOtpChallenge.fromData(Map<String, dynamic> raw) {
    final id = raw['challenge_id'];
    final purpose = raw['purpose'];
    if (id is! String || id.isEmpty || purpose is! String) {
      throw const SignApiException('Invalid verification response.');
    }
    return EmailOtpChallenge(id: id, purpose: purpose);
  }
}

class EmailOtpVerification {
  const EmailOtpVerification({
    required this.purpose,
    this.accessToken,
    this.resetToken,
    this.twoFactorTicket,
  });

  final String purpose;
  final String? accessToken;
  final String? resetToken;
  /// One-use short-lived verifier; never a bearer session.
  final String? twoFactorTicket;
  bool get requiresTwoFactor => twoFactorTicket != null;
}

/// One central mobile auth repository. UI components stay unchanged.
///
/// The Admin Panel uses Laravel web sessions and is intentionally not affected
/// by this email OTP implementation.
class MobileAuthRepository {
  MobileAuthRepository({SignApiClient? api, AuthTokenStorage? tokenStorage})
      : _tokenStorage = tokenStorage ?? const SecureAuthTokenStorage() {
    _api = api ?? SignApiClient(tokenProvider: () async => _sessionToken,
      activeCompanyId: () => ActiveCompanySession.companyId);
  }

  static final MobileAuthRepository shared = MobileAuthRepository();

  late final SignApiClient _api;
  final AuthTokenStorage _tokenStorage;
  String? _sessionToken;

  SignApiClient get api => _api;

  bool get isSignedIn => _sessionToken != null && _sessionToken!.isNotEmpty;

  /// Restore remembered sign-in only after the server confirms the bearer.
  Future<bool> restoreRememberedSession() async {
    final saved = await _tokenStorage.read();
    if (saved == null || saved.isEmpty) return false;
    _sessionToken = saved;
    try {
      await _api.currentAccount();
      return true;
    } catch (error) {
      _sessionToken = null;
      ProfilePhotoSession.setPhoto(null);
      ActiveCompanySession.clear();
      // Only permanently discard a token if the backend explicitly rejects it.
      // A network outage must not delete a still-valid remembered session.
      if (error is SignApiException &&
          (error.statusCode == 401 || error.statusCode == 403)) {
        await _tokenStorage.delete();
      }
      return false;
    }
  }

  /// Complete Google login through our own token-issuing API. A Google
  /// credential never becomes the application's bearer session.
  Future<EmailOtpVerification> signInWithGoogle(String googleIdToken,
      {required bool rememberMe}) async {
    if (googleIdToken.isEmpty) {
      throw const SignApiException('Google sign-in did not return a token.');
    }
    await M20PushCoordinator.shared.revokeBeforeLogout();
    await _tokenStorage.delete();
    _sessionToken = null;
    ActiveCompanySession.clear();

    final response = await _api.post('/api/v1/auth/google',
      authenticated: false, data: {
        'id_token': googleIdToken,
        'device_name': 'Sign2Digital Google Mobile',
      });
    final data = _data(response);
    if (data['purpose'] != 'login') {
      throw const SignApiException('Unexpected Google authentication response.');
    }
    if (data['requires_two_factor'] == true) {
      final ticket = data['two_factor_ticket'];
      if (ticket is! String || ticket.length != 64) {
        throw const SignApiException('Invalid authenticator challenge.');
      }
      return EmailOtpVerification(
        purpose: 'login', twoFactorTicket: ticket);
    }
    final bearer = data['access_token'];
    if (bearer is! String || bearer.isEmpty) {
      throw const SignApiException('Missing authentication token.');
    }
    _sessionToken = bearer;
    if (rememberMe) {
      try {
        await _tokenStorage.write(bearer);
      } catch (_) {
        // Secure storage may be unavailable; keep a memory-only session.
      }
    }
    return EmailOtpVerification(purpose: 'login', accessToken: bearer);
  }

  Future<EmailOtpChallenge> beginLogin(String email, String password) async {
    final response = await _api.post(
      '/api/v1/auth/login',
      authenticated: false,
      data: {'email': email, 'password': password},
    );
    return EmailOtpChallenge.fromData(_data(response));
  }

  Future<EmailOtpChallenge> beginRegistration(CreateAccountDraft draft) async {
    final response = await _api.post(
      '/api/v1/auth/register',
      authenticated: false,
      data: {
        'name': draft.fullName,
        'email': draft.email,
        'phone_number': draft.phoneNumber,
        'country_iso_code': draft.country.isoCode,
        'dialing_code': draft.country.dialCode,
        'password': draft.password,
        'password_confirmation': draft.password,
      },
    );
    return EmailOtpChallenge.fromData(_data(response));
  }

  Future<EmailOtpChallenge> beginPasswordReset(String email) async {
    final response = await _api.post(
      '/api/v1/auth/password/forgot',
      authenticated: false,
      data: {'email': email},
    );
    return EmailOtpChallenge.fromData(_data(response));
  }

  Future<EmailOtpChallenge> resend(EmailOtpChallenge challenge) async {
    final response = await _api.post(
      '/api/v1/auth/otp/resend',
      authenticated: false,
      data: {'challenge_id': challenge.id},
    );
    final next = EmailOtpChallenge.fromData(_data(response));
    if (next.purpose != challenge.purpose) {
      throw const SignApiException('Resent verification type does not match.');
    }
    return next;
  }

  Future<EmailOtpVerification> verify(
    EmailOtpChallenge challenge,
    String code, {
    required bool rememberMe,
  }) async {
    // Revoke this installation before switching accounts.
    await M20PushCoordinator.shared.revokeBeforeLogout();
    // Remove any bearer from an older account *before* consuming this code.
    // If secure storage is inaccessible, leave OTP unused so it can be retried.
    await _tokenStorage.delete();
    // A newly verified account must never inherit the former account's
    // bearer or company context, even when OTP verification later fails.
    _sessionToken = null;
    ActiveCompanySession.clear();
    final response = await _api.post(
      '/api/v1/auth/otp/verify',
      authenticated: false,
      data: {
        'challenge_id': challenge.id,
        'code': code,
        'device_name': 'Sign2Digital Flutter',
      },
    );
    final data = _data(response);
    final purpose = data['purpose'];
    if (purpose is! String || purpose != challenge.purpose) {
      throw const SignApiException('Verification response does not match this request.');
    }

    if (purpose == 'reset') {
      final token = data['reset_token'];
      if (token is! String || token.isEmpty) {
        throw const SignApiException('Missing password reset authorization.');
      }
      return EmailOtpVerification(purpose: purpose, resetToken: token);
    }

    if (data['requires_two_factor'] == true) {
      final ticket = data['two_factor_ticket'];
      if (purpose != 'login' || ticket is! String || ticket.length != 64) {
        throw const SignApiException('Invalid authenticator challenge.');
      }
      return EmailOtpVerification(
        purpose: purpose, twoFactorTicket: ticket,
      );
    }

    final token = data['access_token'];
    if (token is! String || token.isEmpty) {
      throw const SignApiException('Missing authentication token.');
    }
    _sessionToken = token;
    if (rememberMe) {
      try {
        await _tokenStorage.write(token);
      } catch (_) {
        // OTP has already been consumed. Keep a valid memory-only session;
        // never fall back to plain preferences or unencrypted storage.
      }
    }
    return EmailOtpVerification(purpose: purpose, accessToken: token);
  }

  /// Completes 2FA only after an email-OTP challenge. The server never
  /// returns a bearer for an unverified authenticator response.
  Future<void> verifyTwoFactor(
    String ticket, String code, {required bool rememberMe}
  ) async {
    if (isSignedIn) {
      throw const SignApiException('Sign out before starting another sign-in.');
    }
    final response = await _api.post('/api/v1/auth/2fa/verify',
      authenticated: false, data: {'ticket': ticket, 'code': code});
    final data = _data(response);
    final token = data['access_token'];
    if (data['purpose'] != 'login' || token is! String || token.isEmpty) {
      throw const SignApiException('Authenticator verification did not complete.');
    }
    _sessionToken = token;
    if (rememberMe) {
      try {
        await _tokenStorage.write(token);
      } catch (_) {
        // Preserve a verified memory-only session, never plaintext storage.
      }
    }
  }

  Future<Map<String, dynamic>> currentProfile() => _api.currentAccount();

  Future<void> updateProfile(Map<String, dynamic> changes) async {
    await _api.request('PATCH', '/api/v1/me', data: changes);
  }

  Future<void> resetPassword({
    required String email,
    required String resetToken,
    required String newPassword,
  }) async {
    await _api.post(
      '/api/v1/auth/password/reset',
      authenticated: false,
      data: {
        'email': email,
        'reset_token': resetToken,
        'password': newPassword,
        'password_confirmation': newPassword,
      },
    );
  }

  Future<void> logout() async {
    try {
      await M20PushCoordinator.shared.revokeBeforeLogout();
      if (isSignedIn) await _api.post('/api/v1/auth/logout');
    } finally {
      _sessionToken = null;
      ActiveCompanySession.clear();
      ProfilePhotoSession.setPhoto(null);
      await _tokenStorage.delete();
    }
  }

  static Map<String, dynamic> _data(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw const SignApiException('Unexpected server response.');
    }
    return data;
  }

  void dispose() => _api.dispose();
}
