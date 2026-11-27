import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/core/localization/app_language_controller.dart';
import 'package:sign2digital/core/localization/app_strings.dart';
import 'package:sign2digital/core/localization/localized_ui_text.dart';
import 'package:sign2digital/core/widgets/sign2digital_header.dart';
import 'package:sign2digital/core/widgets/sign2digital_primary_button.dart';
import 'package:sign2digital/features/clients/presentation/widgets/sign2digital_status_badge.dart';

void main() {
  testWidgets('Stage 2 labels translate without changing styles or raw data',
      (tester) async {
    const style = TextStyle(fontFamily: 'Inter', fontSize: 16,
      fontWeight: FontWeight.w600);
    for (final values in [
      ('en', 'Save', 'Draft', 'Clients'),
      ('fr', 'Enregistrer', 'Brouillon', 'Clients'),
      ('de', 'Speichern', 'Entwurf', 'Kunden'),
      ('it', 'Salva', 'Bozza', 'Clienti'),
    ]) {
      await tester.pumpWidget(MaterialApp(
        locale: Locale(values.$1),
        supportedLocales: AppLanguages.supportedLocales,
        localizationsDelegates: const [
          AppStrings.delegate, ...GlobalMaterialLocalizations.delegates,
        ],
        home: Scaffold(body: Column(children: [
          const Sign2DigitalHeader(title: 'Clients', translateTitle: true,
            showBackButton: false),
          const LocalizedUiText('Save', key: Key('localized-ui'), style: style),
          const Text('Save', key: Key('user-data'), style: style),
          const Sign2DigitalStatusBadge(status: 'draft'),
          Sign2DigitalPrimaryButton(label: 'Save', onPressed: () {}),
        ])),
      ));
      await tester.pumpAndSettle();
      final raw = tester.widget<Text>(find.byKey(const Key('user-data')));
      expect(raw.data, 'Save');
      expect(raw.style, style);
      expect(find.text(values.$2), findsWidgets);
      expect(find.text(values.$3), findsOneWidget);
      expect(find.text(values.$4), findsOneWidget);
      expect(tester.widget<LocalizedUiText>(
        find.byKey(const Key('localized-ui'))).style, style);
      expect(tester.takeException(), isNull);
    }
  });
}
