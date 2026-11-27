import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:sign2digital/core/localization/app_display_formats.dart';
import 'package:sign2digital/core/localization/app_language_controller.dart';
import 'package:sign2digital/core/localization/app_strings.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting();
  });

  for (final locale in AppLanguages.supportedLocales) {
    testWidgets('Offline date and money format renders in ${locale.languageCode}',
        (tester) async {
      late String date, amount, currency;
      await tester.pumpWidget(MaterialApp(
        locale: locale,
        supportedLocales: AppLanguages.supportedLocales,
        localizationsDelegates: const [
          AppStrings.delegate, ...GlobalMaterialLocalizations.delegates,
        ],
        home: Builder(builder: (context) {
          date = AppDisplayFormats.longDate(context, DateTime(2026,11,28));
          amount = AppDisplayFormats.decimal(context, 1234.5);
          currency = AppDisplayFormats.money(
            context, 123450, 'CHF', english: 'CHF 1,234.50');
          return Scaffold(body: Text(date));
        }),
      ));
      await tester.pumpAndSettle();
      expect(date, isNotEmpty);
      expect(amount, isNotEmpty);
      expect(currency, contains('CHF'));
      expect(find.text(date), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
