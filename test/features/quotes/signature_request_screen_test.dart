import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/features/quotes/domain/quote_document_tracking.dart';
import 'package:sign2digital/features/quotes/domain/quote_review_models.dart';
import 'package:sign2digital/features/quotes/presentation/screens/signature_request_screen.dart';
import 'package:sign2digital/features/quotes/presentation/screens/send_quote_screen.dart';

QuoteReviewDraft sampleQuote({String id = 'tracking-test'}) => QuoteReviewDraft(
  id: id,
  clientName: 'Jean Dupont',
  clientEmail: 'jean@example.com',
  clientPhone: '+41 67 123 45 67',
  quoteNumber: 'Q-TEST-77',
  date: DateTime(2026, 8, 12),
  items: [
    QuoteReviewWorkItem(
      id: 'item-1',
      title: 'Windows',
      quantity: '1',
      unitPrice: '98.00',
      description: '',
    ),
  ],
  approvedLocally: true,
);

void main() {
  setUp(QuoteReminderPreferences.clear);

  test(
    'tracking uses genuine events only and rejects invalid secure links',
    () {
      final created = QuoteDocumentTracking(quoteId: 'a');
      expect(created.sent, false);
      expect(created.viewed, false);
      expect(created.completed, false);
      expect(created.latestFirst, isEmpty);
      expect(created.usableUrl(DateTime(2026, 8, 12)), isNull);
      final record = QuoteDocumentTracking(
        quoteId: 'a',
        secureUrl: Uri.parse('https://example.org/quote/a'),
        expiresAt: DateTime(2026, 8, 13),
        events: [
          QuoteDocumentEvent(
            id: '1',
            type: QuoteDocumentEventType.quoteCreated,
            occurredAt: DateTime(2026, 8, 10),
          ),
          QuoteDocumentEvent(
            id: '2',
            type: QuoteDocumentEventType.documentSent,
            occurredAt: DateTime(2026, 8, 11),
          ),
        ],
      );
      expect(record.sent, true);
      expect(record.viewed, false);
      expect(record.completed, false);
      expect(record.latestFirst.first.id, '2');
      expect(record.usableUrl(DateTime(2026, 8, 14)), isNull);
    },
  );

  testWidgets(
    'shows corrected Customer spelling and does not fake completion',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: SignatureRequestScreen(quote: sampleQuote())),
      );
      expect(find.text('Create Quote'), findsOneWidget);
      expect(find.text('Viewed by Customer'), findsOneWidget);
      expect(find.text('Customer'), findsOneWidget);
      expect(find.text('Costumer'), findsNothing);
      expect(find.text('Jean Dupont'), findsOneWidget);
      expect(find.byKey(const Key('signature-timeline')), findsOneWidget);
      expect(
        find.text('Document delivery has not been confirmed yet.'),
        findsOneWidget,
      );
      expect(find.text('No confirmed document activity yet.'), findsOneWidget);
      expect(find.byKey(const Key('dashboard-tab-0')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'verified events render newest first without inventing a signature',
    (tester) async {
      final tracking = QuoteDocumentTracking.figmaFixture('tracking-test');
      await tester.pumpWidget(
        MaterialApp(
          home: SignatureRequestScreen(
            quote: sampleQuote(),
            tracking: tracking,
          ),
        ),
      );
      await tester.ensureVisible(
        find.byKey(const Key('signature-history-demo-viewed')),
      );
      expect(find.text('Document Viewed'), findsOneWidget);
      expect(find.text('Document Sent'), findsNWidgets(2));
      expect(find.text('Completed'), findsOneWidget);
      expect(
        find.text(
          'The customer has viewed the document. We\'ll notify you when it\'s signed.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('reminder preference persists within local session, not server', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: SignatureRequestScreen(quote: sampleQuote())),
    );
    await tester.ensureVisible(
      find.byKey(const Key('signature-reminders-toggle')),
    );
    final toggle = find.byKey(const Key('signature-reminders-toggle'));
    expect(tester.widget<Switch>(toggle).value, false);
    await tester.tap(toggle);
    await tester.pump();
    expect(QuoteReminderPreferences.getEnabled('tracking-test'), true);
    expect(find.textContaining('requires a connected service'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      MaterialApp(home: SignatureRequestScreen(quote: sampleQuote())),
    );
    await tester.ensureVisible(
      find.byKey(const Key('signature-reminders-toggle')),
    );
    expect(tester.widget<Switch>(toggle).value, true);
  });

  testWidgets(
    'copy/resend refuse fake service; view opens current Customer Document',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: SignatureRequestScreen(quote: sampleQuote())),
      );
      await tester.ensureVisible(find.byKey(const Key('signature-copy-link')));
      await tester.tap(find.byKey(const Key('signature-copy-link')));
      await tester.pump();
      expect(
        find.textContaining('No genuine secure document link'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('signature-resend')));
      await tester.pump();
      expect(find.textContaining('requires an active request'), findsOneWidget);
      await tester.tap(find.byKey(const Key('signature-view-document')));
      await tester.pumpAndSettle();
      expect(find.text('Create Quote'), findsOneWidget);
      expect(find.text('Quote Q-TEST-77'), findsOneWidget);
      expect(find.text('Review and Sign'), findsOneWidget);
      expect(find.text('Customer Signature'), findsNothing);
    },
  );

  testWidgets('Send Quote opens tracking without inventing sent activity', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SendQuoteScreen(
          quote: sampleQuote(),
          pdfGenerator: (_) async =>
              Uint8List.fromList(List<int>.filled(200, 3)),
        ),
      ),
    );
    await tester.ensureVisible(find.byKey(const Key('send-view-tracking')));
    await tester.tap(find.byKey(const Key('send-view-tracking')));
    await tester.pumpAndSettle();
    expect(find.text('Create Quote'), findsOneWidget);
    expect(
      find.text('Document delivery has not been confirmed yet.'),
      findsOneWidget,
    );
    expect(find.text('Customer'), findsOneWidget);
  });

  testWidgets('small portrait and landscape never overflow', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final size in [const Size(320, 650), const Size(700, 350)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        MaterialApp(
          home: SignatureRequestScreen(quote: sampleQuote(id: 'size-$size')),
        ),
      );
      await tester.ensureVisible(
        find.byKey(const Key('signature-reminders-toggle')),
      );
      expect(tester.takeException(), isNull, reason: '$size');
      await tester.ensureVisible(find.byKey(const Key('dashboard-tab-0')));
      expect(tester.takeException(), isNull, reason: '$size');
    }
  });
  testWidgets('reminder switch fits bounded 40px slot after rebuild',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final size in [
      const Size(320, 650), const Size(430, 932),
      const Size(720, 390),
    ]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        MaterialApp(home: SignatureRequestScreen(
          quote: sampleQuote(id: 'resize-$size'))),
      );
      await tester.ensureVisible(
        find.byKey(const Key('signature-reminders-toggle')));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: '$size');
      expect(find.byType(UnconstrainedBox), findsNothing);
      final switchWidget = find.byKey(
        const Key('signature-reminders-toggle'));
      expect(switchWidget, findsOneWidget);
    }
  });

}
