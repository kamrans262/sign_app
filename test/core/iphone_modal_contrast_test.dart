import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/core/theme/app_colors.dart';
import 'package:sign2digital/core/theme/app_theme.dart';
import 'package:sign2digital/core/widgets/sign2digital_modal_surface.dart';
import 'package:sign2digital/core/widgets/sign2digital_selection_sheet.dart';
import 'package:sign2digital/core/widgets/sign2digital_styled_bottom_sheet.dart';
import 'package:sign2digital/features/quotes/presentation/widgets/sign2digital_signature_consent.dart';

double _contrast(Color first, Color second) {
  final a = first.computeLuminance();
  final b = second.computeLuminance();
  return (a > b ? a + .05 : b + .05) /
      (a > b ? b + .05 : a + .05);
}

void _expectReadableWhiteSurface(BuildContext context) {
  final theme = Theme.of(context);
  expect(theme.brightness, Brightness.light);
  expect(_contrast(theme.colorScheme.onSurface, AppColors.white),
      greaterThanOrEqualTo(4.5));
  expect(_contrast(theme.colorScheme.primary, AppColors.white),
      greaterThanOrEqualTo(4.5));
}

void main() {
  for (final appTheme in <ThemeData>[AppTheme.light, AppTheme.dark]) {
    final mode = appTheme.brightness.name;

    testWidgets('iPhone agreement popup uses readable text, checkbox and actions in $mode',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      bool? result;
      await tester.pumpWidget(MaterialApp(
        theme: appTheme,
        home: Scaffold(body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showSign2DigitalSignatureConsent(
                context, 'Signed quote terms and conditions.',
              );
            },
            child: const Text('Sign quotation'),
          ),
        )),
      ));
      await tester.tap(find.text('Sign quotation'));
      await tester.pumpAndSettle();
      expect(find.text('Confirm agreement'), findsOneWidget);
      expect(find.text('Signed quote terms and conditions.'), findsOneWidget);
      final label = find.text('I have read and agree to these terms.');
      expect(label, findsOneWidget);
      _expectReadableWhiteSurface(tester.element(label));
      _expectReadableWhiteSurface(tester.element(find.text('Cancel')));
      expect(tester.widget<TextButton>(
        find.byKey(const Key('signature-consent-continue')),
      ).onPressed, isNull);
      await tester.tap(find.byKey(const Key('signature-consent-checkbox')));
      await tester.pumpAndSettle();
      expect(tester.widget<TextButton>(
        find.byKey(const Key('signature-consent-continue')),
      ).onPressed, isNotNull);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(result, true);
      expect(tester.takeException(), isNull);
    });

    testWidgets('existing selection sheet keeps readable checkbox and action in $mode',
        (tester) async {
      bool? result;
      await tester.pumpWidget(MaterialApp(
        theme: appTheme,
        home: Scaffold(body: Builder(builder: (context) => TextButton(
          onPressed: () async {
            result = await Sign2DigitalSelectionSheet.showCustom<bool>(
              context: context, title: 'Choose agreement',
              icon: Icons.check_circle_outline,
              builder: (sheet) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CheckboxListTile(
                    value: true,
                    onChanged: null,
                    title: Text('Keep this selection'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(sheet, true),
                    child: const Text('Done'),
                  ),
                ],
              ),
            );
          },
          child: const Text('Open options'),
        ))),
      ));
      await tester.tap(find.text('Open options'));
      await tester.pumpAndSettle();
      _expectReadableWhiteSurface(
        tester.element(find.text('Keep this selection')));
      _expectReadableWhiteSurface(tester.element(find.text('Done')));
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(result, true);
      expect(tester.takeException(), isNull);
    });

    testWidgets('legacy bottom sheet preserves callbacks and contrast in $mode',
        (tester) async {
      int? result;
      await tester.pumpWidget(MaterialApp(
        theme: appTheme,
        home: Scaffold(body: Builder(builder: (context) => TextButton(
          onPressed: () async {
            result = await showSign2DigitalBottomSheet<int>(
              context: context,
              builder: (sheet) => ListTile(
                title: const Text('Choose option'),
                onTap: () => Navigator.pop(sheet, 7),
              ),
            );
          },
          child: const Text('Open sheet'),
        ))),
      ));
      await tester.tap(find.text('Open sheet'));
      await tester.pumpAndSettle();
      _expectReadableWhiteSurface(tester.element(find.text('Choose option')));
      expect(tester.widget<BottomSheet>(find.byType(BottomSheet))
          .backgroundColor, AppColors.white);
      await tester.tap(find.text('Choose option'));
      await tester.pumpAndSettle();
      expect(result, 7);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shared popup surface remains accessible in $mode',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: appTheme,
        home: Scaffold(body: Builder(builder: (context) => TextButton(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (dialog) => Sign2DigitalModalSurface(
              child: TextButton(
                onPressed: () => Navigator.pop(dialog),
                child: const Text('Close popup'),
              ),
            ),
          ),
          child: const Text('Open popup'),
        ))),
      ));
      await tester.tap(find.text('Open popup'));
      await tester.pumpAndSettle();
      _expectReadableWhiteSurface(tester.element(find.text('Close popup')));
      await tester.tap(find.text('Close popup'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
