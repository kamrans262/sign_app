import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sign2digital/core/theme/app_colors.dart';
import 'package:sign2digital/core/widgets/sign2digital_selection_sheet.dart';

void main() {
  testWidgets('Shows branded title, selected row and returns chosen option',
      (tester) async {
    String? chosen;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(builder: (context) => ElevatedButton(
          onPressed: () async {
            chosen = await Sign2DigitalSelectionSheet.show(
              context,
              title: 'Language',
              options: const ['English', 'French', 'German'],
              selected: 'English',
              icon: Icons.language_rounded,
              keyForOption: (option) => Key('language-$option'),
            );
          },
          child: const Text('Open Dropdown'),
        )),
      ),
    ));
    await tester.tap(find.text('Open Dropdown'));
    await tester.pumpAndSettle();
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('Select an option'), findsOneWidget);
    expect(find.byKey(const Key('selection-sheet-options')), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    expect(find.byKey(const Key('selection-sheet-close')), findsOneWidget);
    expect(find.byType(Divider), findsWidgets);
    final selectedRow = find.ancestor(
      of: find.byKey(const Key('language-English')),
      matching: find.byType(Material),
    ).first;
    expect(tester.widget<Material>(selectedRow).color, isNot(AppColors.white));
    await tester.tap(find.byKey(const Key('language-German')));
    await tester.pumpAndSettle();
    expect(chosen, 'German');
    expect(find.byKey(const Key('selection-sheet-options')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Close dismisses without changing the selection',
      (tester) async {
    String? chosen = 'English';
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Builder(builder: (context) => TextButton(
        onPressed: () async {
          final result = await Sign2DigitalSelectionSheet.show(
            context,
            title: 'Language',
            options: const ['English', 'French'],
            selected: 'English',
          );
          if (result != null) chosen = result;
        },
        child: const Text('Open Dropdown'),
      ))),
    ));
    await tester.tap(find.text('Open Dropdown'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('selection-sheet-close')));
    await tester.pumpAndSettle();
    expect(chosen, 'English');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Long options scroll without overflow on narrow devices',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final values = List.generate(20, (i) => 'Option $i');
    String? chosen;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Builder(builder: (context) => TextButton(
        onPressed: () async {
          chosen = await Sign2DigitalSelectionSheet.show(
            context,
            title: 'Time Zone',
            options: values,
          );
        },
        child: const Text('Open Dropdown'),
      ))),
    ));
    await tester.tap(find.text('Open Dropdown'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.text('Option 19'),
      190,
      scrollable: find.descendant(
        of: find.byKey(const Key('selection-sheet-options')),
        matching: find.byType(Scrollable),
      ).first,
    );
    await tester.tap(find.text('Option 19'));
    await tester.pumpAndSettle();
    expect(chosen, 'Option 19');
    expect(tester.takeException(), isNull);
  });
}
