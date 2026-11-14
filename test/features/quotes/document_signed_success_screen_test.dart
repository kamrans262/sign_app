import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/features/quotes/data/quote_ui_demo_data.dart';
import 'package:sign2digital/features/quotes/presentation/screens/document_signed_success_screen.dart';
import 'package:sign2digital/features/quotes/presentation/screens/quote_ui_demo_screen.dart';

void main() {
  test('demo quote is complete and clearly marked fictional', () {
    final quote = QuoteUiDemoData.quote();
    expect(quote.isDemo, isTrue);
    expect(quote.quoteNumber, 'Q-2900');
    expect(quote.approvalIssues, isEmpty);
    expect(quote.approvedLocally, isTrue);
  });

  testWidgets('success screen shows demo details and protects signed PDF',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: DocumentSignedSuccessScreen(
        data: QuoteSignedDisplayData(
          documentId: 'demo-only',
          quoteNumber: 'Q-2900',
          projectName: 'Kitchen Renovation',
          signerName: 'Jean Dupont',
          signedAt: DateTime(2026, 8, 23, 22),
          demoOnly: true,
        ),
      ),
    ));
    expect(find.text('Document Signed!'), findsOneWidget);
    expect(find.text('Quote # Q-2900'), findsOneWidget);
    expect(find.byKey(const Key('signed-success-demo-notice')), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(find.byKey(const Key('signed-success-animation')), findsOneWidget);
    final button = find.text('View Signed Document');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
    expect(find.textContaining('no real signed PDF exists'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
  });

  testWidgets('business confirmation reuses success UI and Close returns Home',
      (tester) async {
    var previews=0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: Builder(builder: (context) => Center(
        child: TextButton(
          onPressed: () => Navigator.of(context).push<void>(
            MaterialPageRoute<void>(builder: (_) =>
                DocumentSignedSuccessScreen(
              businessSignaturePending:true,
              data:QuoteSignedDisplayData(
                documentId:'verified-request-3',
                quoteNumber:'Q-12',
                projectName:'Job #9',
                signerName:'Business Owner',
                signedAt:DateTime.utc(2026,11,15,9),
              ),
              onPreviewQuote: (_) async {previews++;},
            )),
          ),
          child:const Text('Open signing result'),
        ),
      )),
    )));
    await tester.tap(find.text('Open signing result'));
    await tester.pumpAndSettle();
    expect(find.text('Business Signature Added!'),findsOneWidget);
    expect(find.text('Document Signed!'),findsNothing);
    expect(find.text('Business Signed By:'),findsOneWidget);
    expect(find.text('Your signature has been saved. '
        'The customer signature is still pending.'),findsOneWidget);
    await tester.ensureVisible(find.text('Preview Quote'));
    await tester.tap(find.text('Preview Quote'));
    expect(previews,1);
    await tester.ensureVisible(find.text('Close'));
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Open signing result'),findsOneWidget);
    expect(find.text('Business Signature Added!'),findsNothing);
  });

  testWidgets('manual quote tour exposes the quote flow', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: QuoteUiDemoScreen()));
    expect(find.text('Northstar Renovations GmbH'), findsOneWidget);
    expect(find.byKey(const Key('quote-demo-step-0')), findsOneWidget);
    expect(find.text('Review Quote'), findsOneWidget);
  });
}
