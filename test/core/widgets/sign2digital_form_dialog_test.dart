import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/core/theme/app_colors.dart';
import 'package:sign2digital/core/theme/app_theme.dart';
import 'package:sign2digital/core/widgets/sign2digital_form_dialog.dart';
import 'package:sign2digital/core/widgets/sign2digital_outlined_button.dart';
import 'package:sign2digital/core/widgets/sign2digital_primary_button.dart';

void main() {
  for (final theme in <ThemeData>[AppTheme.light, AppTheme.dark]) {
    testWidgets('approved form dialog preserves input and actions in '
        '${theme.brightness.name}', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      String? result;
      await tester.pumpWidget(MaterialApp(
        theme: theme,
        home: Scaffold(body: Builder(builder: (context) => TextButton(
          onPressed: () async {
            result = await showDialog<String>(
              context: context,
              builder: (dialogContext) => Sign2DigitalFormDialog(
                title: const Text('Edit Entry'),
                content: const TextField(
                  key: Key('approved-form-field'),
                  decoration: InputDecoration(labelText: 'Description'),
                ),
                actions: [
                  TextButton(
                    key: const Key('approved-cancel'),
                    onPressed: () => Navigator.pop(dialogContext, 'cancel'),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    key: const Key('approved-save'),
                    onPressed: () => Navigator.pop(dialogContext, 'save'),
                    child: const Text('Save'),
                  ),
                ],
              ),
            );
          },
          child: const Text('Open'),
        ))),
      ));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.byType(Sign2DigitalFormDialog), findsOneWidget);
      expect(find.byKey(const Key('approved-form-field')), findsOneWidget);
      expect(find.byType(Sign2DigitalPrimaryButton), findsOneWidget);
      expect(find.byType(Sign2DigitalOutlinedButton), findsOneWidget);
      final field = tester.widget<TextField>(
        find.byKey(const Key('approved-form-field')),
      );
      final decoration = Theme.of(tester.element(
        find.byKey(const Key('approved-form-field')),
      )).inputDecorationTheme;
      expect(field.decoration?.labelText, 'Description');
      expect(decoration.fillColor, AppColors.white);
      expect(decoration.focusedBorder?.borderSide.color, AppColors.primary);
      await tester.tap(find.byKey(const Key('approved-save')));
      await tester.pumpAndSettle();
      expect(result, 'save');
      expect(tester.takeException(), isNull);
    });
  }

  test('approved date and time pickers use brand surfaces', () {
    for (final theme in <ThemeData>[AppTheme.light, AppTheme.dark]) {
      expect(theme.datePickerTheme.backgroundColor, AppColors.white);
      expect(theme.datePickerTheme.headerBackgroundColor, AppColors.primary);
      expect(theme.timePickerTheme.backgroundColor, AppColors.white);
      expect(theme.timePickerTheme.dialHandColor, AppColors.primary);
    }
  });
}
