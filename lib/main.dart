import 'features/auth/presentation/screens/company_entry_gate.dart';

// Sign2Digital: single native mobile splash, existing Flutter desktop/web splash.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;

import 'core/theme/app_theme.dart';
import 'features/profile/data/app_settings_repository.dart';
import 'features/auth/data/mobile_auth_repository.dart';
import 'features/auth/presentation/screens/mobile_auth_gateway.dart';
import 'features/splash/presentation/splash_screen.dart';
import 'features/reminders/services/m20_push_coordinator.dart';
import 'features/subscription/services/m23_billing_deep_links.dart';
import 'features/reminders/presentation/screens/notification_inbox_screen.dart';
import 'features/quotes/presentation/screens/public_customer_signing_screen.dart';

// System notifications are displayed by the OS. The authenticated inbox is
// refreshed when the app resumes; background isolates must never access
// logged-in tokens, company records or the private API.
@pragma('vm:entry-point')
Future<void> m20BackgroundMessage(RemoteMessage message) async {}

Future<void> main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  // Android/iOS already show an OS launch splash. Keep that single splash
  // until authentication is restored; do not display a second Flutter page.
  final mobileNativeSplash = !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
       defaultTargetPlatform == TargetPlatform.iOS);
  if (mobileNativeSplash) {
    FlutterNativeSplash.preserve(widgetsBinding: binding);
  }
  // Catch Checkout links before splash/session restore, including cold starts.
  M23BillingDeepLinks.start();
  // Existing platforms with native Firebase configuration initialize here.
  // Missing configuration is nonfatal while M20 push delivery is disabled.
  if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS)) {
    try {
      if (Firebase.apps.isEmpty) await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(m20BackgroundMessage);
      M20PushCoordinator.shared.attach(openInbox: () {
        final navigator = M20PushCoordinator.navigatorKey.currentState;
        if (navigator == null) return;
        navigator.push(MaterialPageRoute<void>(
          builder: (_) => const NotificationInboxScreen(),
        ));
      });
    } catch (_) {
      // The existing auth and other modules must keep working during setup.
    }
  }
  try {
    await LocalAppSettingsRepository.shared.load();
  } catch (_) {
    // A damaged local settings file must never prevent app startup.
  }
  bool? initiallySignedIn;
  if (mobileNativeSplash) {
    try {
      initiallySignedIn =
          await MobileAuthRepository.shared.restoreRememberedSession();
    } catch (_) {
      // A failed restore never authenticates a user.
      initiallySignedIn = false;
    }
  }
  runApp(Sign2DigitalApp(initiallySignedIn: initiallySignedIn));
  if (mobileNativeSplash) {
    // Remove the native cover only after Flutter has rendered the destination.
    binding.addPostFrameCallback((_) => FlutterNativeSplash.remove());
  }
}

String? get _guestSigningToken {
  if (!kIsWeb) return null;
  final parts = Uri.base.pathSegments.where((part) => part.isNotEmpty).toList();
  if (parts.length != 2 || parts.first != 'sign' ||
      parts.last.isEmpty || parts.last.length > 4096) {
    return null;
  }
  return parts.last;
}

class Sign2DigitalApp extends StatelessWidget {
  const Sign2DigitalApp({super.key, this.initiallySignedIn,
      this.restoreSession});

  /// A non-null value indicates native mobile startup already completed
  /// the guarded session restore while the OS splash was still visible.
  /// Desktop/web keep their existing standalone Flutter splash.
  final bool? initiallySignedIn;
  /// Overrides desktop/web session restoration in tests; mobile uses main().
  final Future<bool> Function()? restoreSession;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppSettings>(
      valueListenable: AppSettingsSession.current,
      builder: (context, settings, child) => MaterialApp(
        navigatorKey: M20PushCoordinator.navigatorKey,
      title: 'Sign2Digital',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      // Only the approved Sign2Digital light UI is offered in Settings.
      themeMode: ThemeMode.light,
      // Sign2Digital keyboard dismissal for all routes.
      builder: (context, child) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: child ?? const SizedBox.shrink(),
      ),
      // Customers can use a hosted /sign/<opaqueToken> link without an account.
      // This never bypasses server token, signer and document authorization.
      home: _guestSigningToken != null
          ? PublicCustomerSigningScreen(token: _guestSigningToken!)
          : initiallySignedIn == null
              ? _AppEntry(restoreSession: restoreSession)
              : initiallySignedIn!
                  ? const CompanyEntryGate()
                  : const MobileAuthGateway(),
    ));
  }
}

class _AppEntry extends StatefulWidget {
  const _AppEntry({this.restoreSession});

  final Future<bool> Function()? restoreSession;

  @override
  State<_AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<_AppEntry> {
  Timer? _navigationTimer;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    // Own the startup transition at the app-entry level. This works even if
    // the splash widget is used elsewhere purely for presentation.
    _navigationTimer = Timer(const Duration(seconds: 2), _showLogin);
  }

  void _showLogin() {
    _openAuthenticatedEntry();
  }

  Future<void> _openAuthenticatedEntry() async {
    if (!mounted || _navigated) return;
    var signedIn = false;
    try {
      signedIn = await (widget.restoreSession?.call() ??
          MobileAuthRepository.shared.restoreRememberedSession());
    } catch (_) {
      // Network or secure-storage errors must not bypass authentication.
      signedIn = false;
    }
    if (!mounted || _navigated) return;
    _navigated = true;
    Navigator.of(context).pushReplacement<void, void>(
      MaterialPageRoute<void>(
        builder: (_) => signedIn
            ? const CompanyEntryGate()
            : const MobileAuthGateway(),
      ),
    );
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SplashScreen();
}
