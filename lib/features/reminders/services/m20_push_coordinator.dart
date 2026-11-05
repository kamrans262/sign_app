import 'dart:async';
import 'dart:math';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/services/active_company_session.dart';
import '../../auth/data/mobile_auth_repository.dart';
import '../data/m20_push_api.dart';

/// M20 Stage 2: one background-safe device registration coordinator. Never
/// stores the registration token in preferences or logs, and never requests
/// OS permission before the signed-in user explicitly enables push.
class M20PushCoordinator with WidgetsBindingObserver {
  M20PushCoordinator({M20PushApi? api}) : _api = api ?? M20PushApi.shared;

  static final shared = M20PushCoordinator();
  static final navigatorKey = GlobalKey<NavigatorState>();
  static const _storage = FlutterSecureStorage();
  static const _installationKey = 's2d.m20.push.installation.id';
  final M20PushApi _api;
  final ValueNotifier<int> inboxChanges = ValueNotifier<int>(0);

  StreamSubscription<String>? _refreshSubscription;
  StreamSubscription<RemoteMessage>? _messageSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  VoidCallback? _openInbox;
  bool _started = false;
  bool _registering = false;
  int? _pendingOpenCompany;

  static bool get _supported => !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
       defaultTargetPlatform == TargetPlatform.iOS);

  static bool get _initialized => _supported && Firebase.apps.isNotEmpty;

  static String get _platform =>
      defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';

  void attach({VoidCallback? openInbox}) {
    if (openInbox != null) _openInbox = openInbox;
    if (!_initialized || _started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    ActiveCompanySession.selected.addListener(_companyChanged);
    _refreshSubscription = FirebaseMessaging.instance.onTokenRefresh.listen(
      (token) { unawaited(_registerIfEnabled(token)); },
      onError: (Object _) {},
    );
    _messageSubscription = FirebaseMessaging.onMessage.listen((_) {
      inboxChanges.value++;
    });
    _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _onOpened(message);
    });
    unawaited(FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) _onOpened(message);
    }).catchError((Object _) {}));
    _companyChanged();
  }

  void _onOpened(RemoteMessage message) {
    final company = int.tryParse(message.data['company_id'] ?? '');
    if (company == null || company < 1) return;
    _pendingOpenCompany = company;
    _tryOpen();
  }

  void _tryOpen() {
    if (_pendingOpenCompany != ActiveCompanySession.companyId ||
        !MobileAuthRepository.shared.isSignedIn || _openInbox == null) return;
    _pendingOpenCompany = null;
    // Navigate only to our authenticated inbox, never directly to an
    // unvalidated record from a push data payload.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (navigatorKey.currentState != null) _openInbox?.call();
    });
  }

  void _companyChanged() {
    if (!MobileAuthRepository.shared.isSignedIn) return;
    _tryOpen();
    unawaited(syncRegistration());
  }

  /// Resume/reselect can restore an expired Firebase token or APNs mapping.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(syncRegistration());
    }
  }

  static String _uuid() {
    final bytes = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  Future<String> _installationId() async {
    final existing = await _storage.read(key: _installationKey);
    if (existing != null && existing.length == 36) return existing;
    final id = _uuid();
    await _storage.write(key: _installationKey, value: id);
    return id;
  }

  Future<String?> _fcmToken() async {
    if (!_initialized) return null;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      // iOS requires APNs to finish registration before getToken().
      final apns = await FirebaseMessaging.instance.getAPNSToken();
      if (apns == null || apns.isEmpty) return null;
    }
    return FirebaseMessaging.instance.getToken();
  }

  Future<void> _registerIfEnabled(String token) async {
    if (_registering || !MobileAuthRepository.shared.isSignedIn ||
        ActiveCompanySession.companyId == null || !_initialized) return;
    _registering = true;
    try {
      final company = ActiveCompanySession.companyId;
      final preferences = await _api.preferences();
      if (!preferences.pushEnabled || !preferences.pushAvailable ||
          company != ActiveCompanySession.companyId) return;
      final settings = await FirebaseMessaging.instance.getNotificationSettings();
      if (settings.authorizationStatus != AuthorizationStatus.authorized &&
          settings.authorizationStatus != AuthorizationStatus.provisional) return;
      if (token.isNotEmpty) {
        await _api.register(installationId: await _installationId(),
            platform: _platform, token: token);
      }
    } catch (_) {
      // Push setup must never interrupt existing authenticated workflows.
    } finally {
      _registering = false;
    }
  }

  Future<void> syncRegistration() async {
    if (!_initialized || !MobileAuthRepository.shared.isSignedIn ||
        ActiveCompanySession.companyId == null) return;
    try {
      final preferences = await _api.preferences();
      if (!preferences.pushEnabled || !preferences.pushAvailable) return;
      final settings = await FirebaseMessaging.instance.getNotificationSettings();
      if (settings.authorizationStatus != AuthorizationStatus.authorized &&
          settings.authorizationStatus != AuthorizationStatus.provisional) return;
      final token = await _fcmToken();
      if (token != null) await _registerIfEnabled(token);
    } catch (_) {}
  }

  Future<M20NotificationPreferences> enable(M20NotificationPreferences preferences) async {
    if (!preferences.pushAvailable) {
      throw StateError('Push notifications are not enabled on the server.');
    }
    if (!_initialized) {
      throw StateError('Firebase configuration is unavailable.');
    }
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true, badge: true, sound: true, provisional: false,
    );
    if (settings.authorizationStatus != AuthorizationStatus.authorized &&
        settings.authorizationStatus != AuthorizationStatus.provisional) {
      throw StateError('Notification permission was not granted.');
    }
    final company = ActiveCompanySession.companyId;
    final token = await _fcmToken();
    if (token == null || token.isEmpty || company == null) {
      throw StateError('Push device registration is not ready.');
    }
    await _api.register(installationId: await _installationId(),
        platform: _platform, token: token);
    if (company != ActiveCompanySession.companyId) {
      throw StateError('Company changed while enabling notifications.');
    }
    return _api.update(preferences, pushEnabled: true);
  }

  Future<M20NotificationPreferences> disable(M20NotificationPreferences preferences) =>
      _api.update(preferences, pushEnabled: false);

  Future<void> revokeBeforeLogout() async {
    if (!_initialized || !MobileAuthRepository.shared.isSignedIn) return;
    try {
      final id = await _storage.read(key: _installationKey);
      if (id != null) await _api.revoke(installationId: id);
    } catch (_) {
      // Logout must remain available offline; this device's next login will
      // revoke registrations for previous users with the same installation.
    }
  }

  void dispose() {
    ActiveCompanySession.selected.removeListener(_companyChanged);
    WidgetsBinding.instance.removeObserver(this);
    _refreshSubscription?.cancel();
    _messageSubscription?.cancel();
    _openedSubscription?.cancel();
    _started = false;
  }
}
