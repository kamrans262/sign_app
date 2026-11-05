import '../../../core/services/active_company_session.dart';
import '../../../core/services/sign_api_client.dart';
import '../../auth/data/mobile_auth_repository.dart';

class M20NotificationPreferences {
  const M20NotificationPreferences({
    required this.inAppEnabled, required this.pushEnabled,
    required this.pushAvailable, required this.locale, required this.timezone,
  });
  final bool inAppEnabled, pushEnabled, pushAvailable;
  final String locale, timezone;

  factory M20NotificationPreferences.fromJson(Map<String, dynamic> data) {
    return M20NotificationPreferences(
      inAppEnabled: data['in_app_enabled'] == true || data['in_app_enabled'] == 1,
      pushEnabled: data['push_enabled'] == true || data['push_enabled'] == 1,
      pushAvailable: data['push_available'] == true || data['push_available'] == 1,
      locale: (data['locale'] ?? 'en').toString(),
      timezone: (data['timezone'] ?? 'UTC').toString(),
    );
  }
}

class M20PushApi {
  M20PushApi({SignApiClient? api})
      : _api = api ?? MobileAuthRepository.shared.api;
  static final shared = M20PushApi();
  final SignApiClient _api;

  static Map<String, dynamic> _data(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is! Map) {
      throw const SignApiException('Invalid push preferences response.');
    }
    return Map<String, dynamic>.from(data);
  }

  int _company() {
    final company = ActiveCompanySession.companyId;
    if (company == null || company < 1) {
      throw const SignApiException('Select a company first.');
    }
    return company;
  }

  void _check(int company) {
    if (ActiveCompanySession.companyId != company) {
      throw const SignApiException('Company changed during push setup.');
    }
  }

  Future<M20NotificationPreferences> preferences() async {
    final company = _company();
    final response = await _api.get('/api/v1/notification-preferences',
        companyScoped: true);
    _check(company);
    final prefs = _data(response)['preferences'];
    if (prefs is! Map) {
      throw const SignApiException('Missing notification preferences.');
    }
    return M20NotificationPreferences.fromJson(Map<String, dynamic>.from(prefs));
  }

  Future<M20NotificationPreferences> update(M20NotificationPreferences current, {
    required bool pushEnabled,
  }) async {
    final company = _company();
    final response = await _api.put('/api/v1/notification-preferences',
        companyScoped: true,
        data: <String, dynamic>{
          'in_app_enabled': current.inAppEnabled,
          'push_enabled': pushEnabled,
          'locale': current.locale,
          'timezone': current.timezone,
        });
    _check(company);
    final prefs = _data(response)['preferences'];
    if (prefs is! Map) {
      throw const SignApiException('Missing updated preferences.');
    }
    return M20NotificationPreferences.fromJson(Map<String, dynamic>.from(prefs));
  }

  Future<void> register({
    required String installationId,
    required String platform,
    required String token,
  }) async {
    final company = _company();
    final response = await _api.post('/api/v1/push-devices',
        companyScoped: true, data: {
          'installation_id': installationId,
          'platform': platform,
          'token': token,
        });
    _check(company);
    if (_data(response)['registered'] != true) {
      throw const SignApiException('Device registration was not confirmed.');
    }
  }

  /// The endpoint is deliberately user-wide: all companies are revoked when
  /// this device signs out of the current account.
  Future<void> revoke({required String installationId}) async {
    await _api.request('DELETE', '/api/v1/push-devices',
        data: {'installation_id': installationId});
  }
}
