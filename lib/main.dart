import 'features/clients/presentation/screens/clients_screen.dart';

// Sign2Digital Navigation Fix — permanent splash -> login startup.
import 'dart:async';

import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/profile/data/app_settings_repository.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/splash/presentation/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await LocalAppSettingsRepository.shared.load();
  } catch (_) {
    // A damaged local settings file must never prevent app startup.
  }
  runApp(const Sign2DigitalApp());
}

class Sign2DigitalApp extends StatelessWidget {
  const Sign2DigitalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppSettings>(
      valueListenable: AppSettingsSession.current,
      builder: (context, settings, child) => MaterialApp(
      title: 'Sign2Digital',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: settings.themeMode,
      // Sign2Digital keyboard dismissal for all routes.
      builder: (context, child) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: child ?? const SizedBox.shrink(),
      ),
      home: const _AppEntry(),
    ));
  }
}

class _AppEntry extends StatefulWidget {
  const _AppEntry();

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
    if (!mounted || _navigated) return;
    _navigated = true;
    Navigator.of(context).pushReplacement<void, void>(
      MaterialPageRoute<void>(
        builder: (loginContext) => LoginScreen(
          onSubmit: (email, password, rememberMe) {
            // UI-only demo route; real authentication will be added with the API.
            Navigator.of(loginContext).pushReplacement<void, void>(
              MaterialPageRoute<void>(builder: (_) => const ClientsScreen()),
            );
          },
        ),
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
