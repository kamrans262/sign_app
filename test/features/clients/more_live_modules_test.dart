import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/features/clients/presentation/screens/more_screen.dart';

void main() {
  testWidgets('More displays exactly the eleven real product modules',
      (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: MoreScreen()),
    ));
    await tester.pumpAndSettle();

    final expected = <String, String>{
      'open-profile-settings': 'Profile & Settings',
      'open-global-search': 'Search Across the App',
      'open-ai-documents': 'AI Documents',
      'open-reports': 'Reports',
      'open-time-labour': 'Time & Labour',
      'open-invoices': 'Invoices',
      'open-reminders': 'Reminders',
      'open-equipment': 'Equipment',
      'open-deposits': 'Deposits',
      'open-expenses': 'Expenses',
      'open-subscription': 'Subscription',
    };

    final list = find.byKey(const Key('more-menu-scroll'));
    expect(list, findsOneWidget);
    for (final entry in expected.entries) {
      await tester.scrollUntilVisible(find.byKey(Key(entry.key)), 100,
          scrollable: find.descendant(of: list,
            matching: find.byType(Scrollable)).first);
      expect(find.text(entry.value), findsOneWidget);
    }
    expect(find.text('Quote UI Demo'), findsNothing);
    expect(find.text('Subscription Management'), findsNothing);
    expect(find.byKey(const Key('open-quote-ui-demo')), findsNothing);
    expect(find.byKey(const Key('open-subscription-management')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
