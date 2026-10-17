import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/core/widgets/sign2digital_country_selector.dart';
import 'package:sign2digital/core/widgets/sign2digital_selection_sheet.dart';

void main() {
  testWidgets('shared selection sheet keeps Switch Company header and values',
      (tester) async {
    String? chosen;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Builder(builder: (context) => TextButton(
        onPressed: () async {
          chosen = await Sign2DigitalSelectionSheet.show(context,
            title: 'Switch company',
            icon: Icons.business_outlined,
            options: const ['Business A', 'Business B'],
            selected: 'Business A');
        },
        child: const Text('Show companies'),
      ))),
    ));
    await tester.tap(find.text('Show companies'));
    await tester.pumpAndSettle();
    expect(find.text('Switch company'), findsOneWidget);
    expect(find.byIcon(Icons.business_outlined), findsOneWidget);
    expect(find.byKey(const Key('selection-sheet-close')), findsOneWidget);
    expect(find.text('Business A'), findsOneWidget);
    await tester.tap(find.text('Business B'));
    await tester.pumpAndSettle();
    expect(chosen, 'Business B');
    expect(tester.takeException(), isNull);
  });

  testWidgets('custom picker returns its record without changing selection data',
      (tester) async {
    String? selectedId;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Builder(builder: (context) => TextButton(
        onPressed: () async {
          selectedId = await Sign2DigitalSelectionSheet.showCustom<String>(
            context: context,
            title: 'Select Job / Project',
            subtitle: 'Choose the job for this invoice',
            icon: Icons.work_outline_rounded,
            builder: (sheet) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  key: const Key('test-job-choice'),
                  title: const Text('Kitchen renovation'),
                  onTap: () => Navigator.pop(sheet, 'job-42'),
                ),
              ],
            ),
          );
        },
        child: const Text('Choose job'),
      ))),
    ));
    await tester.tap(find.text('Choose job'));
    await tester.pumpAndSettle();
    expect(find.text('Select Job / Project'), findsOneWidget);
    expect(find.byIcon(Icons.work_outline_rounded), findsOneWidget);
    expect(find.text('Choose the job for this invoice'), findsOneWidget);
    await tester.tap(find.byKey(const Key('test-job-choice')));
    await tester.pumpAndSettle();
    expect(selectedId, 'job-42');
    expect(tester.takeException(), isNull);
  });

  testWidgets('multi-select picker preserves independent selections',
      (tester) async {
    Set<String>? selected;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Builder(builder: (context) => TextButton(
        child: const Text('Choose team'),
        onPressed: () async {
          final working = <String>{'one'};
          selected = await Sign2DigitalSelectionSheet.showCustom<Set<String>>(
            context: context,
            title: 'Select Team Members',
            icon: Icons.groups_outlined,
            subtitle: 'Choose one or more team members',
            builder: (sheet) => StatefulBuilder(
              builder: (context, update) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CheckboxListTile(
                    value: working.contains('one'),
                    title: const Text('First worker'),
                    onChanged: (v) => update(() {
                      if (v == true) { working.add('one'); }
                      else { working.remove('one'); }
                    }),
                  ),
                  CheckboxListTile(
                    value: working.contains('two'),
                    title: const Text('Second worker'),
                    onChanged: (v) => update(() {
                      if (v == true) { working.add('two'); }
                      else { working.remove('two'); }
                    }),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(sheet, working),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ),
          );
        },
      ))),
    ));
    await tester.tap(find.text('Choose team'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Second worker'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(selected, containsAll(['one', 'two']));
    expect(tester.takeException(), isNull);
  });

  testWidgets('country-code search uses the shared header and returns ISO code',
      (tester) async {
    var country = Sign2DigitalCountries.switzerland;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: StatefulBuilder(
        builder: (context, setState) => Sign2DigitalCountrySelector(
          selected: country,
          onChanged: (next) => setState(() => country = next),
        ),
      )),
    ));
    await tester.tap(find.byKey(const Key('country-selector')));
    await tester.pumpAndSettle();
    expect(find.text('Select Country'), findsOneWidget);
    expect(find.byIcon(Icons.public_outlined), findsOneWidget);
    expect(find.byKey(const Key('selection-sheet-close')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('country-search')), 'Pakistan');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('country-PK')));
    await tester.pumpAndSettle();
    expect(country.isoCode, 'PK');
    expect(tester.takeException(), isNull);
  });
}
