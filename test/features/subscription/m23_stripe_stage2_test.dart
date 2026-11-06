import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:sign2digital/core/services/active_company_session.dart';
import 'package:sign2digital/core/services/sign_api_client.dart';
import 'package:sign2digital/features/subscription/data/remote_subscription_repository.dart';
import 'package:sign2digital/features/subscription/domain/subscription_plan.dart';
import 'package:sign2digital/features/subscription/presentation/screens/subscription_payment_details_screen.dart';

const _plan = SubscriptionPlanOption(
  id: 'business', serverPlanId: 7, canCheckout: true,
  name: 'Business', period: SubscriptionBillingPeriod.monthly,
  priceLabel: 'CHF 20.00 / month',
  description: 'Business essentials',
  featureLabels: ['Invoices & deposits', 'Email support'],
);

class _FakeStripeApi {
  _FakeStripeApi({this.verified = false, this.checkoutHost = 'checkout.stripe.com'});
  final bool verified;
  final String checkoutHost;
  final requests = <String>[];
  late final api = SignApiClient(
    baseUrl: Uri.parse('https://example.test'),
    tokenProvider: () async => 'bearer_test',
    activeCompanyId: () => ActiveCompanySession.companyId,
    httpClient: MockClient((request) async {
      requests.add('${request.method} ${request.url.path}');
      if (request.headers['X-Company-Id'] != '11' &&
          request.headers['x-company-id'] != '11') {
        return http.Response(jsonEncode({'message':'Invalid company'}),403,
          headers: {'content-type':'application/json'});
      }
      Map<String,dynamic> response;
      switch (request.url.path) {
        case '/api/v1/billing/checkout':
          final body=jsonDecode(request.body) as Map<String,dynamic>;
          if(body['plan_id']!=7 || body['request_id'] is! String){
            return http.Response(jsonEncode({'message':'Wrong plan'}),422);
          }
          response={
            'intent_id':body['request_id'],
            'status':'pending','charged':false,
            'checkout_url':'https://$checkoutHost/c/pay/test',
          };
        case '/api/v1/billing/checkout/11111111-1111-4111-8111-111111111111/status':
          response={'status':verified?'active':'pending','verified':verified};
        case '/api/v1/billing/portal':
          response={'portal_url':'https://billing.stripe.com/p/session/test'};
        case '/api/v1/billing/cancel':
          response={'status':'active','cancel_at_period_end':true};
        case '/api/v1/billing/resume':
          response={'status':'active','cancel_at_period_end':false};
        case '/api/v1/billing/change-preview':
          response={'currency':'chf','amount_due_minor':2000,'confirmed':false};
        case '/api/v1/billing/change':
          response={'status':'active','plan_id':7};
        default:
          return http.Response(jsonEncode({'message':'Unrecognized API route'}),404,
            headers:{'content-type':'application/json'});
      }
      return http.Response(jsonEncode({'data':response}),200,
        headers:{'content-type':'application/json'});
    }),
  );
}

