import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/core/widgets/sign2digital_info_banner.dart';
import 'package:sign2digital/features/quotes/data/quote_ui_demo_data.dart';
import 'package:sign2digital/features/quotes/domain/quote_signature_draft.dart';
import 'package:sign2digital/features/quotes/presentation/screens/document_signed_success_screen.dart';
import 'package:sign2digital/features/quotes/presentation/screens/in_person_signature_screen.dart';
import 'package:sign2digital/features/quotes/presentation/screens/quote_ui_demo_screen.dart';
import 'package:sign2digital/features/quotes/presentation/widgets/sign2digital_quote_summary_card.dart';

void main() {
  setUp(QuoteSignatureDraftSession.clearAll);

  Widget screen({
    Future<QuoteSignedDisplayData?> Function(QuoteInPersonSignatureSubmission)?
        onSubmit,
  }) => MaterialApp(
    home: InPersonSignatureScreen(
      quote: QuoteUiDemoData.quote(),
      projectName: QuoteUiDemoData.projectName,
      documentId: 'demo-document',
      customerSignerId: 'demo-customer',
      businessSignerId: 'demo-business',
      onSubmit: onSubmit,
    ),
  );

  Future<void> draw(WidgetTester tester) async {
    final canvas = find.byKey(const Key('in-person-draw-canvas'));
    await tester.ensureVisible(canvas);
    await tester.timedDrag(
      canvas, const Offset(105, 40), const Duration(milliseconds: 160),
    );
    await tester.pump();
  }

  testWidgets('Figma structure reuses card, tabs, info box and 258px canvas',
      (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(screen());
    expect(find.text('In-Person Signature'), findsOneWidget);
    expect(find.text('Quote # Q-2900'), findsOneWidget);
    expect(find.text('Kitchen Renovation'), findsOneWidget);
    expect(find.text('Costumer Signature'), findsOneWidget);
    expect(find.text('Your Signature'), findsOneWidget);
    expect(
      tester.widget<Sign2DigitalQuoteSummaryCard>(
        find.byType(Sign2DigitalQuoteSummaryCard),
      ).subtitleGap,
      3,
    );
    expect(
      tester.widget<Sign2DigitalInfoBanner>(
        find.byType(Sign2DigitalInfoBanner),
      ).verticalPadding,
      10,
    );
    expect(
      tester.getSize(find.byKey(const Key('in-person-signature-panel'))).height,
      258,
    );
    await tester.ensureVisible(find.text('Confirm Signature'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty canvas is refused; changing tabs keeps independent strokes',
      (tester) async {
    QuoteInPersonSignatureSubmission? received;
    await tester.pumpWidget(screen(onSubmit: (draft) async {
      received = draft;
      return null;
    }));
    final button = find.text('Confirm Signature');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('Please draw a signature'), findsOneWidget);
    await draw(tester);
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Please add the other required signature.'), findsOneWidget);
    expect(find.text('Document Signed!'), findsNothing);
    await draw(tester);

    // Clear only the business strokes, not the customer strokes.
    await tester.ensureVisible(find.text('Clear'));
    await tester.tap(find.text('Clear'));
    await tester.pump();
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('Please draw a signature'), findsOneWidget);
    await draw(tester);
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Confirm agreement'), findsOneWidget);
    await tester.tap(find.byKey(const Key('signature-consent-checkbox')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('signature-consent-continue')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(received, isNotNull);
    expect(received!.quoteId, 'ui-demo-kitchen-renovation');
    expect(received!.documentId, 'demo-document');
    expect(received!.customerSignerId, 'demo-customer');
    expect(received!.businessSignerId, 'demo-business');
    expect(received!.customerStrokes, isNotEmpty);
    expect(received!.businessStrokes, isNotEmpty);
    expect(received!.consentAccepted, isTrue);
    expect(find.text('Document Signed!'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('only confirmed demo callback opens clearly labelled success',
      (tester) async {
    await tester.pumpWidget(screen(onSubmit: (draft) async {
      return QuoteSignedDisplayData(
        documentId: draft.documentId,
        quoteNumber: 'Q-2900',
        projectName: 'Kitchen Renovation',
        signerName: 'Jean Dupont',
        signedAt: DateTime(2026, 8, 23, 22),
        demoOnly: true,
      );
    }));
    await draw(tester);
    await tester.ensureVisible(find.byKey(const Key('in-person-tab-business')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('in-person-tab-business')));
    await tester.pump();
    await draw(tester);
    await tester.ensureVisible(find.text('Confirm Signature'));
    await tester.tap(find.text('Confirm Signature'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Confirm agreement'), findsOneWidget);
    await tester.tap(find.byKey(const Key('signature-consent-checkbox')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('signature-consent-continue')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Document Signed!'), findsOneWidget);
    expect(find.byKey(const Key('signed-success-demo-notice')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('In-Person Signature is linked from demo Quote Preview',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: QuoteUiDemoScreen()),
    );
    await tester.ensureVisible(find.byKey(const Key('quote-demo-step-3')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('quote-demo-step-3')));
    await tester.pumpAndSettle();
    final link = find.byKey(const Key('quote-preview-in-person-sign'));
    await tester.ensureVisible(link);
    await tester.tap(link);
    await tester.pumpAndSettle();
    expect(find.text('In-Person Signature'), findsOneWidget);
    expect(find.byKey(const Key('in-person-draw-canvas')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('small portrait and landscape keep confirmation reachable',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final size in [const Size(320, 650), const Size(720, 390)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(screen());
      await tester.ensureVisible(find.text('Confirm Signature'));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: '$size');
    }
  });
}
