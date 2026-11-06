import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:sign2digital/core/services/active_company_session.dart';
import 'package:sign2digital/core/services/sign_api_client.dart';
import 'package:sign2digital/features/subscription/data/remote_subscription_repository.dart';
import 'package:sign2digital/features/subscription/domain/subscription_plan.dart';
import 'package:sign2digital/features/subscription/presentation/screens/choose_plan_screen.dart';
import 'package:sign2digital/features/subscription/presentation/screens/subscription_management_screen.dart';
import 'package:sign2digital/features/subscription/presentation/screens/subscription_overview_screen.dart';
import 'package:sign2digital/features/subscription/presentation/screens/subscription_payment_details_screen.dart';

Map<String, dynamic> _overview(int companyId) => {
  'company_id': companyId,
  'plan_name': 'Free allowance',
  'status': 'free',
  'price_label': null,
  'billing_description': 'No paid subscription is connected.',
  'features': null,
  'usage': {'documents': 1, 'clients': 2, 'equipment': 3},
  'allowance': {
    'limit': 3,
    'used': 1,
    'remaining': 2,
    'enforcement_enabled': false,
  },
  'can_checkout': false,
  'demo_only': false,
};

Map<String, dynamic> _plans(int companyId) => {
  'company_id': companyId,
  'checkout_available': false,
  'plans': [
    {
      'code':'business', 'name':'Business',
      'period':'monthly', 'price_label':'CHF 20.00 / month',
      'description':'Basic business plan',
      'feature_labels':['Invoices & deposits','Email support'],
    },
    {
      'code':'business', 'name':'Business',
      'period':'yearly', 'price_label':'CHF 200.00 / year',
      'description':'Annual business plan',
      'feature_labels':['Invoices & deposits','Email support'],
    },
  ],
};

SignApiClient _api({int companyId = 11, bool wrongCompany = false}) {
  return SignApiClient(
    baseUrl: Uri.parse('https://example.test'),
    tokenProvider: () async => 'valid-test-token',
    activeCompanyId: () => ActiveCompanySession.companyId,
    httpClient: MockClient((request) async {
      if (!request.headers.containsKey('authorization')) {
        return http.Response('Unauthorized', 401);
      }
      final expected = ActiveCompanySession.companyId.toString();
      if (request.headers['x-company-id'] != expected &&
          request.headers['X-Company-Id'] != expected) {
        return http.Response('Company header missing', 400);
      }
      final data = switch (request.url.path) {
        '/api/v1/billing/overview' => _overview(
          wrongCompany ? 99 : companyId),
        '/api/v1/billing/plans' => _plans(
          wrongCompany ? 99 : companyId),
        '/api/v1/billing/usage' => {
          'company_id': companyId,
          'allowance': {'limit':3,'used':1,'remaining':2},
          'by_type': {'quote':1},'recent': <Object>[],
        },
        '/api/v1/billing/history' => {
          'invoices': <Object>[], 'events': <Object>[],
          'provider_connected': false,
        },
        _ => throw StateError('Unexpected API request ${request.url.path}'),
      };
      return http.Response(jsonEncode({'data':data}), 200,
        headers: {'content-type':'application/json'});
    }),
  );
}

