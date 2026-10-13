import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/features/quotes/domain/quote_document_tracking.dart';
import 'package:sign2digital/features/quotes/domain/quote_review_models.dart';
import 'package:sign2digital/features/quotes/presentation/screens/customer_document_view_screen.dart';
import 'package:sign2digital/features/quotes/presentation/screens/quote_preview_screen.dart';

QuoteReviewDraft _quote() => QuoteReviewDraft(
  id: 'customer-doc-17',
  quoteNumber: 'Q-17',
  clientName: 'Jean Dupont',
  clientEmail: 'jean@domain.test',
  billingAddress: '123 Business Road',
  clientPhone: '+41 123 456',
  currency: 'GBP',
  vatBasisPoints: 1000,
  date: DateTime(2026, 4, 24),
  validUntil: DateTime(2026, 5, 24),
  terms: '1. Scope of services\n2. Payment terms',
  items: [
    QuoteReviewWorkItem(
      id: 'work-1',
      title: 'Kitchen Demolition',
      quantity: '1',
      unitPrice: '98.00',
      description: '',
    ),
    QuoteReviewWorkItem(
      id: 'work-2',
      title: 'Kitchen Installation',
      quantity: '1',
      description: '',
    ),
  ],
  approvedLocally: true,
);

QuoteDocumentTracking _sentRequest() => QuoteDocumentTracking(
  quoteId: 'customer-doc-17',
  requestId: 'request-17',
  secureUrl: Uri.parse('https://documents.example.org/r/request-17'),
  expiresAt: DateTime.now().add(const Duration(days: 7)),
  events: [
    QuoteDocumentEvent(
      id: 'sent-17',
      type: QuoteDocumentEventType.documentSent,
      occurredAt: DateTime(2026, 10, 1),
    ),
  ],
);

void main() {
  testWidgets(
    'customer view reuses document without business controls or signature lines',
    (tester) async {
      tester.view.physicalSize = const Size(430, 960);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: CustomerDocumentViewScreen(
            quote: _quote(),
            tracking: _sentRequest(),
            description: 'Kitchen renovation, Muller AG',
          ),
        ),
      );
      expect(find.text('Create Quote'), findsOneWidget);
      expect(find.text('Quote Q-17'), findsOneWidget);
      expect(find.text('Sent for signature'), findsOneWidget);
      expect(find.text('Kitchen renovation, Muller AG'), findsOneWidget);
      expect(
        find.byKey(const Key('quote-preview-items-table')),
        findsOneWidget,
      );
      expect(find.text('Kitchen Installation'), findsOneWidget);
      expect(find.text('£98.00'), findsWidgets);
      expect(
        find.text('Pricing incomplete — missing values are not zero.'),
        findsOneWidget,
      );
      expect(find.text('General Terms & Conditions'), findsOneWidget);
      expect(find.text('Customer Signature'), findsNothing);
      expect(find.text('Download PDF'), findsNothing);
      expect(find.text('Send to Customer'), findsNothing);
      expect(find.text('Review and Sign'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'invoice title is configurable; business preview still says Quote',
    (tester) async {
      final quote = _quote();
      await tester.pumpWidget(
        MaterialApp(
          home: CustomerDocumentViewScreen(
            quote: quote,
            documentTitle: 'Invoice',
          ),
        ),
      );
      expect(find.text('Invoice'), findsOneWidget);
      expect(find.text('Not sent'), findsOneWidget);
      await tester.pumpWidget(
        MaterialApp(home: QuotePreviewScreen(quote: quote)),
      );
      expect(find.text('Quote Preview'), findsOneWidget);
      expect(find.text('Quote'), findsOneWidget);
      expect(find.text('Customer Signature'), findsOneWidget);
      expect(find.byKey(const Key('quote-preview-download')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Review and Sign requires real request and callback; does not fake signature',
    (tester) async {
      var called = 0;
      final quote = _quote();
      await tester.pumpWidget(
        MaterialApp(
          home: CustomerDocumentViewScreen(
            quote: quote,
            onReviewAndSign: (_) async {
              called++;
            },
          ),
        ),
      );
      final button = find.byKey(const Key('customer-document-review-sign'));
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pump();
      expect(called, 0);
      expect(
        find.textContaining('valid, active signature request'),
        findsOneWidget,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: CustomerDocumentViewScreen(
            quote: quote,
            tracking: _sentRequest(),
            onReviewAndSign: (draft) async {
              expect(draft.id, quote.id);
              expect(draft.quoteNumber, quote.quoteNumber);
              called++;
            },
          ),
        ),
      );
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pump();
      expect(called, 1);
      expect(_sentRequest().signed, false);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'customer document scrolls at narrow portrait and landscape sizes',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final size in [const Size(320, 650), const Size(720, 390)]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(
          MaterialApp(
            home: CustomerDocumentViewScreen(
              quote: _quote(),
              tracking: _sentRequest(),
            ),
          ),
        );
        await tester.ensureVisible(
          find.byKey(const Key('customer-document-review-sign')),
        );
        await tester.pump();
        expect(tester.takeException(), isNull, reason: '$size');
      }
    },
  );
}
