import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/core/widgets/sign2digital_modal_guard.dart';

void main() {
  testWidgets('rapid taps create one sheet and allow a nested child picker',
      (tester) async {
    var parentOpens = 0;
    var childOpens = 0;

    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: Builder(builder: (screen) => FilledButton(
        onPressed: () {
          Sign2DigitalModalGuard.run<void>(screen, () => showModalBottomSheet<void>(
            context: screen,
            builder: (sheet) {
              parentOpens++;
              return Builder(builder: (inner) => FilledButton(
                onPressed: () {
                  Sign2DigitalModalGuard.run<void>(inner, () =>
                    showModalBottomSheet<void>(
                      context: inner,
                      builder: (_) {
                        childOpens++;
                        return const Text('Child picker');
                      },
                    ));
                },
                child: const Text('Open child'),
              ));
            },
          ));
        },
        child: const Text('Open parent'),
      )),
    )));

    await tester.tap(find.text('Open parent'));
    await tester.tap(find.text('Open parent'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(parentOpens, 1);

    await tester.tap(find.text('Open child'));
    await tester.pumpAndSettle();
    expect(childOpens, 1);
    expect(find.text('Child picker'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Child picker'), findsNothing);
    expect(find.text('Open child'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Open parent'), findsOneWidget);
  });
}