void main() {
  setUp(() => ActiveCompanySession.set(11));
  tearDown(ActiveCompanySession.clear);

  test('Remote overview is free, shows authoritative quota and never demo paid data',
      () async {
    final overview = await RemoteSubscriptionRepository(api:_api()).load();
    expect(overview.demoOnly, isFalse);
    expect(overview.status, 'free');
    expect(overview.priceLabel, isNull);
    expect(overview.features, isNull);
    expect(overview.freeDocumentLimit, 3);
    expect(overview.freeDocumentsRemaining, 2);
    expect(overview.usage.documents, 1);
    expect(overview.canCheckout, isFalse);
  });

  test('Remote plans contain only backend-approved catalog amounts and features',
      () async {
    final catalog = RemoteSubscriptionPlanCatalog(api:_api());
    expect(catalog.options, isEmpty);
    await catalog.load();
    expect(catalog.options.length, 2);
    expect(catalog.options.first.priceLabel, 'CHF 20.00 / month');
    expect(catalog.options.last.period, SubscriptionBillingPeriod.yearly);
    expect(catalog.options.first.demoOnly, isFalse);
    expect(catalog.options.first.featureLabels, contains('Email support'));
  });

  test('Tenant mismatch cannot be treated as a subscription', () async {
    final repository = RemoteSubscriptionRepository(
      api:_api(wrongCompany:true));
    await expectLater(repository.load(), throwsA(isA<SignApiException>()));
    final catalog = RemoteSubscriptionPlanCatalog(api:_api(wrongCompany:true));
    await expectLater(catalog.load(), throwsA(isA<SignApiException>()));
    expect(catalog.options, isEmpty);
  });

  test('Switching the active company invalidates previous company requests',
      () async {
    final repository = RemoteSubscriptionRepository(api:_api(companyId:11));
    final original = await repository.load();
    expect(original.status, 'free');
    ActiveCompanySession.set(21);
    await expectLater(repository.load(),throwsA(isA<SignApiException>()));
  });

  testWidgets('Real overview keeps approved layout and displays free allowance',
      (tester) async {
    await tester.pumpWidget(MaterialApp(home: SubscriptionOverviewScreen(
      repository: RemoteSubscriptionRepository(api:_api()))));
    await tester.pumpAndSettle();
    expect(find.text('Free allowance'), findsOneWidget);
    expect(find.text('Price unavailable'), findsOneWidget);
    expect(find.text('Active'), findsNothing);
    expect(find.byKey(const Key('m23-free-document-allowance')), findsOneWidget);
    expect(find.text('Free documents remaining: 2 of 3'), findsOneWidget);
    expect(find.byKey(const Key('subscription-demo-notice')), findsNothing);
    expect(tester.takeException(),isNull);
  });

  testWidgets('Real monthly/yearly plans go to safe payment review',
      (tester) async {
    final catalog=RemoteSubscriptionPlanCatalog(api:_api());
    await tester.pumpWidget(MaterialApp(home: ChoosePlanScreen(
      catalog:catalog)));
    await tester.pumpAndSettle();
    expect(find.text('CHF 20.00 / month'),findsOneWidget);
    expect(find.byKey(const Key('choose-plan-demo-notice')),findsNothing);
    await tester.tap(find.byKey(const Key('details-tab-1')));
    await tester.pumpAndSettle();
    expect(find.text('CHF 200.00 / year'),findsOneWidget);
    await tester.tap(find.byKey(const Key('choose-plan-select')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('choose-plan-continue')));
    await tester.pumpAndSettle();
    expect(find.byType(SubscriptionPaymentDetailsScreen),findsOneWidget);
    expect(find.text('CHF 200.00 / year'),findsOneWidget);
    expect(find.byKey(const Key('m23-stripe-disabled')),findsOneWidget);
    final checkout = tester.widget<FilledButton>(
      find.descendant(
        of:find.byKey(const Key('m23-checkout-unavailable')),
        matching:find.byType(FilledButton)));
    expect(checkout.onPressed,isNull);
    expect(tester.takeException(),isNull);
  });

  testWidgets('Verified billing history is empty rather than fabricated',
      (tester) async {
    await tester.pumpWidget(MaterialApp(home:SubscriptionManagementScreen(
      repository:RemoteSubscriptionRepository(api:_api()))));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('subscription-action-billing-history')));
    await tester.tap(find.byKey(const Key('subscription-action-billing-history')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('m23-no-billing-history')),findsOneWidget);
    expect(find.text('CHF 49 / month'), findsNothing);
    expect(tester.takeException(),isNull);
  });

  for (final size in [const Size(320,568),const Size(1180,700)]) {
    testWidgets('Subscription screen preserves portrait and full-width landscape $size',
        (tester) async {
      tester.view.physicalSize=size;
      tester.view.devicePixelRatio=1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(home:SubscriptionOverviewScreen(
        repository:RemoteSubscriptionRepository(api:_api()))));
      await tester.pumpAndSettle();
      final width = tester.getSize(
        find.byKey(const Key('subscription-scroll'))).width;
      if(size.width>size.height) {
        expect(width,greaterThan(1000));
      }else {
        expect(width,lessThanOrEqualTo(720));
      }
      expect(tester.takeException(),isNull);
    });
  }
}
