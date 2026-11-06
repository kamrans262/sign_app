import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/core/widgets/sign2digital_bottom_navigation_bar.dart';
import 'package:sign2digital/core/widgets/sign2digital_dashboard_header.dart';
import 'package:sign2digital/features/clients/presentation/screens/more_screen.dart';
import 'package:sign2digital/features/clients/presentation/widgets/sign2digital_status_badge.dart';
import 'package:sign2digital/features/subscription/data/subscription_overview_repository.dart';
import 'package:sign2digital/features/subscription/presentation/screens/subscription_overview_screen.dart';
import 'package:sign2digital/features/subscription/presentation/screens/subscription_management_screen.dart';

class _StubRepository implements SubscriptionOverviewRepository {
  _StubRepository(this.data);
  final SubscriptionOverview data;
  bool fails = false;
  @override
  Future<SubscriptionOverview> load() async {
    if (fails) throw StateError('Subscription service unavailable');
    return data;
  }
}

Future<void> _scrollTo(WidgetTester tester, Key key) async {
  await tester.scrollUntilVisible(
    find.byKey(key),
    180,
    scrollable: find.descendant(
      of: find.byKey(const Key('subscription-scroll')),
      matching: find.byType(Scrollable),
    ).first,
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('More opens Subscription with the global header and More nav',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: MoreScreen()),
    ));
    await tester.tap(find.byKey(const Key('open-subscription')));
    await tester.pumpAndSettle();

    expect(find.byType(SubscriptionOverviewScreen), findsOneWidget);
    expect(find.byType(Sign2DigitalDashboardHeader), findsOneWidget);
    expect(
      tester.widget<Sign2DigitalBottomNavigationBar>(
        find.byType(Sign2DigitalBottomNavigationBar),
      ).selectedIndex,
      4,
    );
    expect(find.byKey(const Key('subscription-demo-notice')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Renders repository plan, status, entitlements and usage',
      (tester) async {
    final repository = _StubRepository(const SubscriptionOverview(
      planName: 'Business',
      status: 'Pending',
      priceLabel: 'CHF 89 / month',
      billingDescription: 'Renews only after payment confirmation',
      features: {SubscriptionFeature.aiDocuments, SubscriptionFeature.labour},
      usage: SubscriptionUsage(documents: 7, clients: 3, equipment: 1),
    ));
    await tester.pumpWidget(MaterialApp(
      home: SubscriptionOverviewScreen(repository: repository),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Business'), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget);
    expect(find.text('Active'), findsNothing);
    expect(find.text('CHF 89 / month'), findsOneWidget);
    expect(find.byType(Sign2DigitalStatusBadge), findsOneWidget);
    expect(find.byKey(const Key('subscription-demo-notice')), findsNothing);
    expect(find.text('AI document generation'), findsOneWidget);
    expect(find.text('Unlimited projects'), findsOneWidget);
    final usage = find.byKey(const Key('subscription-usage-documents'));
    await _scrollTo(tester, const Key('subscription-usage-documents'));
    expect(find.descendant(of: usage, matching: find.text('7')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Billing, management and details actions use supplied callbacks',
      (tester) async {
    var billing = 0;
    var manage = 0;
    var details = 0;
    await tester.pumpWidget(MaterialApp(
      home: SubscriptionOverviewScreen(
        onViewBilling: () => billing++,
        onManagePlan: () => manage++,
        onViewUsage: () => details++,
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('subscription-view-billing')));
    await tester.tap(find.byKey(const Key('subscription-manage-plan')));
    expect(billing, 1);
    expect(manage, 1);

    await _scrollTo(tester, const Key('subscription-view-details'));
    await tester.tap(find.byKey(const Key('subscription-view-details')));
    expect(details, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('View Billing opens the implemented subscription management screen',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: SubscriptionOverviewScreen(),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('subscription-view-billing')));
    await tester.pumpAndSettle();
    expect(find.text('Current Plan'), findsOneWidget);
    expect(find.byType(SubscriptionManagementScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Missing account fields are not replaced with paid fixture',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: SubscriptionOverviewScreen(
        repository: _StubRepository(const SubscriptionOverview()),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Plan unavailable'), findsOneWidget);
    expect(find.text('Unknown'), findsOneWidget);
    expect(find.text('Active'), findsNothing);
    expect(find.text('Plan features are unavailable.'), findsOneWidget);
    expect(find.byKey(const Key('subscription-demo-notice')), findsNothing);
  });

  testWidgets('Failed repository load shows retry without fake data',
      (tester) async {
    final repo = _StubRepository(const SubscriptionOverview(
      planName: 'Real account',
    ))..fails = true;
    await tester.pumpWidget(MaterialApp(
      home: SubscriptionOverviewScreen(repository: repo),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('subscription-retry')), findsOneWidget);
    expect(find.text('Professional'), findsNothing);
    repo.fails = false;
    await tester.tap(find.byKey(const Key('subscription-retry')));
    await tester.pumpAndSettle();
    expect(find.text('Real account'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(800, 1024),
  ]) {
    testWidgets('Subscription fits viewport $size without overflow',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(
        home: SubscriptionOverviewScreen(),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // The last usage card is lazily built on narrow phones.
      // Scroll until the card is actually visible instead of assuming
      // a fixed pixel drag reaches it at every viewport size.
      await _scrollTo(tester, const Key('subscription-usage-equipment'));
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('subscription-usage-equipment')),
        findsOneWidget);
    });
  }
}
