import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/core/localization/app_language_controller.dart';
import 'package:sign2digital/core/localization/app_strings.dart';
import 'package:sign2digital/core/localization/localized_ui_text.dart';

void main() {
  test('critical consent and data-deletion copy has four-language coverage', () {
    const keys = [
      'Deactivation disables sign-in and revokes active sessions. It does not delete company records or signed documents. Active company owners must transfer or close ownership first.',
      'Your personal profile and private support data will be erased and every session revoked. Issued company records and signed documents are retained for legal integrity. Transfer company ownership and administrator access first.',
      'A signed document for this job is required before creating an addendum.',
      'Enter a temporary OpenAI API key to process your recording. Audio is transmitted to OpenAI; API charges may apply.',
      'Overdue Reminders: On ({days} days)',
    ];
    for (final code in ['fr','de','it']) {
      final catalog=AppStrings(Locale(code));
      for (final key in keys) {
        expect(catalog.tr(key),isNot(key),reason:'Missing $code: $key');
      }
      expect(catalog.format('Overdue Reminders: On ({days} days)',
        {'days':7}),contains('7'));
      expect(catalog.tr('Q-003'),'Q-003');
    }
  });

  testWidgets('localized copy retains existing text configuration',
      (tester) async {
    final language=AppLanguageController(
      readCode: () async => 'fr',
      writeCode: (_) async {},
    );
    await language.restore();
    await tester.pumpWidget(ValueListenableBuilder<Locale?>(
      valueListenable: language,
      builder: (_,locale,__) => MaterialApp(
        locale: locale,
        supportedLocales: AppLanguages.supportedLocales,
        localizationsDelegates: const [
          AppStrings.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        home: const Scaffold(
          body: LocalizedUiText('Choose from gallery',
            style: TextStyle(fontFamily:'Inter',fontSize:14),
            maxLines:2,overflow:TextOverflow.ellipsis),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    final french=find.text(AppStrings(const Locale('fr')).tr('Choose from gallery'));
    expect(french,findsOneWidget);
    expect(tester.widget<Text>(french).maxLines,2);
    expect(tester.widget<Text>(french).style!.fontFamily,'Inter');
    await tester.pumpWidget(const SizedBox());
    language.dispose();
  });

  test('no double-prefixed localization widget in site report', () {
    final source=File('lib/features/documents/presentation/screens/site_report_wizard_screen.dart')
        .readAsStringSync();
    expect(source, isNot(contains('LocalizedUiLocalizedUiText')));
  });
}
