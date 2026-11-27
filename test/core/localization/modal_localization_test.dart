import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/core/localization/app_language_controller.dart';
import 'package:sign2digital/core/localization/app_strings.dart';
import 'package:sign2digital/core/widgets/sign2digital_approved_confirmation.dart';
import 'package:sign2digital/core/widgets/sign2digital_form_dialog.dart';
import 'package:sign2digital/core/widgets/sign2digital_selection_sheet.dart';

void main() {
  for (final code in ['fr', 'de', 'it']) {
    testWidgets('approved confirmation translates fixed labels in $code '
        'without changing action values', (tester) async {
      bool? result;
      await tester.pumpWidget(MaterialApp(
        locale: Locale(code),
        supportedLocales: AppLanguages.supportedLocales,
        localizationsDelegates: const [
          AppStrings.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        home: Scaffold(body: Builder(builder: (context) =>
          TextButton(onPressed: () async {
            result = await showDialog<bool>(context: context,
              builder: (dialog) => Sign2DigitalApprovedConfirmation(
                title: const Text('Delete document?'),
                content: const Column(mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('This action cannot be undone.'),
                    Text('Q-001'),
                  ]),
                actions: [
                  TextButton(key: const Key('modal-no'),
                    onPressed: () => Navigator.pop(dialog, false),
                    child: const Text('Cancel')),
                  TextButton(key: const Key('modal-yes'),
                    onPressed: () => Navigator.pop(dialog, true),
                    child: const Text('Confirm Deletion')),
                ],
              ));
          }, child: const Text('Open')))),
      ));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final strings = AppStrings(Locale(code));
      expect(find.text(strings.tr('Delete document?')), findsOneWidget);
      expect(find.text(strings.tr('This action cannot be undone.')), findsOneWidget);
      expect(find.text(strings.tr('Confirm Deletion')), findsOneWidget);
      expect(find.text('Q-001'), findsOneWidget);
      expect(find.byKey(const Key('modal-no')), findsOneWidget);
      await tester.tap(find.byKey(const Key('modal-yes')));
      await tester.pumpAndSettle();
      expect(result, true);
      expect(tester.takeException(), isNull);
    });

    testWidgets('form dialog translates plain Text without changing layout '
        'or input handling in $code', (tester) async {
      String? result;
      await tester.pumpWidget(MaterialApp(
        locale: Locale(code),
        supportedLocales: AppLanguages.supportedLocales,
        localizationsDelegates: const [
          AppStrings.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        home: Scaffold(body: Builder(builder: (context) =>
          TextButton(onPressed: () async {
            result = await showDialog<String>(context: context,
              builder: (dialog) => Sign2DigitalFormDialog(
                title: const Text('Edit Role'),
                content: const Text('This action cannot be undone.'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(dialog, 'cancel'),
                    child: const Text('Cancel')),
                  TextButton(onPressed: () => Navigator.pop(dialog, 'save'),
                    child: const Text('Save')),
                ]));
          }, child: const Text('Open')))),
      ));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final strings = AppStrings(Locale(code));
      expect(find.text(strings.tr('Edit Role')), findsOneWidget);
      expect(find.text(strings.tr('This action cannot be undone.')), findsOneWidget);
      await tester.tap(find.text(strings.tr('Save')));
      await tester.pumpAndSettle();
      expect(result, 'save');
      expect(tester.takeException(), isNull);
    });

    testWidgets('picker translates labels but returns canonical option in $code',
        (tester) async {
      String? chosen;
      await tester.pumpWidget(MaterialApp(
        locale: Locale(code),
        supportedLocales: AppLanguages.supportedLocales,
        localizationsDelegates: const [
          AppStrings.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        home: Scaffold(body: Builder(builder: (context) =>
          TextButton(onPressed: () async {
            chosen = await Sign2DigitalSelectionSheet.show(context,
              title: 'Select Country',
              icon: Icons.language,
              options: const ['Manual Labour Entry', 'Live Time Tracking'],
              selected: 'Manual Labour Entry');
          }, child: const Text('Open')))),
      ));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final strings = AppStrings(Locale(code));
      expect(find.text(strings.tr('Select Country')), findsOneWidget);
      expect(find.text(strings.tr('Manual Labour Entry')), findsOneWidget);
      await tester.tap(find.text(strings.tr('Live Time Tracking')));
      await tester.pumpAndSettle();
      expect(chosen, 'Live Time Tracking');
      expect(tester.takeException(), isNull);
    });
  }

  test('known popup labels translate while business data stays unchanged', () {
    for (final code in ['fr', 'de', 'it']) {
      final tr = AppStrings(Locale(code)).tr;
      for (final label in [
        'Create New Quote', 'Mark as Paid', 'Select Country',
        'Search country or calling code', 'Cancel', 'Save',
      ]) {
        expect(tr(label), isNot(label), reason: '$code / $label');
      }
      expect(tr('Q-001'), 'Q-001');
      expect(tr('client@example.com'), 'client@example.com');
      expect(tr('CHF 5,000'), 'CHF 5,000');
    }
  });
}
