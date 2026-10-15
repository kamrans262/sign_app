import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/core/widgets/sign2digital_bottom_navigation_bar.dart';
import 'package:sign2digital/core/widgets/sign2digital_header.dart';
import 'package:sign2digital/features/subscription/data/subscription_overview_repository.dart';
import 'package:sign2digital/features/subscription/domain/subscription_plan.dart';
import 'package:sign2digital/features/subscription/presentation/screens/choose_plan_screen.dart';
import 'package:sign2digital/features/subscription/presentation/screens/subscription_management_screen.dart';
import 'package:sign2digital/features/subscription/presentation/screens/subscription_overview_screen.dart';
import 'package:sign2digital/features/subscription/presentation/widgets/subscription_current_plan_card.dart';
import 'package:sign2digital/features/subscription/presentation/widgets/subscription_management_action_card.dart';

class _StubRepository implements SubscriptionOverviewRepository {
  _StubRepository(this.value);
  SubscriptionOverview value;
  bool fail = false;

  @override
  Future<SubscriptionOverview> load() async {
    if (fail) throw StateError('offline');
    return value;
  }
}

Future<void> _scrollTo(WidgetTester tester, Key key) async {
  await tester.scrollUntilVisible(
    find.byKey(key),
    180,
    scrollable: find.descendant(
      of: find.byKey(const Key('subscription-management-scroll')),
      matching: find.byType(Scrollable),
    ).first,
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Uses shared plan card, header, More navigation and action cards',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: SubscriptionManagementScreen(),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(Sign2DigitalHeader), findsOneWidget);
    expect(find.text('Subscription'), findsOneWidget);
    expect(find.text('Current Plan'), findsOneWidget);
    expect(find.byType(SubscriptionCurrentPlanCard), findsOneWidget);
    expect(find.byType(SubscriptionManagementActionCard), findsNWidgets(5));
    expect(tester.widget<Sign2DigitalBottomNavigationBar>(
      find.byType(Sign2DigitalBottomNavigationBar)).selectedIndex, 4);
    expect(find.text('Professional'), findsOneWidget);
    expect(find.text('CHF 49 / month'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
    expect(find.byKey(const Key('subscription-demo-notice')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Management renders repository values without fabricating status',
      (tester) async {
    final repo = _StubRepository(const SubscriptionOverview(
      planName: 'Business Plan',
      priceLabel: 'CHF 20 / month',
      status: 'Pending',
      billingDescription: 'Billed monthly · Renewal is not confirmed',
      usage: SubscriptionUsage(documents: 4, clients: 2, equipment: 1),
    ));
    await tester.pumpWidget(MaterialApp(
      home: SubscriptionManagementScreen(repository: repo),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Business Plan'), findsOneWidget);
    expect(find.text('CHF 20 / month'), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget);
    expect(find.text('Active'), findsNothing);
    expect(find.text('Billed monthly'), findsOneWidget);
    expect(find.text('Renewal is not confirmed'), findsOneWidget);
    expect(find.byKey(const Key('subscription-demo-notice')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Overview View Billing opens Management using shared plan card',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: SubscriptionOverviewScreen(),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(SubscriptionCurrentPlanCard), findsOneWidget);
    await tester.tap(find.byKey(const Key('subscription-view-billing')));
    await tester.pumpAndSettle();
    expect(find.byType(SubscriptionManagementScreen), findsOneWidget);
    expect(find.byType(SubscriptionCurrentPlanCard), findsOneWidget);
    expect(find.text('Current Plan'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Change Plan keeps yearly draft across backward navigation',
      (tester) async {
    final flow = SubscriptionPlanFlowState();
    await tester.pumpWidget(MaterialApp(
      home: SubscriptionManagementScreen(flowState: flow),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('subscription-action-change-plan')));
    await tester.pumpAndSettle();
    expect(find.byType(ChoosePlanScreen), findsOneWidget);
    await tester.tap(find.byKey(const Key('details-tab-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('choose-plan-select')));
    await tester.pumpAndSettle();
    expect(flow.selectedPlan?.period, SubscriptionBillingPeriod.yearly);
    expect(flow.selectedPlan?.priceLabel, 'CHF 200 / year');
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pumpAndSettle();
    expect(find.byType(SubscriptionManagementScreen), findsOneWidget);
    await tester.tap(find.byKey(const Key('subscription-action-change-plan')));
    await tester.pumpAndSettle();
    expect(find.text('CHF 200 / year'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Unconnected billing actions do not manufacture payment records',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: SubscriptionManagementScreen(),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('subscription-action-payment-method')));
    await tester.pump();
    expect(find.text('Payment Method is not connected yet.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('subscription-action-billing-history')));
    await tester.pump();
    expect(find.text('Subscription billing history is not connected yet.'),
      findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Usage opens existing repository statistics', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: SubscriptionManagementScreen(),
    ));
    await tester.pumpAndSettle();
    await _scrollTo(tester, const Key('subscription-action-usage'));
    await tester.tap(find.byKey(const Key('subscription-action-usage')));
    await tester.pumpAndSettle();
    expect(find.text('Usage This Month'), findsOneWidget);
    expect(find.text('Documents'), findsOneWidget);
    expect(find.text('24'), findsOneWidget);
    expect(find.text('8'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('Demo preview · Usage values are samples.'),
      findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Cancellation requires confirmation and no callback changes no data',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: SubscriptionManagementScreen(),
    ));
    await tester.pumpAndSettle();
    await _scrollTo(tester, const Key('subscription-action-cancel'));
    await tester.tap(find.byKey(const Key('subscription-action-cancel')));
    await tester.pumpAndSettle();
    expect(find.text('Cancel Subscription?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('subscription-keep-plan')));
    await tester.pumpAndSettle();
    expect(find.text('Cancel Subscription?'), findsNothing);
    expect(find.text('Active'), findsOneWidget);

    await tester.tap(find.byKey(const Key('subscription-action-cancel')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('subscription-confirm-cancel')));
    await tester.pump();
    expect(find.text('Cancellation is not connected. No changes were made.'),
      findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Connected cancel handler runs only after explicit confirmation',
      (tester) async {
    var requests = 0;
    await tester.pumpWidget(MaterialApp(
      home: SubscriptionManagementScreen(
        onConfirmCancellation: (current) async {
          expect(current.planName, 'Professional');
          requests++;
        },
      ),
    ));
    await tester.pumpAndSettle();
    await _scrollTo(tester, const Key('subscription-action-cancel'));
    await tester.tap(find.byKey(const Key('subscription-action-cancel')));
    await tester.pumpAndSettle();
    expect(requests, 0);
    await tester.tap(find.byKey(const Key('subscription-confirm-cancel')));
    await tester.pumpAndSettle();
    expect(requests, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Unavailable subscription does not claim an active plan',
      (tester) async {
    final repo = _StubRepository(const SubscriptionOverview());
    await tester.pumpWidget(MaterialApp(
      home: SubscriptionManagementScreen(repository: repo),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Plan unavailable'), findsOneWidget);
    expect(find.text('Unknown'), findsOneWidget);
    expect(find.text('Active'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Error shows retry and recovers', (tester) async {
    final repo = _StubRepository(const SubscriptionOverview(
      planName: 'Verified plan',
    ))..fail = true;
    await tester.pumpWidget(MaterialApp(
      home: SubscriptionManagementScreen(repository: repo),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('subscription-management-retry')),
      findsOneWidget);
    expect(find.text('Professional'), findsNothing);
    repo.fail = false;
    await tester.tap(find.byKey(const Key('subscription-management-retry')));
    await tester.pumpAndSettle();
    expect(find.text('Verified plan'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(800, 1024),
  ]) {
    testWidgets('Five actions remain reachable without overflow at $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(
        home: SubscriptionManagementScreen(),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await _scrollTo(tester, const Key('subscription-action-cancel'));
      expect(find.byKey(const Key('subscription-action-cancel')),
        findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
