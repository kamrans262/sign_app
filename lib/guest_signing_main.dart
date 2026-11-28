import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/localization/app_language_controller.dart';
import 'core/localization/app_strings.dart';
import 'core/localization/localized_ui_text.dart';
import 'core/theme/app_theme.dart';
import 'features/quotes/presentation/screens/public_customer_signing_screen.dart';

/// Dedicated web entry point for account-free customers. Deploy a separate
/// HTTPS guest build rather than importing the business login/dashboard shell.
///
/// flutter build web -t lib/guest_signing_main.dart
///   --dart-define=SIGN2DIGITAL_SIGNING_API_BASE_URL=https://api.example.com
///
/// Configure the host to rewrite /sign/<opaqueToken> to index.html.
/// The API still authorizes every token and signature server-side.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppLanguageController.shared.restore();
  final active = AppLanguageController.shared.effectiveLocale(
    WidgetsBinding.instance.platformDispatcher.locales,
  );
  final parts = Uri.base.pathSegments
      .where((segment) => segment.isNotEmpty)
      .toList();
  final token = parts.length == 2 && parts.first == 'sign'
      ? parts.last
      : '';
  runApp(MaterialApp(
    locale: active,
    supportedLocales: AppLanguages.supportedLocales,
    localizationsDelegates: const [
      AppStrings.delegate,
      ...GlobalMaterialLocalizations.delegates,
    ],
    title: 'Sign2Digital Customer Signing',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    home: token.isEmpty
        ? const Scaffold(
            body: Center(child: LocalizedUiText('This signing link is unavailable.')),
          )
        : PublicCustomerSigningScreen(token: token),
  ));
}
