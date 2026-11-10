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
/// stores a Firebase Installation ID (FID) in preferences or logs. The OS permission
/// is requested once on the first authenticated launch after company selection.
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
  bool _syncing = false;
  bool _syncAgain = false;
  int? _pendingOpenCompany;

  static bool get _supported => !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
       defaultTargetPlatform == TargetPlatform.iOS);

  static bool get _initialized => _supported && Firebase.apps.isNotEmpty;

  static String get _platform =>
      defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';

  void attach({VoidCallback? openInbox}) {
    if (openInbox != null) { _openInbox = openInbox; }
    if (!_initialized || _started) { return; }
    _started = true;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      unawaited(FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
            alert: true, badge: true, sound: true,
          ).catchError((Object _) {}));
    }
    WidgetsBinding.instance.addObserver(this);
    ActiveCompanySession.selected.addListener(_companyChanged);
    _refreshSubscription = FirebaseMessaging.instance.onRegistered.listen(
      (fid) { unawaited(_registerIfEnabled(fid)); },
      onError: (Object _) {},
    );
    _messageSubscription = FirebaseMessaging.onMessage.listen((_) {
      inboxChanges.value++;
    });
    _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _onOpened(message);
    });
    unawaited(FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) { _onOpened(message); }
    }).catchError((Object _) {}));
    _companyChanged();
  }

  void _onOpened(RemoteMessage message) {
    final company = int.tryParse(message.data['company_id'] ?? '');
    if (company == null || company < 1) { return; }
    _pendingOpenCompany = company;
    _tryOpen();
  }

  void _tryOpen() {
    if (_pendingOpenCompany != ActiveCompanySession.companyId ||
        !MobileAuthRepository.shared.isSignedIn || _openInbox == null) { return; }
    _pendingOpenCompany = null;
    // Navigate only to our authenticated inbox, never directly to an
    // unvalidated record from a push data payload.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (navigatorKey.currentState != null) { _openInbox?.call(); }
    });
  }

  void _companyChanged() {
    if (!MobileAuthRepository.shared.isSignedIn ||
        ActiveCompanySession.companyId == null) { return; }
    _tryOpen();
    // Wait for the authenticated company screen to appear before the OS dialog.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_started && MobileAuthRepository.shared.isSignedIn &&
          ActiveCompanySession.companyId != null) {
        unawaited(syncRegistration());
      }
    });
  }

  /// Resume/reselect can restore a rotated Firebase installation or APNs mapping.
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
    if (existing != null && existing.length == 36) { return existing; }
    final id = _uuid();
    await _storage.write(key: _installationKey, value: id);
    return id;
  }

  Future<String?> _currentFid() async {
    if (!_initialized) { return null; }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      // iOS requires APNs to be ready before Firebase Messaging registration.
      final apns = await FirebaseMessaging.instance.getAPNSToken();
      if (apns == null || apns.isEmpty) { return null; }
    }
    // 17.x emits the FID asynchronously through onRegistered.
    final received = Completer<String?>();
    final subscription = FirebaseMessaging.instance.onRegistered.listen((fid) {
      if (!received.isCompleted) { received.complete(fid); }
    });
    try {
      await FirebaseMessaging.instance.register();
      return await received.future.timeout(
        const Duration(seconds: 15), onTimeout: () => null,
      );
    } finally {
      await subscription.cancel();
    }
  }

  Future<void> _registerIfEnabled(String fid) async {
    if (_syncing || _registering || !MobileAuthRepository.shared.isSignedIn ||
        ActiveCompanySession.companyId == null || !_initialized) { return; }
    _registering = true;
    try {
      final company = ActiveCompanySession.companyId;
      final preferences = await _api.preferences();
      if (!preferences.pushEnabled || !preferences.pushAvailable ||
          company != ActiveCompanySession.companyId) { return; }
      final settings = await FirebaseMessaging.instance.getNotificationSettings();
      if (settings.authorizationStatus != AuthorizationStatus.authorized &&
          settings.authorizationStatus != AuthorizationStatus.provisional) { return; }
      if (fid.isNotEmpty) {
        await _api.register(installationId: await _installationId(),
            platform: _platform, fid: fid);
      }
    } catch (_) {
      // Push setup must never interrupt existing authenticated workflows.
    } finally {
      _registering = false;
    }
  }

  @visibleForTesting
  static bool shouldRequestPermission(AuthorizationStatus status) =>
      status == AuthorizationStatus.notDetermined;

  @visibleForTesting
  static bool hasPushPermission(AuthorizationStatus status) =>
      status == AuthorizationStatus.authorized ||
      status == AuthorizationStatus.provisional;

  /// Automatically requests OS permission only once, after an authenticated
  /// company is selected, then registers this installation with Laravel.
  /// Subsequent launches refresh registration without asking again. A denial
  /// is respected, and an unavailable server never triggers an OS prompt.
  Future<void> syncRegistration() async {
    if (!_initialized || !_started || !MobileAuthRepository.shared.isSignedIn ||
        ActiveCompanySession.companyId == null) { return; }
    if (_syncing) {
      _syncAgain = true;
      return;
    }
    _syncing = true;
    try {
      final company = ActiveCompanySession.companyId;
      final preferences = await _api.preferences();
      if (!preferences.pushAvailable ||
          company != ActiveCompanySession.companyId) { return; }

      var settings = await FirebaseMessaging.instance.getNotificationSettings();
      if (shouldRequestPermission(settings.authorizationStatus)) {
        settings = await FirebaseMessaging.instance.requestPermission(
          alert: true, badge: true, sound: true, provisional: false,
        );
      }
      // Do not repeat denied prompts or register without device consent.
      if (!hasPushPermission(settings.authorizationStatus) ||
          !MobileAuthRepository.shared.isSignedIn ||
          company != ActiveCompanySession.companyId) { return; }

      // Firebase emits the private installation ID through onRegistered.
      // On Apple platforms registration waits until APNs has issued a token.
      final fid = await _currentFid();
      if (fid == null || fid.isEmpty ||
          !MobileAuthRepository.shared.isSignedIn ||
          company != ActiveCompanySession.companyId) { return; }

      await _api.register(installationId: await _installationId(),
          platform: _platform, fid: fid);
      if (!preferences.pushEnabled &&
          MobileAuthRepository.shared.isSignedIn &&
          company == ActiveCompanySession.companyId) {
        await _api.update(preferences, pushEnabled: true);
      }
    } catch (_) {
      // A temporary Firebase/API failure must not interrupt other modules.
      // Registration is retried when the app resumes or company changes.
    } finally {
      _syncing = false;
      if (_syncAgain) {
        _syncAgain = false;
        unawaited(syncRegistration());
      }
    }
  }

  Future<void> revokeBeforeLogout() async {
    if (!_initialized || !MobileAuthRepository.shared.isSignedIn) { return; }
    try {
      final id = await _storage.read(key: _installationKey);
      if (id != null) { await _api.revoke(installationId: id); }
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
