import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/core/services/sign_api_client.dart';
import 'package:sign2digital/core/widgets/sign2digital_subscription_gate.dart';

void main() {
  testWidgets('Only a verified 402 offers an upgrade, without charging',
      (tester) async {
    bool? handled;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Builder(builder: (context) => TextButton(
        onPressed: () async {
          handled = await Sign2DigitalSubscriptionGate.handle(
              context, const SignApiException('Limit reached',
                  statusCode: 402));
        },
        child: const Text('Issue a document'),
      ))),
    ));
    await tester.tap(find.text('Issue a document'));
    await tester.pumpAndSettle();
    expect(find.text('Subscription Required'), findsOneWidget);
    expect(find.byKey(const Key('subscription-required-view-plans')),
        findsOneWidget);
    expect(find.byKey(const Key('subscription-required-later')),
        findsOneWidget);
    await tester.tap(find.byKey(const Key('subscription-required-later')));
    await tester.pumpAndSettle();
    expect(handled, isTrue);
    expect(find.text('Subscription Required'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Ordinary errors are not represented as subscription limits',
      (tester) async {
    bool? handled;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Builder(builder: (context) => TextButton(
        onPressed: () async {
          handled = await Sign2DigitalSubscriptionGate.handle(
              context, const SignApiException('Network offline',
                  statusCode: 503));
        },
        child: const Text('Try Action'),
      ))),
    ));
    await tester.tap(find.text('Try Action'));
    await tester.pumpAndSettle();
    expect(handled, isFalse);
    expect(find.text('Subscription Required'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
