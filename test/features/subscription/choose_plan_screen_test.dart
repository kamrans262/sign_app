import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/core/widgets/sign2digital_header.dart';
import 'package:sign2digital/core/widgets/sign2digital_primary_button.dart';
import 'package:sign2digital/features/subscription/domain/subscription_plan.dart';
import 'package:sign2digital/features/subscription/data/subscription_overview_repository.dart';
import 'package:sign2digital/features/subscription/presentation/screens/choose_plan_screen.dart';
import 'package:sign2digital/features/subscription/presentation/screens/subscription_overview_screen.dart';
import 'package:sign2digital/features/subscription/presentation/widgets/subscription_feature_list.dart';

class _MissingCatalog implements SubscriptionPlanCatalog {
  const _MissingCatalog();
  @override
  List<SubscriptionPlanOption> get options => const [];
}

Future<void> _scrollTo(WidgetTester tester, Key key) async {
  await tester.scrollUntilVisible(
    find.byKey(key),
    200,
    scrollable: find.descendant(
      of: find.byKey(const Key('choose-plan-scroll')),
      matching: find.byType(Scrollable),
    ).first,
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Uses detail header, shared card/features and fixed primary action',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ChoosePlanScreen()));
    expect(find.byType(Sign2DigitalHeader), findsOneWidget);
    expect(find.text('Subscription'), findsOneWidget);
    expect(find.byType(SubscriptionFeatureList), findsOneWidget);
    expect(find.byType(Sign2DigitalPrimaryButton), findsOneWidget);
    expect(find.text('Business Plan'), findsOneWidget);
    expect(find.text('CHF 20 / month'), findsOneWidget);
    expect(find.text('Email support'), findsOneWidget);
    await _scrollTo(tester, const Key('choose-plan-demo-notice'));
    expect(find.byKey(const Key('choose-plan-demo-notice')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Monthly and Yearly swap price and configurable features',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ChoosePlanScreen()));
    await tester.tap(find.byKey(const Key('details-tab-1')));
    await tester.pumpAndSettle();
    expect(find.text('CHF 200 / year'), findsOneWidget);
    expect(find.text('CHF 20 / month'), findsNothing);
    expect(find.text('Priority customer support'), findsOneWidget);
    expect(find.text('Advanced reports & analytics'), findsOneWidget);
    expect(find.text('Additional document storage'), findsOneWidget);
    expect(find.text('Extended AI usage benefits'), findsOneWidget);
    expect(find.text('Unlimited projects & job management'), findsOneWidget);
    await tester.tap(find.byKey(const Key('details-tab-0')));
    await tester.pumpAndSettle();
    expect(find.text('CHF 20 / month'), findsOneWidget);
    expect(find.text('Priority customer support'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Continue validates radio and forwards the full selected plan',
      (tester) async {
    final draft = SubscriptionPlanFlowState();
    SubscriptionPlanOption? continued;
    await tester.pumpWidget(MaterialApp(home: ChoosePlanScreen(
      flowState: draft,
      onContinue: (value) => continued = value,
    )));
    await tester.tap(find.byKey(const Key('choose-plan-continue')));
    await tester.pump();
    expect(find.text('Select the Business Plan to continue.'), findsOneWidget);
    expect(continued, isNull);

    await tester.tap(find.byKey(const Key('choose-plan-radio')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('choose-plan-continue')));
    expect(continued?.id, 'business');
    expect(continued?.period, SubscriptionBillingPeriod.monthly);
    expect(continued?.priceLabel, 'CHF 20 / month');
    expect(continued?.featureLabels.length, SubscriptionFeature.values.length);
    expect(draft.selectedPlan?.id, 'business');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Switching periods preserves an explicit choice and benefits',
      (tester) async {
    final draft = SubscriptionPlanFlowState();
    SubscriptionPlanOption? continued;
    await tester.pumpWidget(MaterialApp(home: ChoosePlanScreen(
      flowState: draft, onContinue: (plan) => continued = plan,
    )));
    await tester.tap(find.byKey(const Key('choose-plan-select')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('details-tab-1')));
    await tester.pumpAndSettle();
    expect(draft.selectedPlan?.period, SubscriptionBillingPeriod.yearly);
    await tester.tap(find.byKey(const Key('choose-plan-continue')));
    expect(continued?.priceLabel, 'CHF 200 / year');
    expect(continued?.featureLabels.length, SubscriptionFeature.values.length + 4);
    expect(continued?.featureLabels.last, 'Extended AI usage benefits');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Overview Manage Plan opens the selector and restores its draft',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: SubscriptionOverviewScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('subscription-manage-plan')));
    await tester.pumpAndSettle();
    expect(find.byType(ChoosePlanScreen), findsOneWidget);
    await tester.tap(find.byKey(const Key('details-tab-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('choose-plan-select')));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('subscription-manage-plan')));
    await tester.pumpAndSettle();
    expect(find.text('CHF 200 / year'), findsOneWidget);
    await tester.tap(find.byKey(const Key('choose-plan-continue')));
    await tester.pump();
    expect(
      find.text('Payment Details is not connected yet. Your selection is saved.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Missing catalog does not make up an offer', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: ChoosePlanScreen(catalog: _MissingCatalog()),
    ));
    expect(
      find.text('There is no configured plan for this billing period.'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('choose-plan-continue')));
    await tester.pump();
    expect(find.text('No configured plan is available for this billing period.'),
      findsOneWidget);
  });

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(800, 1024),
  ]) {
    testWidgets('Monthly and yearly scroll on viewport $size without overflow',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(home: ChoosePlanScreen()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('choose-plan-continue')), findsOneWidget);

      await tester.tap(find.byKey(const Key('details-tab-1')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await _scrollTo(tester, const Key('choose-plan-demo-notice'));
      expect(find.byKey(const Key('choose-plan-continue')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
