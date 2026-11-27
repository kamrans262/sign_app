import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/core/localization/app_display_formats.dart';
import 'package:sign2digital/core/localization/app_language_controller.dart';
import 'package:sign2digital/core/localization/app_strings.dart';
import 'package:sign2digital/core/widgets/sign2digital_selection_field.dart';
import 'package:sign2digital/core/widgets/sign2digital_selection_sheet.dart';

void main() {
  test('Translated templates preserve literal identifiers and user text', () {
    final strings = AppStrings(const Locale('fr'));
    expect(strings.format('Client: {name}', {'name': 'ACME {name}'}),
      'Client : ACME {name}');
    expect(strings.format('Photo {current} of {total}',
      {'current': 2, 'total': 5}), 'Photo 2 sur 5');
  });

  testWidgets('Localized date, currency and selection labels retain raw values',
      (tester) async {
    String? chosen;
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('fr'),
      supportedLocales: AppLanguages.supportedLocales,
      localizationsDelegates: const [
        AppStrings.delegate, ...GlobalMaterialLocalizations.delegates,
      ],
      home: Scaffold(body: Builder(builder: (context) => Column(children: [
        Text(AppDisplayFormats.longDate(context, DateTime(2026, 8, 25))),
        Text(AppDisplayFormats.money(context, 123456, 'CHF',
          english: 'CHF 1,234.56')),
        Sign2DigitalSelectionField(
          key: const Key('raw-status'),
          label: 'Status', value: 'Draft', translateValue: true,
          hintText: 'Select', iconAsset: '', leadingIcon: Icons.edit,
          onTap: () async {
            chosen = await Sign2DigitalSelectionSheet.show(context,
              title: 'Status', options: const ['Draft', 'Approved'],
              selected: 'Draft', translateOptions: true);
          },
        ),
        Sign2DigitalSelectionField(
          label: 'Client', value: 'Draft', hintText: 'Select client',
          iconAsset: '', leadingIcon: Icons.person, onTap: () {},
        ),
      ]))),
    ));
    await tester.pumpAndSettle();
    expect(find.text('25 août 2026'), findsOneWidget);
    expect(find.textContaining('234,56'), findsOneWidget);
    expect(find.text('Brouillon'), findsOneWidget);
    expect(find.text('Draft'), findsOneWidget);
    await tester.tap(find.byKey(const Key('raw-status')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Validé'));
    await tester.pumpAndSettle();
    expect(chosen, 'Approved');
    expect(tester.takeException(), isNull);
  });
}
