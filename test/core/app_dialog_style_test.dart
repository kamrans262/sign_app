import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/core/theme/app_colors.dart';
import 'package:sign2digital/core/theme/app_theme.dart';

void main() {
  for (final mode in <String, ThemeData>{
    'light': AppTheme.light,
    'dark': AppTheme.dark,
  }.entries) {
    testWidgets('all AlertDialogs use approved style in ${mode.key}',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      bool? accepted;
      await tester.pumpWidget(MaterialApp(
        theme: mode.value,
        home: Scaffold(body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              accepted = await showDialog<bool>(
                context: context,
                builder: (dialog) => AlertDialog(
                  title: const Text('Review Document Suggestion'),
                  content: const SizedBox(
                    height: 240,
                    child: SingleChildScrollView(
                      child: Text('Generated document text for review.'),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialog, false),
                      child: const Text('Keep Editing'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(dialog, true),
                      child: const Text('Save Draft'),
                    ),
                  ],
                ),
              );
            },
            child: const Text('Generate document'),
          ),
        )),
      ));
      await tester.tap(find.text('Generate document'));
      await tester.pumpAndSettle();
      expect(find.text('Review Document Suggestion'), findsOneWidget);
      final alert = tester.widget<AlertDialog>(find.byType(AlertDialog));
      final dialog = tester.widget<Dialog>(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(Dialog),
        ),
      );
      expect(dialog.backgroundColor, AppColors.white);
      expect(dialog.surfaceTintColor, Colors.transparent);
      expect(dialog.elevation, 0);
      expect(
        dialog.shape,
        const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
      );
      expect(tester.getSize(find.byType(Dialog)).width, lessThanOrEqualTo(350));
      expect(mode.value.alertDialogTheme.titleTextStyle?.fontFamily, 'Inter');
      expect(mode.value.alertDialogTheme.titleTextStyle?.fontSize, 18);
      expect(mode.value.alertDialogTheme.contentTextStyle?.fontSize, 14);
      expect(mode.value.dialogTheme.barrierColor, const Color(0x80000000));
      expect(alert.actions?.length, 2);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Save Draft'));
      await tester.pumpAndSettle();
      expect(accepted, isTrue);
      expect(find.byType(AlertDialog), findsNothing);
    });
  }

  testWidgets('approved dialog remains usable on compact phones',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: Builder(
        builder: (context) => TextButton(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (dialog) => AlertDialog(
              title: const Text('Review Document Suggestion'),
              content: const SizedBox(
                height: 240,
                child: SingleChildScrollView(
                  child: Text('Generated document details.'),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialog),
                  child: const Text('Keep Editing'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(dialog),
                  child: const Text('Save Draft'),
                ),
              ],
            ),
          ),
          child: const Text('Generate document'),
        ),
      )),
    ));
    await tester.tap(find.text('Generate document'));
    await tester.pumpAndSettle();
    expect(find.text('Save Draft'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Keep Editing'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });
}
