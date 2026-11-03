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
  date: DateTime(2026, 8, 23),
);

// Dashboard has intentional continually active animations/async widgets.
// Bounded frames test stable navigation without waiting for all animation
// futures to quiesce, which pumpAndSettle cannot guarantee.
Future<void> _pumpUi(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 320));
}

void main() {
  setUp(QuoteTrackingHomeSession.clear);
  tearDown(QuoteTrackingHomeSession.clear);

  testWidgets('Home has no invented signature request before opening a quote', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ClientsScreen()));
    await _pumpUi(tester);
    await tester.tap(find.byKey(const Key('dashboard-tab-0')).last);
    await _pumpUi(tester);
    expect(find.byKey(const Key('home-dashboard-scroll')), findsOneWidget);
    expect(find.byKey(const Key('home-demo-disclaimer')), findsNothing);
    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('Document Sent'), findsNothing);
    expect(find.byKey(const Key('home-open-signature-tracking')), findsNothing);
    await tester.ensureVisible(
      find.byKey(const Key('home-card-documents')));
    await _pumpUi(tester);
    await tester.tap(find.byKey(const Key('home-card-documents')));
    await _pumpUi(tester);
    expect(find.byKey(const Key('documents-scroll')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Home displays selected quote tracking; tabs still navigate', (
    tester,
  ) async {
    QuoteTrackingHomeSession.remember(_quote());
    await tester.pumpWidget(const MaterialApp(home: ClientsScreen()));
    await _pumpUi(tester);
    await tester.tap(find.byKey(const Key('dashboard-tab-0')).last);
    await _pumpUi(tester);
    expect(find.byKey(const Key('home-dashboard-scroll')), findsOneWidget);
    final track = find.byKey(const Key('home-open-signature-tracking'));
    await tester.scrollUntilVisible(
      track, 140,
      scrollable: find.descendant(
        of: find.byKey(const Key('home-dashboard-scroll')),
        matching: find.byType(Scrollable),
      ).first,
      maxScrolls: 20,
    );
    await _pumpUi(tester);
    await tester.tap(track);
    await _pumpUi(tester);
    expect(find.text('Viewed by Customer'), findsOneWidget);
    expect(find.text('Jean Dupont'), findsOneWidget);
    expect(
      find.text('Document delivery has not been confirmed yet.'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('dashboard-tab-1')).last);
    await _pumpUi(tester);
    expect(find.text('Active (12)'), findsOneWidget);
    await tester.tap(find.byKey(const Key('dashboard-tab-0')).last);
    await _pumpUi(tester);
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