void main(){
  setUp(()=>ActiveCompanySession.set(11));
  tearDown(ActiveCompanySession.clear);

  test('Checkout is server-priced and never marked paid by a URL',() async {
    final fake=_FakeStripeApi();
    final repo=RemoteSubscriptionRepository(api:fake.api);
    final attempt=await repo.startCheckout(7,
      requestId:'11111111-1111-4111-8111-111111111111');
    expect(attempt.url.host,'checkout.stripe.com');
    expect(attempt.intentId,'11111111-1111-4111-8111-111111111111');
    expect(fake.requests,contains('POST /api/v1/billing/checkout'));
    final state=await repo.checkoutStatus(attempt.intentId);
    expect(state.verified,isFalse);
    expect(state.status,'pending');
    final completed=await RemoteSubscriptionRepository(
      api:_FakeStripeApi(verified:true).api).checkoutStatus(attempt.intentId);
    expect(completed.verified,isTrue);
    expect(completed.status,'active');
  });

  test('Untrusted server checkout host is rejected before browser launch',() async {
    final fake=_FakeStripeApi(checkoutHost:'evil.example');
    final repository=RemoteSubscriptionRepository(api:fake.api);
    await expectLater(repository.startCheckout(7,
      requestId:'11111111-1111-4111-8111-111111111111'),
      throwsA(isA<SignApiException>()));
    expect(fake.requests,contains('POST /api/v1/billing/checkout'));
  });

  test('Stripe-hosted URLs are restricted to official HTTPS domains',(){
    expect(()=>RemoteSubscriptionRepository.hostedUrl(
      'https://checkout.stripe.com/c/pay/session'),returnsNormally);
    for(final url in [
      'https://evil.example/pay','http://checkout.stripe.com/c/pay/x',
      'https://checkout.stripe.com.evil.example/pay',
      'https://checkout.stripe.com:444/c/pay/x',
      'https://billing.stripe.com/p/session/x',
    ]){
      expect(()=>RemoteSubscriptionRepository.hostedUrl(url),
          throwsA(isA<SignApiException>()));
    }
    expect(()=>RemoteSubscriptionRepository.hostedUrl(
      'https://billing.stripe.com/p/session/x',portal:true),
      returnsNormally);
  });

  test('Portal, cancel, resume and change requests are server owned',() async {
    final fake=_FakeStripeApi();
    final repo=RemoteSubscriptionRepository(api:fake.api);
    final portal=await repo.portal();
    expect(portal.host,'billing.stripe.com');
    final cancel=await repo.cancel();
    expect(cancel['cancel_at_period_end'],isTrue);
    final resume=await repo.resume();
    expect(resume['cancel_at_period_end'],isFalse);
    final preview=await repo.previewChange(7);
    expect(preview['amount_due_minor'],2000);
    await repo.changePlan(7,
      requestId:'11111111-1111-4111-8111-111111111111');
    expect(fake.requests,contains('POST /api/v1/billing/change-preview'));
    expect(fake.requests,contains('POST /api/v1/billing/change'));
  });

  test('Company switching rejects stale payment operations',() async {
    final fake=_FakeStripeApi();
    final repo=RemoteSubscriptionRepository(api:fake.api);
    ActiveCompanySession.clear();
    await expectLater(repo.startCheckout(7),
        throwsA(isA<SignApiException>()));
    expect(fake.requests,isEmpty);
  });

  testWidgets('Hosted checkout is opened but never instantly confirmed',
      (tester) async {
    final fake=_FakeStripeApi();
    Uri? opened;
    await tester.pumpWidget(MaterialApp(
      home:SubscriptionPaymentDetailsScreen(
        plan:_plan,
        repository:RemoteSubscriptionRepository(api:fake.api),
        browserLauncher:(url) async { opened=url; return true; },
      )));
    expect(find.text('Secure Stripe Checkout'),findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('m23-checkout-unavailable')));
    await tester.tap(find.byKey(const Key('m23-checkout-unavailable')));
    await tester.pumpAndSettle();
    expect(opened?.host,'checkout.stripe.com');
    expect(find.textContaining('Checkout opened securely'),findsOneWidget);
    expect(find.textContaining('Provider verified'),findsNothing);
    expect(find.byKey(const Key('m23-verify-checkout')),findsOneWidget);
    expect(tester.takeException(),isNull);
  });

  testWidgets('No Stripe configuration means no browser or payment action',
      (tester) async {
    final fake=_FakeStripeApi();
    await tester.pumpWidget(MaterialApp(
      home:SubscriptionPaymentDetailsScreen(
        plan:const SubscriptionPlanOption(
          id:'business',name:'Business',
          period:SubscriptionBillingPeriod.monthly,
          priceLabel:'CHF 20 / month',description:'Preview',
          featureLabels:[],serverPlanId:7,canCheckout:false,
        ),
        repository:RemoteSubscriptionRepository(api:fake.api),
      )));
    final checkout=tester.widget<FilledButton>(find.descendant(
      of:find.byKey(const Key('m23-checkout-unavailable')),
      matching:find.byType(FilledButton)));
    expect(checkout.onPressed,isNull);
    expect(fake.requests,isEmpty);
    expect(find.text('Payment setup is pending'),findsOneWidget);
  });

  testWidgets('Plan changes require a preview and explicit confirmation',
      (tester) async {
    final fake=_FakeStripeApi();
    await tester.pumpWidget(MaterialApp(
      home:SubscriptionPaymentDetailsScreen(
        plan:_plan,changeExistingPlan:true,
        repository:RemoteSubscriptionRepository(api:fake.api),
      )));
    await tester.tap(find.byKey(const Key('m23-checkout-unavailable')));
    await tester.pumpAndSettle();
    expect(find.text('Confirm Plan Change'),findsOneWidget);
    expect(fake.requests,contains('POST /api/v1/billing/change-preview'));
    expect(fake.requests, isNot(contains('POST /api/v1/billing/change')));
    await tester.tap(find.text('Keep Current Plan'));
    await tester.pumpAndSettle();
    expect(fake.requests,isNot(contains('POST /api/v1/billing/change')));
    await tester.tap(find.byKey(const Key('m23-checkout-unavailable')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('m23-confirm-plan-change')));
    await tester.pumpAndSettle();
    expect(fake.requests,contains('POST /api/v1/billing/change'));
    expect(find.textContaining('verified billing'),findsOneWidget);
    expect(tester.takeException(),isNull);
  });

  for(final viewport in [const Size(320,568),const Size(1200,750)]){
    testWidgets('Stripe review preserves responsive approved layout $viewport',
        (tester) async {
      tester.view.physicalSize=viewport;
      tester.view.devicePixelRatio=1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
        home:SubscriptionPaymentDetailsScreen(plan:_plan,
          repository:RemoteSubscriptionRepository(api:_FakeStripeApi().api))));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('m23-review-price')),findsOneWidget);
      expect(tester.takeException(),isNull);
    });
  }
}
