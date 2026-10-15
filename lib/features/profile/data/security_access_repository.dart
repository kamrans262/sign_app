/// Authentication-owned security state. No password, token or secret is stored
/// in this model. A missing status is unknown, NOT disabled or verified.
class SecurityDeviceSession {
  const SecurityDeviceSession({
    required this.id,
    required this.deviceName,
    required this.location,
    required this.agentAndLastSeen,
    required this.isCurrent,
    this.isMobile = false,
  });

  final String id;
  final String deviceName;
  final String location;
  final String agentAndLastSeen;
  final bool isCurrent;
  final bool isMobile;
}

class SecurityOverview {
  const SecurityOverview({
    this.twoFactorEnabled,
    this.sessions,
    this.demoOnly = false,
  });

  final bool? twoFactorEnabled;
  final List<SecurityDeviceSession>? sessions;
  final bool demoOnly;
}

/// A production adapter must verify password and complete the actual 2FA
/// enrollment/disable workflow before returning true. No optimistic UI.
abstract class SecurityAccessRepository {
  Future<SecurityOverview> load();

  Future<bool> changeTwoFactor({
    required bool enable,
    required String confirmationPassword,
  });

  /// True only after the backend actually revoked the intended sessions.
  Future<bool> revokeOtherSessions({required String confirmationPassword});

  Future<bool> revokeSession({
    required String sessionId,
    required String confirmationPassword,
  });
}

/// Figma-only preview. Never claims OS 2FA, authenticated sessions, or logout.
/// Its two-factor and session values are visibly marked as sample data.
class PreviewSecurityAccessRepository implements SecurityAccessRepository {
  const PreviewSecurityAccessRepository();
  @override
  Future<SecurityOverview> load() async => const SecurityOverview(
    twoFactorEnabled: true,
    demoOnly: true,
    sessions: [
      SecurityDeviceSession(
        id: 'preview-current',
        deviceName: 'MacBook Pro',
        location: 'Zurich, Switzerland',
        agentAndLastSeen: 'Chrome · 14 August 2026, 10:00 PM',
        isCurrent: true,
      ),
      SecurityDeviceSession(
        id: 'preview-iphone',
        deviceName: 'iPhone 15',
        location: 'Zurich, Switzerland',
        agentAndLastSeen: 'Chrome · 14 August 2026, 10:00 PM',
        isCurrent: false,
        isMobile: true,
      ),
    ],
  );

  @override
  Future<bool> changeTwoFactor({
    required bool enable,
    required String confirmationPassword,
  }) async => false;

  @override
  Future<bool> revokeOtherSessions({
    required String confirmationPassword,
  }) async => false;

  @override
  Future<bool> revokeSession({
    required String sessionId,
    required String confirmationPassword,
  }) async => false;
}
