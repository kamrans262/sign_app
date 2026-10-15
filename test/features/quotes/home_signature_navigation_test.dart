import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/features/clients/presentation/screens/clients_screen.dart';
import 'package:sign2digital/features/quotes/domain/quote_review_models.dart';
import 'package:sign2digital/features/quotes/domain/quote_tracking_home_session.dart';
import 'package:sign2digital/features/quotes/presentation/screens/send_quote_screen.dart';

QuoteReviewDraft _quote() => QuoteReviewDraft(
  id: 'home-signature-quote',
  clientName: 'Jean Dupont',
  clientEmail: 'jean@example.com',
  quoteNumber: 'Q-HOME-1',
  items: [
    QuoteReviewWorkItem(
      id: 'item-1',
      title: 'Windows',
      description: 'Installation',
      quantity: '1',
      unitPrice: '98.00',
    ),
  ],
  approvedLocally: true,
  date: null,
);

void main() {
  setUp(QuoteTrackingHomeSession.clear);
  tearDown(QuoteTrackingHomeSession.clear);

  testWidgets('Home has no invented signature request before opening a quote', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ClientsScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('dashboard-tab-0')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home-dashboard-scroll')), findsOneWidget);
    expect(find.byKey(const Key('home-preview-notice')), findsOneWidget);
    expect(find.text('Signature Requests'), findsNothing);
    expect(find.text('Document Sent'), findsNothing);
    await tester.tap(find.byKey(const Key('home-stat-clients')));
    await tester.pumpAndSettle();
    expect(find.text('Clients'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Home displays selected quote tracking; tabs still navigate', (
    tester,
  ) async {
    QuoteTrackingHomeSession.remember(_quote());
    await tester.pumpWidget(const MaterialApp(home: ClientsScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('dashboard-tab-0')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home-dashboard-scroll')), findsOneWidget);
    final trackingLink = find.byKey(
      const Key('home-open-signature-tracking'),
    );
    await tester.scrollUntilVisible(
      trackingLink,
      150,
      scrollable: find.descendant(
        of: find.byKey(const Key('home-dashboard-scroll')),
        matching: find.byType(Scrollable),
      ).first,
    );
    await tester.ensureVisible(trackingLink);
    await tester.pumpAndSettle();
    await tester.tap(trackingLink);
    await tester.pumpAndSettle();
    expect(find.text('Viewed by Customer'), findsOneWidget);
    expect(find.text('Jean Dupont'), findsOneWidget);
    expect(
      find.text('Document delivery has not been confirmed yet.'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('dashboard-tab-1')));
    await tester.pumpAndSettle();
    expect(find.text('Active (12)'), findsOneWidget);
    await tester.tap(find.byKey(const Key('dashboard-tab-0')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home-dashboard-scroll')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opening Send Quote remembers its exact quote for Home', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SendQuoteScreen(
          quote: _quote(),
          pdfGenerator: (_) async => Uint8List.fromList([37, 80, 68, 70]),
        ),
      ),
    );
    await tester.pump();
    final remembered = QuoteTrackingHomeSession.currentQuote;
    expect(remembered, isNotNull);
    expect(remembered!.id, 'home-signature-quote');
    expect(remembered.quoteNumber, 'Q-HOME-1');
    expect(tester.takeException(), isNull);
  });
}
