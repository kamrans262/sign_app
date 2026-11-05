import '../../../core/services/sign_api_client.dart';
import '../../auth/data/mobile_auth_repository.dart';
import 'profile_preferences_repository.dart';

/// M22 real cross-device preference storage; only a validated server
/// response updates the shared session.
class RemoteProfilePreferencesRepository implements ProfilePreferencesRepository {
  RemoteProfilePreferencesRepository({SignApiClient? api})
      : _api = api ?? MobileAuthRepository.shared.api;
  final SignApiClient _api;

  static ProfilePreferences parse(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw const SignApiException('Invalid preferences response.');
    }
    return ProfilePreferences.fromJson(data);
  }

  @override
  Future<ProfilePreferences> load() async {
    final saved = parse(await _api.get('/api/v1/me/preferences'));
    ProfilePreferencesSession.current.value = saved;
    return saved;
  }

  @override
  Future<void> save(ProfilePreferences preferences) async {
    final saved = parse(await _api.request(
      'PATCH', '/api/v1/me/preferences',
      data: preferences.toJson(),
    ));
    ProfilePreferencesSession.current.value = saved;
  }
}
