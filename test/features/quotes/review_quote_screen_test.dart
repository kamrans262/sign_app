import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/features/quotes/domain/quote_review_models.dart';
import 'package:sign2digital/features/quotes/domain/quote_extraction_models.dart';
import 'package:sign2digital/features/quotes/presentation/screens/review_quote_screen.dart';
import 'package:sign2digital/features/quotes/presentation/screens/quote_ai_processing_screen.dart';
import 'package:sign2digital/features/quotes/presentation/screens/quote_preview_screen.dart';
import 'package:sign2digital/features/quotes/presentation/widgets/sign2digital_quote_work_item_card.dart';

void main() {
  setUp(QuoteReviewSessionStore.clear);

  testWidgets('processing demo navigates to clearly labelled review demo', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: QuoteAiProcessingScreen(
      initialSnapshot: QuotePreparationSnapshot.figmaPreview,
    )));
    await tester.ensureVisible(find.byKey(const Key('quote-demo-review')));
    await tester.tap(find.byKey(const Key('quote-demo-review')));
    await tester.pumpAndSettle();
    expect(find.byType(ReviewQuoteScreen), findsOneWidget);
    expect(find.byKey(const Key('quote-review-demo-banner')), findsOneWidget);
    expect(find.text('Review Quote'), findsOneWidget);
  });

  testWidgets('complete local quote opens preview without claiming server approval',
      (tester) async {
    final draft = QuoteReviewDraft(
      id: 'complete-review-test', clientName: 'Customer Example',
      quoteNumber: 'Q-TEST-1', date: DateTime(2026, 10, 12),
      currency: 'CHF', vatBasisPoints: 800,
      items: [QuoteReviewWorkItem(
        id: 'line-1', title: 'Window installation', description: 'Fitting',
        quantity: '2', unitPrice: '100.00',
      )],
      terms: 'Sample conditions agreed with customer',
    );
    await tester.pumpWidget(MaterialApp(home: ReviewQuoteScreen(initialDraft: draft)));
    await tester.ensureVisible(find.byKey(const Key('quote-approve')));
    await tester.tap(find.byKey(const Key('quote-approve')));
    await tester.pumpAndSettle();
    expect(find.byType(QuotePreviewScreen), findsOneWidget);
    expect(find.text('Q-TEST-1'), findsOneWidget);
    expect(find.text('CHF 216.00'), findsWidgets);
  });

  testWidgets('missing unit price blocks approval but permits local draft', (tester) async {
    await tester.pumpWidget(MaterialApp(home: ReviewQuoteScreen(
      initialDraft: QuoteReviewDraft.figmaDemo(),
    )));
    expect(find.byType(Sign2DigitalQuoteWorkItemCard), findsNWidgets(2));
    expect(find.text('£765.00 (partial)'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('quote-approve')));
    await tester.tap(find.byKey(const Key('quote-approve')));
    await tester.pump();
    expect(find.textContaining('Cannot approve:'), findsOneWidget);
    // Dismiss the approval notice before interacting with the bottom action.
    // A snackbar overlays and absorbs taps on an otherwise visible button.
    ScaffoldMessenger.of(tester.element(find.byType(ReviewQuoteScreen)))
        .removeCurrentSnackBar();
    await tester.pumpAndSettle();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.ensureVisible(find.byKey(const Key('quote-save-draft')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('quote-save-draft')));
    await tester.pump();
    expect(QuoteReviewSessionStore.load('figma-quote-review-demo'), isNotNull);
  });

  testWidgets('Add Items creates editable work item with sequential number', (tester) async {
    await tester.pumpWidget(MaterialApp(home: ReviewQuoteScreen(
      initialDraft: QuoteReviewDraft.figmaDemo(),
    )));
    await tester.ensureVisible(find.byKey(const Key('quote-add-items')));
    await tester.tap(find.byKey(const Key('quote-add-items')));
    await tester.pump();
    expect(find.byType(Sign2DigitalQuoteWorkItemCard), findsNWidgets(3));
    expect(tester.widgetList<Sign2DigitalQuoteWorkItemCard>(
      find.byType(Sign2DigitalQuoteWorkItemCard)).last.number, 3);
  });

  testWidgets('Quote Details edit and Terms expand use real input', (tester) async {
    await tester.pumpWidget(MaterialApp(home: ReviewQuoteScreen(
      initialDraft: QuoteReviewDraft.figmaDemo(),
    )));
    await tester.tap(find.byKey(const Key('quote-edit-details')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('quote-edit-client')),
        matching: find.byType(TextField),
      ),
      'Anne Example',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.tap(find.byKey(const Key('quote-details-apply')));
    await tester.pumpAndSettle();
    expect(find.text('Anne Example'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('quote-terms-toggle')));
    await tester.tap(find.byKey(const Key('quote-terms-toggle')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('quote-terms-edit')), findsOneWidget);
  });

  testWidgets('responsive body does not overflow at narrow and landscape widths', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final size in [const Size(320, 640), const Size(740, 370),
      const Size(1080, 800)]) {
      // Unmount first so scroll/focus/render objects are not detached while
      // viewport metrics are changing.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(MaterialApp(home: ReviewQuoteScreen(
        initialDraft: QuoteReviewDraft.figmaDemo(),
      )));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'Viewport $size');
    }
  });
  testWidgets('multiple unpriced extracted items display editable content',
      (tester) async {
    final draft = QuoteReviewDraft.fromExtraction(
      QuotePreparationSnapshot(
        stage: QuotePreparationStage.completed,
        currency: 'CHF',
        items: [
          for (var i = 1; i <= 8; i++)
            QuotePreparedWorkItem(title: 'Renovation item $i',
              description: 'Description from AI $i', quantity: i),
        ],
      ),
      null,
    );
    await tester.pumpWidget(MaterialApp(home: ReviewQuoteScreen(
      initialDraft: draft,
    )));
    await tester.pump();
    expect(find.byKey(const Key('review-quote-scroll')), findsOneWidget);
    expect(find.byKey(const Key('quote-edit-details')), findsOneWidget);
    expect(find.byKey(const Key('quote-add-items')), findsOneWidget);
    expect(find.byType(Sign2DigitalQuoteWorkItemCard), findsNWidgets(8));
    expect(find.text('Pricing incomplete — resolve amber fields before approval.'),
      findsOneWidget);
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.ensureVisible(find.byKey(const Key('quote-approve')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('quote-approve')));
    await tester.pump();
    expect(find.textContaining('Cannot approve:'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

}
