import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/core/widgets/sign2digital_bottom_navigation_bar.dart';
import 'package:sign2digital/core/widgets/sign2digital_dashboard_header.dart';
import 'package:sign2digital/features/clients/presentation/screens/clients_screen.dart';
import 'package:sign2digital/features/documents/presentation/screens/documents_screen.dart';
import 'package:sign2digital/features/quotes/data/quote_ui_demo_data.dart';
import 'package:sign2digital/features/quotes/presentation/screens/add_signature_screen.dart';
import 'package:sign2digital/features/quotes/presentation/screens/document_signed_success_screen.dart';
import 'package:sign2digital/features/quotes/presentation/screens/in_person_signature_screen.dart';
import 'package:sign2digital/features/quotes/presentation/screens/quote_preview_screen.dart';

void main() {
  const viewports = [
    Size(320, 650),   // small phone portrait
    Size(375, 667),   // standard phone
    Size(430, 932),   // Figma reference width
    Size(720, 390),   // phone landscape
    Size(1024, 768),  // tablet landscape
  ];

  void setViewport(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
  }

  testWidgets('full dashboard Documents fits every supported viewport',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final size in viewports) {
      setViewport(tester, size);
      // Each viewport starts at the top with fresh dashboard scroll state.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(const MaterialApp(home: ClientsScreen()));
      await tester.tap(find.byKey(const Key('dashboard-tab-3')));
      await tester.pumpAndSettle();
      expect(find.byType(Sign2DigitalDashboardHeader), findsOneWidget);
      expect(find.byType(DocumentsScreen), findsOneWidget);
      final nav = find.byType(Sign2DigitalBottomNavigationBar);
      expect(tester.widget<Sign2DigitalBottomNavigationBar>(nav).selectedIndex, 3);
      final scroll = find.byKey(const Key('documents-scroll'));
      expect(scroll, findsOneWidget);
      expect(tester.getBottomRight(scroll).dy,
          lessThanOrEqualTo(tester.getTopLeft(nav).dy + 1));
      expect(tester.getSize(scroll).width, lessThanOrEqualTo(720));
      // The rightmost category must be reachable on narrow phones.
      await tester.ensureVisible(find.byKey(const Key('details-tab-4')));
      await tester.pump();
      // Scroll to the fifth real record and keep it above fixed navigation.
      await tester.scrollUntilVisible(
        find.byKey(const Key('document-card-documents-figma-quote-5')),
        160,
        scrollable: find.descendant(
          of: scroll,
          matching: find.byType(Scrollable),
        ).first,
      );
      await tester.ensureVisible(
        find.byKey(const Key('document-card-documents-figma-quote-5')),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getBottomRight(
          find.byKey(const Key('document-card-documents-figma-quote-5')),
        ).dy,
        lessThanOrEqualTo(tester.getTopLeft(nav).dy + 1),
      );
      expect(tester.takeException(), isNull, reason: '$size');
    }
  });

  testWidgets('signature capture, quote preview and success remain scrollable',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final quote = QuoteUiDemoData.quote();
    for (final size in viewports) {
      setViewport(tester, size);
      await tester.pumpWidget(MaterialApp(
        home: InPersonSignatureScreen(
          quote: quote.copy(),
          projectName: QuoteUiDemoData.projectName,
          documentId: 'viewport-document',
          customerSignerId: 'viewport-customer',
          businessSignerId: 'viewport-business',
        ),
      ));
      final canvas = find.byKey(const Key('in-person-signature-panel'));
      expect(tester.getSize(canvas).height, 258);
      await tester.ensureVisible(find.text('Confirm Signature'));
      await tester.pump();
      expect(tester.getBottomRight(find.text('Confirm Signature')).dy,
          lessThanOrEqualTo(size.height));
      expect(tester.takeException(), isNull, reason: 'in-person $size');

      await tester.pumpWidget(MaterialApp(home: AddSignatureScreen(
        quoteId: quote.id,
        documentId: 'viewport-document',
        requestId: 'viewport-request',
        signerId: 'viewport-signer',
        documentVersion: 'v1',
        consentReference: 'viewport-terms',
        termsText: quote.terms,
      )));
      await tester.ensureVisible(find.text('Confirm Signature'));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'add-signature $size');

      await tester.pumpWidget(MaterialApp(
        home: QuotePreviewScreen(quote: quote.copy()),
      ));
      await tester.ensureVisible(find.byKey(const Key('quote-preview-download')));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'quote-preview $size');

      await tester.pumpWidget(MaterialApp(
        home: DocumentSignedSuccessScreen(
          data: QuoteSignedDisplayData(
            documentId: 'fixture-only',
            quoteNumber: quote.quoteNumber,
            projectName: QuoteUiDemoData.projectName,
            signerName: quote.clientName,
            signedAt: DateTime(2026, 8, 23, 22),
            demoOnly: true,
          ),
        ),
      ));
      await tester.ensureVisible(find.text('Close'));
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull, reason: 'signed-success $size');
    }
  });
}
