import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/features/quotes/domain/quote_review_models.dart';
import 'package:sign2digital/features/quotes/presentation/screens/quote_preview_screen.dart';

void main() {
  test('Swiss payment QR is hidden when bank data is missing or invalid', () {
    final draft = QuoteReviewDraft.figmaDemo();
    expect(draft.payment, isNull);
    final partial = QuotePaymentDetails(iban: 'CH0000', accountHolder: 'Test');
    expect(partial.swissQrBillPayload(currency: 'CHF', amountMinor: 9800), isNull);
  });

  test('valid Swiss QR bill fields generate encoded real payment data', () {
    final details = QuotePaymentDetails(
      iban: 'CH9300762011623852957', accountHolder: 'Sample Company',
      street: 'Musterstrasse', buildingNumber: '1',
      postalCode: '8000', city: 'Zurich', country: 'CH',
    );
    final result = details.swissQrBillPayload(currency: 'CHF', amountMinor: 9800);
    expect(result, isNotNull);
    expect(result, startsWith('SPC\n0200\n1\nCH9300762011623852957\n'));
    expect(result, contains('\n98.00\nCHF\n'));
    expect(result, contains('\nNON\n'));
  });

  test('quote snapshots preserve client, totals and terms unchanged', () {
    final draft = QuoteReviewDraft.figmaDemo();
    draft.billingAddress = 'Example Road 12';
    draft.clientEmail = 'example@test.invalid';
    draft.terms = 'Sample terms';
    draft.items.last.unitPrice = '100.00';
    final copy = draft.copy();
    expect(copy.billingAddress, 'Example Road 12');
    expect(copy.terms, 'Sample terms');
    expect(copy.totalMinor, draft.totalMinor);
    copy.items.first.unitPrice = '1.00';
    expect(copy.totalMinor, isNot(draft.totalMinor));
  });

  testWidgets('preview renders draft data and actions at 430 logical px',
      (tester) async {
    tester.view.physicalSize = const Size(430, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final draft = QuoteReviewDraft.figmaDemo();
    draft.terms = 'Sample terms';
    await tester.pumpWidget(MaterialApp(home: QuotePreviewScreen(quote: draft)));
    expect(find.text('Quote Preview'), findsOneWidget);
    expect(find.text('Q-2026-0043'), findsOneWidget);
    expect(find.textContaining('PVC Windows (Standard)'), findsOneWidget);
    expect(find.text('Pricing incomplete — missing values are not zero.'),
        findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('quote-preview-download')));
    expect(find.byKey(const Key('quote-preview-share')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('approved quote preview has only Download and Send to Customer actions',
      (tester) async {
    final quote = QuoteReviewDraft(
      id: 'server-quote-7',
      serverId: 7,
      clientName: 'QA Customer',
      clientEmail: 'qa@example.test',
      quoteNumber: 'Q-QA-7',
      date: DateTime(2026, 11, 12),
      terms: 'Approved terms',
      approvedLocally: true,
      items: [
        QuoteReviewWorkItem(
          id: 'line-1', title: 'Bathroom repair',
          description: 'Repair fixtures', quantity: '1', unitPrice: '1493.00',
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp(home: QuotePreviewScreen(quote: quote)));
    await tester.ensureVisible(find.byKey(const Key('quote-preview-share')));
    expect(find.byKey(const Key('quote-preview-request-signature')), findsNothing);
    expect(find.byKey(const Key('quote-preview-in-person-sign')), findsNothing);
    expect(find.text('Request Signature'), findsNothing);
    expect(find.text('In-Person Signature'), findsNothing);
    expect(find.text('Send to Customer'), findsOneWidget);
    expect(find.byKey(const Key('quote-preview-share')), findsOneWidget);
    expect(find.byKey(const Key('quote-preview-download')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('M7 mobile quote preview includes deposit, balance and all reviewed fields',
      (tester) async {
    tester.view.physicalSize = const Size(416, 940);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final quote = QuoteReviewDraft(
      id: 'm7-parity', clientName: 'Flutter Db',
      quoteNumber: 'M6-TEST-003',
      date: DateTime(2026, 11, 3),
      validUntil: DateTime(2026, 11, 28),
      currency: 'CHF', vatBasisPoints: 2000,
      depositBasisPoints: 3000,
      terms: 'Verified terms',
      items: [
        QuoteReviewWorkItem(id: 'bricks', title: 'Bricks',
          description: 'Exterior repair',
          dimensions: '3 m x 4 m',
          quantity: '4', unitPrice: '150.00'),
      ],
    );
    await tester.pumpWidget(MaterialApp(home: QuotePreviewScreen(quote: quote)));
    expect(find.text('Deposit due (30%)'), findsOneWidget);
    expect(find.text('CHF 216.00'), findsOneWidget);
    expect(find.text('Remaining after deposit'), findsOneWidget);
    expect(find.text('CHF 504.00'), findsOneWidget);
    expect(find.textContaining('Exterior repair'), findsOneWidget);
    expect(find.textContaining('Dimensions: 3 m x 4 m'), findsOneWidget);
    expect(find.text('Payable amount'), findsOneWidget);
    expect(find.text('Currency'), findsOneWidget);
    // Unlike the previous fixed 76px labels, both dates start just after
    // their individual labels; maintain the web/PDF date layout separately.
    final dateLabel = find.text('Date:');
    final dateValue = find.text('3 November 2026');
    final validLabel = find.text('Valid Until:');
    final validValue = find.text('28 November 2026');
    final dateGap = tester.getTopLeft(dateValue).dx -
        tester.getTopRight(dateLabel).dx;
    final validGap = tester.getTopLeft(validValue).dx -
        tester.getTopRight(validLabel).dx;
    expect(dateGap, lessThanOrEqualTo(10));
    expect(validGap, lessThanOrEqualTo(10));
    expect(tester.takeException(), isNull);
  });

  testWidgets('M7 date block matches Quote right margin and both dates align',
      (tester) async {
    tester.view.physicalSize = const Size(430, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final quote = QuoteReviewDraft(
      id: 'aligned-dates', clientName: 'Flutter Db',
      quoteNumber: 'M6-TEST-003',
      date: DateTime(2026, 11, 3),
      validUntil: DateTime(2026, 11, 28),
      terms: 'Quote terms',
      items: [QuoteReviewWorkItem(
        id: 'bricks', title: 'Bricks', description: '',
        quantity: '4', unitPrice: '150.00')],
    );
    await tester.pumpWidget(MaterialApp(home: QuotePreviewScreen(quote: quote)));
    final block = find.byKey(const Key('quote-preview-date-block'));
    final quoteTitle = find.byKey(const Key('quote-preview-document-title'));
    final date = find.text('3 November 2026');
    final valid = find.text('28 November 2026');
    expect(block, findsOneWidget);
    expect((tester.getTopLeft(date).dx - tester.getTopLeft(valid).dx).abs(),
      lessThan(1));
    expect((tester.getTopRight(block).dx -
            tester.getTopRight(quoteTitle).dx).abs(), lessThan(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('landscape quote preview scrolls without Flex overflow',
      (tester) async {
    tester.view.physicalSize = const Size(720, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: QuotePreviewScreen(
      quote: QuoteReviewDraft.figmaDemo(),
    )));
    await tester.ensureVisible(find.byKey(const Key('quote-preview-share')));
    expect(tester.takeException(), isNull);
  });
}
