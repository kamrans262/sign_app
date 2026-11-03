import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/features/clients/domain/client_profile.dart';
import 'package:sign2digital/features/clients/presentation/screens/clients_screen.dart';

void main() {
  test('client initials, singular jobs, and search use typed fields', () {
    final client = ClientProfile(
      id: 'c1',
      companyName: 'Dupont Construction SA',
      companyType: 'Construction company',
      email: 'Contact@example.com',
      phone: '+41 21 123 45 67',
      jobCount: 1,
    );
    expect(client.initials, 'DC');
    expect(client.matches('DUPONT'), isTrue);
    expect(client.matches('example'), isTrue);
    expect(client.matches('+41'), isTrue);
    expect(client.matches('no match'), isFalse);
  });

  testWidgets(
    'Clients displays demo data, filters and supports clearing search',
    (tester) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(home: ClientsScreen()));
      // The Dashboard tab may schedule ongoing async widgets; a bounded frame
      // verifies the UI without waiting for unrelated perpetual work.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Clients'), findsOneWidget);
      expect(find.text('Dupont Construction SA'), findsWidgets);
      expect(find.text('12 jobs'), findsWidgets);

      final search = find.byKey(const Key('clients-search-input'));
      await tester.enterText(search, 'no matching client');
      // The Dashboard tab may schedule ongoing async widgets; a bounded frame
      // verifies the UI without waiting for unrelated perpetual work.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('No clients match your search'), findsOneWidget);
      await tester.tap(find.byTooltip('Clear search'));
      // The Dashboard tab may schedule ongoing async widgets; a bounded frame
      // verifies the UI without waiting for unrelated perpetual work.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Dupont Construction SA'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'fixed dashboard navigation switches tabs and returns to Clients',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: ClientsScreen()));
      // The Dashboard tab may schedule ongoing async widgets; a bounded frame
      // verifies the UI without waiting for unrelated perpetual work.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const Key('dashboard-tab-1')));
      // The Dashboard tab may schedule ongoing async widgets; a bounded frame
      // verifies the UI without waiting for unrelated perpetual work.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Active (12)'), findsOneWidget);
      await tester.tap(find.byKey(const Key('dashboard-tab-2')));
      // The Dashboard tab may schedule ongoing async widgets; a bounded frame
      // verifies the UI without waiting for unrelated perpetual work.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Manage your clients and contacts'), findsNothing);
      expect(find.byKey(const Key('open-quote-ui-demo')), findsNothing);
      expect(find.byKey(const Key('open-reports')), findsNothing);
      await tester.tap(find.byKey(const Key('dashboard-tab-4')));
      // The Dashboard tab may schedule ongoing async widgets; a bounded frame
      // verifies the UI without waiting for unrelated perpetual work.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('open-quote-ui-demo')), findsOneWidget);
      // The unchanged More menu is a lazy ListView: verify offscreen items
      // by scrolling to them instead of assuming they are eagerly built.
      final moreScroll = find.descendant(
        of: find.byKey(const Key('more-menu-scroll')),
        matching: find.byType(Scrollable),
      ).first;
      await tester.scrollUntilVisible(
        find.byKey(const Key('open-reports')), 130,
        scrollable: moreScroll, maxScrolls: 20,
      );
      await tester.pump();
      expect(find.byKey(const Key('open-reports')), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const Key('open-expenses')), 130,
        scrollable: moreScroll, maxScrolls: 20,
      );
      await tester.pump();
      expect(find.byKey(const Key('open-expenses')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in <Size>[
    const Size(320, 568),
    const Size(430, 932),
    const Size(800, 1180),
  ]) {
    testWidgets('Clients responsive: ${size.width} x ${size.height}', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(home: ClientsScreen()));
      // The Dashboard tab may schedule ongoing async widgets; a bounded frame
      // verifies the UI without waiting for unrelated perpetual work.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Clients'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
