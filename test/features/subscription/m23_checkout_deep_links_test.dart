import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:sign2digital/core/services/active_company_session.dart';
import 'package:sign2digital/core/services/sign_api_client.dart';
import 'package:sign2digital/features/subscription/data/remote_subscription_repository.dart';
import 'package:sign2digital/features/subscription/services/m23_billing_deep_links.dart';
import 'package:sign2digital/features/subscription/presentation/screens/m23_checkout_return_screen.dart';

const _intent = '33333333-3333-4333-8333-333333333333';

void main() {
  setUp(() => ActiveCompanySession.set(11));
  tearDown(ActiveCompanySession.clear);

  test('Accept only our checkout URLs with properly scoped request IDs', () {
    final success = M23BillingReturn.parse(
      Uri.parse('sign2digital://billing/success?intent=$_intent'));
    expect(success?.kind, M23BillingReturnKind.success);
    expect(success?.intentId, _intent);
    final canceled = M23BillingReturn.parse(
      Uri.parse('sign2digital://billing/cancel?intent=$_intent'));
    expect(canceled?.kind, M23BillingReturnKind.cancel);
    expect(M23BillingReturn.parse(
      Uri.parse('sign2digital://billing/portal'))?.kind,
      M23BillingReturnKind.portal);
    for (final raw in [
      'sign2digital://billing/success',
      'sign2digital://evil.example/success?intent=$_intent',
      'https://billing/success?intent=$_intent',
      'sign2digital://billing/success?intent=1',
      'sign2digital://billing/success?intent=$_intent&status=paid',
      'sign2digital://billing/success?intent=$_intent#fragment',
      'sign2digital://billing/portal?status=paid',
      'sign2digital://billing/admin?intent=$_intent',
    ]) {
      expect(M23BillingReturn.parse(Uri.parse(raw)), isNull,
          reason: 'Untrusted callback: $raw');
    }
  });

  RemoteSubscriptionRepository repository({required bool verified}) {
    final api = SignApiClient(
      baseUrl: Uri.parse('https://example.test'),
      tokenProvider: () async => 'test_bearer',
      activeCompanyId: () => ActiveCompanySession.companyId,
      httpClient: MockClient((request) async {
        if (request.url.path != '/api/v1/billing/checkout/$_intent/status') {
          return http.Response(jsonEncode({'message':'Unknown API'}), 404);
        }
        return http.Response(jsonEncode({'data':{
          'status':verified?'active':'pending','verified':verified,
        }}), 200, headers: {'content-type':'application/json'});
      }),
    );
    return RemoteSubscriptionRepository(api: api);
  }

  testWidgets('browser success cannot forge paid access when Stripe unverified',
      (tester) async {
    await tester.pumpWidget(MaterialApp(home: M23CheckoutReturnScreen(
      result: const M23BillingReturn(M23BillingReturnKind.success,_intent),
      repository: repository(verified:false),
    )));
    await tester.pumpAndSettle();
    expect(find.text('Payment Verification'), findsOneWidget);
    expect(find.textContaining('Payment is not confirmed yet'), findsOneWidget);
    expect(find.text('Subscription Verified'), findsNothing);
    expect(find.byKey(const Key('m23-return-verify-again')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('verified Stripe response displays subscription success',
      (tester) async {
    await tester.pumpWidget(MaterialApp(home: M23CheckoutReturnScreen(
      result: const M23BillingReturn(M23BillingReturnKind.success,_intent),
      repository: repository(verified:true),
    )));
    await tester.pumpAndSettle();
    expect(find.text('Subscription Verified'), findsOneWidget);
    expect(find.textContaining('Subscription verified'), findsOneWidget);
    expect(find.byKey(const Key('m23-return-verify-again')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('browser cancellation never calls the status endpoint',
      (tester) async {
    await tester.pumpWidget(MaterialApp(home: M23CheckoutReturnScreen(
      result: const M23BillingReturn(M23BillingReturnKind.cancel,_intent),
      repository: repository(verified:false),
    )));
    await tester.pumpAndSettle();
    expect(find.text('Checkout Canceled'), findsOneWidget);
    expect(find.textContaining('No payment has been confirmed'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
