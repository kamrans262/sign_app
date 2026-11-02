import '../domain/account_profile.dart';
import 'account_repository.dart';
import 'mobile_auth_repository.dart';

/// Real profile data for an OTP-authenticated mobile account.
/// The approved Profile / Edit Profile UI is reused unchanged.
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
      throw const FormatException('Missing account response.');
    }
    final user = payload['user'];
    if (user is! Map<String, dynamic>) {
      throw const FormatException('Missing user identity.');
    }
    return AccountProfile(
      id: (user['id'] ?? '').toString(),
      fullName: (user['name'] ?? '').toString(),
      email: (user['email'] ?? '').toString(),
      phoneNumber: (user['phone_number'] ?? '').toString(),
      countryIsoCode: (user['country_iso_code'] ?? 'CH').toString(),
      dialingCode: (user['dialing_code'] ?? '+41').toString(),
    );
  }

  @override
  Future<void> saveDraft(AccountProfile profile) async {
    await _auth.updateProfile({
      'name': profile.fullName,
      'email': profile.email,
      'phone_number': profile.phoneNumber,
      'country_iso_code': profile.countryIsoCode,
      'dialing_code': profile.dialingCode,
    });
  }
}
