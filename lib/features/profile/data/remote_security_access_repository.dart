import '../../../core/services/sign_api_client.dart';
import '../../auth/data/mobile_auth_repository.dart';
import 'security_access_repository.dart';

/// Account-wide verified Sanctum device sessions. The existing mandatory
/// email OTP is not mislabeled as optional enrolled authenticator 2FA.
class RemoteSecurityAccessRepository implements SecurityAccessRepository {
  RemoteSecurityAccessRepository({SignApiClient? api})
      : _api = api ?? MobileAuthRepository.shared.api;

  final SignApiClient _api;

  static Map<String, dynamic> _object(Object? raw) {
    if (raw is Map<String, dynamic>) return raw;
    throw const SignApiException('Invalid security response.');
  }

  @override
  Future<SecurityOverview> load() async {
    final data = _object((await _api.get('/api/v1/me/security'))['data']);
    final values = data['sessions'];
    if (values is! List) throw const SignApiException('Invalid session list.');
    final sessions = <SecurityDeviceSession>[];
    for (final raw in values) {
      final value = _object(raw);
      final name = (value['device_name'] ?? 'Sign2Digital session').toString();
      final id = (value['id'] ?? '').toString();
      if (int.tryParse(id) == null || int.parse(id) <= 0 ||
          value['is_current'] is! bool) {
        throw const SignApiException('Invalid verified device session.');
      }
      final seen = value['last_used_at']?.toString() ??
          value['created_at']?.toString() ?? 'Unknown';
      sessions.add(SecurityDeviceSession(
        id: id, deviceName: name,
        location: 'Location unavailable',
        agentAndLastSeen: 'Last used: $seen',
        isCurrent: value['is_current'] as bool,
        isMobile: RegExp('iphone|android|ipad|mobile', caseSensitive: false)
            .hasMatch(name),
      ));
    }
    final twoFactor = data['two_factor_enabled'];
    return SecurityOverview(
      twoFactorEnabled: twoFactor is bool ? twoFactor : null,
      sessions: List.unmodifiable(sessions),
      demoOnly: false,
    );
  }

  @override
  Future<bool> changeTwoFactor({
    required bool enable,
    required String confirmationPassword,
  }) async {
    // No separate verified TOTP enrollment or recovery exists yet.
    // Never return true or enable a fake 2FA control.
    return false;
  }

  @override
  Future<bool> revokeOtherSessions({
    required String confirmationPassword,
  }) async {
    final response = await _api.post('/api/v1/me/sessions/revoke-others',
      data: {'password': confirmationPassword});
    final data = _object(response['data']);
    return data['revoked'] is num && (data['revoked'] as num) >= 0;
  }

  @override
  Future<bool> revokeSession({
    required String sessionId,
    required String confirmationPassword,
  }) async {
    final id = int.tryParse(sessionId);
    if (id == null || id <= 0) {
      throw const SignApiException('Invalid session.');
    }
    final response = await _api.request(
      'DELETE', '/api/v1/me/sessions/$id',
      data: {'password': confirmationPassword},
    );
    return _object(response['data'])['revoked'] == true;
  }

  Future<bool> changePassword({
    required String current,
    required String next,
  }) async {
    final response = await _api.post('/api/v1/me/password/change',data: {
      'current_password': current,
      'password': next,
      'password_confirmation': next,
    });
    return _object(response['data'])['requires_login'] == true;
  }
}
