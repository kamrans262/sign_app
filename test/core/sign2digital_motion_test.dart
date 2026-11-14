import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/core/theme/app_theme.dart';
import 'package:sign2digital/core/theme/sign2digital_motion.dart';

void main() {
  test('page and sheet motion are configured through shared theme tokens', () {
    expect(AppTheme.light.pageTransitionsTheme,
        Sign2DigitalMotion.pageTransitions);
    expect(AppTheme.dark.pageTransitionsTheme,
        Sign2DigitalMotion.pageTransitions);
    expect(Sign2DigitalMotion.bottomSheet.duration,
        const Duration(milliseconds: 300));
  });

  testWidgets('tab fade preserves unsaved text while switching screens',
      (tester) async {
    final input = TextEditingController();
    addTearDown(input.dispose);
    var index = 0;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: StatefulBuilder(builder: (context, setState) => Scaffold(
        body: Column(children: [
          Row(children: [
            TextButton(onPressed: () => setState(() => index = 0),
                child: const Text('First')),
            TextButton(onPressed: () => setState(() => index = 1),
                child: const Text('Second')),
          ]),
          Expanded(child: Sign2DigitalAnimatedIndexedStack(
            index: index,
            children: [
              TextField(key: const Key('draft'), controller: input),
              const Center(child: Text('Other tab')),
            ],
          )),
        ]),
      )),
    ));
    await tester.enterText(find.byKey(const Key('draft')), 'unsaved details');
    await tester.tap(find.text('Second'));
    await tester.pumpAndSettle();
    expect(find.text('Other tab'), findsOneWidget);
    await tester.tap(find.text('First'));
    await tester.pumpAndSettle();
    expect(input.text, 'unsaved details');
    expect(tester.takeException(), isNull);
  });
}
