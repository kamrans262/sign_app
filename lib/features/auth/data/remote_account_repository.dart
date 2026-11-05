import 'dart:typed_data';

import '../../../core/services/profile_photo_session.dart';
import '../../../core/services/sign_api_client.dart';
import '../domain/account_profile.dart';
import 'account_repository.dart';
import 'mobile_auth_repository.dart';

/// Real M22 profile data. Account identity is server-authoritative and
/// secure photos are fetched only after checking the current account.
class RemoteAccountRepository implements AccountRepository {
  RemoteAccountRepository({MobileAuthRepository? auth})
      : _auth = auth ?? MobileAuthRepository.shared;

  final MobileAuthRepository _auth;

  @override
  Future<AccountProfile?> currentAccount() async {
    if (!_auth.isSignedIn) return null;
    final response = await _auth.currentProfile();
    final payload = response['data'];
    if (payload is! Map<String, dynamic>) {
      throw const SignApiException('Missing account response.');
    }
    final user = payload['user'];
    if (user is! Map<String, dynamic>) {
      throw const SignApiException('Missing user identity.');
    }
    final profile = AccountProfile(
      id: (user['id'] ?? '').toString(),
      fullName: (user['name'] ?? '').toString(),
      email: (user['email'] ?? '').toString(),
      phoneNumber: (user['phone_number'] ?? '').toString(),
      countryIsoCode: (user['country_iso_code'] ?? 'CH').toString(),
      dialingCode: (user['dialing_code'] ?? '+41').toString(),
      title: user['job_title']?.toString(),
    );
    // Clear prior-account photo before attempting the authenticated request.
    // A network failure can never show another account's image.
    ProfilePhotoSession.setPhoto(null);
    if (payload['has_photo'] == true) {
      try {
        final photo = await _auth.api.getPrivateAttachment(
          '/api/v1/me/photo', mimeType: 'image/jpeg',
          companyScoped: false, maxBytes: 4 * 1024 * 1024,
        );
        if (_auth.isSignedIn) ProfilePhotoSession.setPhoto(photo);
      } catch (_) {
        // Profile fields remain available even when the image is unavailable.
      }
    }
    return profile;
  }

  @override
  Future<void> saveDraft(AccountProfile profile) async {
    if (!_auth.isSignedIn) {
      throw const SignApiException('Sign in to update your profile.');
    }
    final current = await _auth.currentProfile();
    final me = current['data'];
    if (me is! Map<String, dynamic> ||
        me['user'] is! Map<String, dynamic>) {
      throw const SignApiException('Unable to verify your account.');
    }
    final verifiedEmail = (me['user']['email'] ?? '').toString();
    if (profile.email.trim().toLowerCase() != verifiedEmail.toLowerCase()) {
      throw const SignApiException(
        'Email changes require a verification code. Use Verify New Email.');
    }
    await _auth.updateProfile({
      'name': profile.fullName.trim(),
      'email': verifiedEmail,
      'phone_number': profile.phoneNumber.trim(),
      'country_iso_code': profile.countryIsoCode,
      'dialing_code': profile.dialingCode,
      'job_title': profile.title?.trim(),
    });
  }

  Future<void> uploadPhoto(Uint8List bytes) async {
    if (bytes.isEmpty || bytes.length > 4 * 1024 * 1024) {
      throw const SignApiException('Select an image under 4 MB.');
    }
    final result = await _auth.api.postMultipart('/api/v1/me/photo',
      filename: 'profile.jpg', bytes: bytes, fieldName: 'photo',
      maxBytes: 4 * 1024 * 1024);
    if (result['data'] is! Map<String, dynamic> ||
        result['data']['has_photo'] != true) {
      throw const SignApiException('Photo could not be saved.');
    }
    // Reload the private server-normalized JPEG, never use unchecked local bytes.
    final stored = await _auth.api.getPrivateAttachment(
      '/api/v1/me/photo', mimeType: 'image/jpeg',
      companyScoped: false, maxBytes: 4 * 1024 * 1024,
    );
    ProfilePhotoSession.setPhoto(stored);
  }

  Future<void> removePhoto() async {
    final result = await _auth.api.delete('/api/v1/me/photo');
    if (result['data'] is! Map<String, dynamic> ||
        result['data']['has_photo'] != false) {
      throw const SignApiException('Unable to remove profile photo.');
    }
    ProfilePhotoSession.setPhoto(null);
  }

  Future<String> startEmailChange({
    required String email,
    required String password,
  }) async {
    final response = await _auth.api.post('/api/v1/me/email-change',
      data: {'email': email.trim().toLowerCase(), 'password': password});
    final data = response['data'];
    if (data is! Map<String, dynamic> || data['challenge_id'] is! String) {
      throw const SignApiException('Email verification could not start.');
    }
    return data['challenge_id'] as String;
  }

  Future<bool> verifyEmailChange({
    required String challengeId,
    required String code,
  }) async {
    final response = await _auth.api.post('/api/v1/me/email-change/verify',
      data: {'challenge_id':challengeId,'code':code});
    final data = response['data'];
    return data is Map<String, dynamic> &&
      data['verified'] == true && data['requires_login'] == true;
  }
}
