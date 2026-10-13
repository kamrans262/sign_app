import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/features/quotes/domain/quote_review_models.dart';
import 'package:sign2digital/features/quotes/presentation/screens/send_quote_screen.dart';
import 'package:sign2digital/features/quotes/presentation/screens/quote_preview_screen.dart';

QuoteReviewDraft readyQuote({String id = 'send-test'}) {
  final quote = QuoteReviewDraft(
    id: id,
    clientName: 'Example Customer',
    clientEmail: 'example@domain.test',
    clientPhone: '+41 79 555 10 10',
    billingAddress: 'Example Street 14',
    date: DateTime(2026, 10, 12),
    quoteNumber: 'Q-TEST-010',
    items: [QuoteReviewWorkItem(id: '1', title: 'Windows',
      description: 'Installation', quantity: '2', unitPrice: '98.00')],
    terms: 'Example terms', approvedLocally: true,
  );
  return quote;
}

Future<Uint8List> fakePdf(QuoteReviewDraft quote) async =>
    Uint8List.fromList(List<int>.filled(1500, 21));

/// Reach and tap real controls even when the screen is scrolled or the
/// keyboard was opened by an earlier field interaction.
Future<void> tapOnScreen(WidgetTester tester, Finder target) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump();
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  setUp(QuoteSendSessionStore.clear);

  testWidgets('email selected by default and switching methods keeps message',
      (tester) async {
    await tester.pumpWidget(MaterialApp(home: SendQuoteScreen(
      quote: readyQuote(), pdfGenerator: fakePdf,
    )));
    await tester.pump();
    expect(find.text('Send Quote'), findsOneWidget);
    expect(find.text('E-mail'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('send-message-input')),
      'Please review this updated quote.');
    await tapOnScreen(tester, find.byKey(const Key('send-method-other')));
    final input = tester.widget<TextField>(find.byKey(const Key('send-message-input')));
    expect(input.controller!.text, 'Please review this updated quote.');
    await tapOnScreen(tester, find.byKey(const Key('send-method-link')));
    expect(tester.takeException(), isNull);
  });

  testWidgets('recipient overrides are editable without editing original quote',
      (tester) async {
    final quote = readyQuote();
    await tester.pumpWidget(MaterialApp(home: SendQuoteScreen(
      quote: quote, pdfGenerator: fakePdf,
    )));
    await tester.pump();
    await tapOnScreen(tester, find.text('Edit'));
    await tester.enterText(find.byWidgetPredicate((w) => w is TextField && w.decoration?.labelText == 'Email'), 'changed@domain.test');
    await tapOnScreen(tester, find.text('Save'));
    expect(find.text('changed@domain.test'), findsOneWidget);
    expect(quote.clientEmail, 'example@domain.test');
    expect(tester.takeException(), isNull);
  });

  testWidgets('invalid recipient email stays in the edit dialog',
      (tester) async {
    await tester.pumpWidget(MaterialApp(home: SendQuoteScreen(
      quote: readyQuote(id: 'invalid-recipient'), pdfGenerator: fakePdf,
    )));
    await tester.pump();
    await tapOnScreen(tester, find.text('Edit'));
    await tester.enterText(
      find.byWidgetPredicate(
        (widget) => widget is TextField &&
            widget.decoration?.labelText == 'Email',
      ),
      'invalid-address',
    );
    await tapOnScreen(tester, find.text('Save'));
    expect(find.text('Enter a valid email address'), findsOneWidget);
    expect(find.text('Edit Recipient'), findsOneWidget);
    await tapOnScreen(tester, find.text('Cancel'));
    expect(find.text('example@domain.test'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('PDF attachment can be removed and restored', (tester) async {
    await tester.pumpWidget(MaterialApp(home: SendQuoteScreen(
      quote: readyQuote(), pdfGenerator: fakePdf,
    )));
    await tester.pump();
    await tapOnScreen(tester, find.byKey(const Key('send-remove-attachment')));
    expect(find.byKey(const Key('send-restore-attachment')), findsOneWidget);
    await tapOnScreen(tester, find.byKey(const Key('send-restore-attachment')));
    expect(find.byKey(const Key('send-remove-attachment')), findsOneWidget);
  });

  testWidgets('no real secure link cannot be copied or sent', (tester) async {
    await tester.pumpWidget(MaterialApp(home: SendQuoteScreen(
      quote: readyQuote(), pdfGenerator: fakePdf,
    )));
    await tester.pump();
    await tapOnScreen(tester, find.byKey(const Key('send-method-link')));
    await tapOnScreen(tester, find.byKey(const Key('send-quote-submit')));
    expect(find.textContaining('requires a real connected service'), findsOneWidget);
    final copy = tester.widget<IconButton>(find.byKey(const Key('send-copy-link')));
    expect(copy.onPressed, isNull);
  });

  testWidgets('back and reopen retain edited message', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Builder(
      builder: (ctx) => ElevatedButton(onPressed: () {
        Navigator.of(ctx).push<void>(MaterialPageRoute(
          builder: (_) => SendQuoteScreen(quote: readyQuote(),
            pdfGenerator: fakePdf)));
      }, child: const Text('Open')),
    )));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('send-message-input')), 'My saved message');
    await tapOnScreen(tester, find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byKey(const Key('send-message-input')))
      .controller!.text, 'My saved message');
  });

  testWidgets('narrow landscape and portrait are scrollable without overflow',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final size in [const Size(320, 660), const Size(720, 370)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(MaterialApp(home: SendQuoteScreen(
        quote: readyQuote(id: 'viewport-$size'), pdfGenerator: fakePdf,
      )));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('send-quote-submit')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$size');
    }
  });

  testWidgets('validated Quote Preview opens Send Quote', (tester) async {
    final quote = readyQuote();
    await tester.pumpWidget(MaterialApp(home: QuotePreviewScreen(quote: quote)));
    await tester.ensureVisible(find.byKey(const Key('quote-preview-share')));
    await tester.tap(find.byKey(const Key('quote-preview-share')));
    await tester.pumpAndSettle();
    expect(find.text('Send Quote'), findsOneWidget);
    expect(find.textContaining('Q-TEST-010'), findsOneWidget);
  });
}
