import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/features/quotes/domain/quote_draft_input.dart';
import 'package:sign2digital/features/quotes/domain/quote_extraction_models.dart';
import 'package:sign2digital/features/quotes/domain/quote_preparation_service.dart';
import 'package:sign2digital/features/quotes/presentation/screens/quote_ai_processing_screen.dart';
import 'package:sign2digital/features/quotes/presentation/screens/create_quote_screen.dart';
import 'package:sign2digital/features/quotes/presentation/screens/review_quote_screen.dart';
import 'package:sign2digital/features/quotes/presentation/widgets/sign2digital_quote_work_item_card.dart';

class _FakeService implements QuotePreparationService {
  final controller = StreamController<QuotePreparationSnapshot>.broadcast();
  final inputs = <QuoteDraftInput>[];
  @override
  Stream<QuotePreparationSnapshot> prepare(QuoteDraftInput input) {
    inputs.add(input);
    return controller.stream;
  }
  Future<void> dispose() => controller.close();
}

final sampleInput = QuoteDraftInput(
  method: QuoteInputMethod.text,
  description: 'Install three windows.',
  clientId: 'test-client',
  createdAt: DateTime(2026, 10, 12),
);

void main() {
  test('quote illustration source exists and pubspec registers it', () async {
    final bytes = await File('assets/create_quote.png').readAsBytes();
    expect(bytes.length, greaterThan(1024));
    final spec = await File('pubspec.yaml').readAsString();
    expect(spec.contains('assets/create_quote.png'), isTrue);
  });

  testWidgets('processing page references quote illustration', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: QuoteAiProcessingScreen()));
    expect(find.byKey(const Key('create-quote-illustration')), findsOneWidget);
  });

  testWidgets('No service does not invent extracted data or progress', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: QuoteAiProcessingScreen()));
    expect(find.textContaining('AI quote generation is not connected yet'), findsOneWidget);
    expect(find.text('3 windows'), findsNothing);
    expect(find.byKey(const Key('quote-processing-progress')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Figma example is explicitly labelled as demonstration', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: QuoteAiProcessingScreen()));
    await tester.ensureVisible(find.byKey(const Key('quote-preview-example')));
    await tester.tap(find.byKey(const Key('quote-preview-example')));
    await tester.pump();
    expect(find.byKey(const Key('quote-demo-label')), findsOneWidget);
    expect(find.text('3 windows'), findsOneWidget);
    expect(find.text('60%'), findsOneWidget);
    expect(find.byKey(const Key('quote-extracted-row-demo-material-a')), findsOneWidget);
    expect(find.byKey(const Key('quote-extracted-row-demo-material-b')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('real service fields and clamped percentage update independently', (tester) async {
    final service = _FakeService();
    addTearDown(service.dispose);
    await tester.pumpWidget(MaterialApp(home: QuoteAiProcessingScreen(
      input: sampleInput, service: service,
    )));
    expect(find.text('3 windows'), findsNothing);
    service.controller.add(const QuotePreparationSnapshot(
      stage: QuotePreparationStage.partial,
      progressPercentage: 110,
      fields: [
        QuoteExtractedField(
          id: 'real-location', label: 'Location',
          value: 'A newly extracted, real address',
          status: QuoteExtractionStatus.needsReview,
        ),
      ],
    ));
    await tester.pump();
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('A newly extracted, real address'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed extraction retains partial information for review', (tester) async {
    final service = _FakeService();
    addTearDown(service.dispose);
    await tester.pumpWidget(MaterialApp(home: QuoteAiProcessingScreen(
      input: sampleInput, service: service,
    )));
    service.controller.add(const QuotePreparationSnapshot(
      stage: QuotePreparationStage.partial,
      fields: [QuoteExtractedField(
        id: 'valid-before-fail', label: 'Quantity', value: '7',
        status: QuoteExtractionStatus.needsReview,
      )],
    ));
    await tester.pump();
    service.controller.addError(StateError('Service error'));
    await tester.pump();
    expect(find.text('7'), findsOneWidget);
    expect(find.textContaining('Quote extraction failed'), findsOneWidget);
  });

  testWidgets('short vague prompt asks clarification and preserves original source',
      (tester) async {
    final service = _FakeService();
    addTearDown(service.dispose);
    await tester.pumpWidget(MaterialApp(home: QuoteAiProcessingScreen(
      input: QuoteDraftInput(
        method: QuoteInputMethod.text,
        description: 'Bathroom quote',
        clientId: 'client-7',
        jobId: 'job-4',
        createdAt: DateTime(2026, 11, 14),
      ),
      service: service,
    )));
    expect(service.inputs.length, 1);
    service.controller.add(const QuotePreparationSnapshot(
      stage: QuotePreparationStage.needsClarification,
      clarificationQuestion: 'What work is needed in the bathroom?',
    ));
    await tester.pump();
    expect(find.text('More Details Needed'), findsOneWidget);
    expect(find.text('What work is needed in the bathroom?'), findsOneWidget);
    expect(find.byKey(const Key('quote-processing-review')), findsNothing);
    await tester.enterText(find.byKey(const Key('quote-clarification-input')),
        'Replace the sink and tiles.');
    await tester.tap(find.byKey(const Key('quote-clarification-submit')));
    await tester.pump();
    expect(service.inputs.length, 2);
    expect(service.inputs.last.description, 'Bathroom quote');
    expect(service.inputs.last.clarification, 'Replace the sink and tiles.');
    expect(service.inputs.last.clientId, 'client-7');
    expect(service.inputs.last.jobId, 'job-4');
    service.controller.add(const QuotePreparationSnapshot(
      stage: QuotePreparationStage.completed,
      items: [QuotePreparedWorkItem(title:'Replace the sink')],
    ));
    await tester.pump();
    expect(find.byKey(const Key('quote-processing-review')), findsOneWidget);
  });

  testWidgets('long text wraps in phone portrait, landscape and tablet', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final size in [
      const Size(320, 640),
      const Size(740, 370),
      const Size(1080, 800),
    ]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(const MaterialApp(home: QuoteAiProcessingScreen(
        initialSnapshot: QuotePreparationSnapshot(
          stage: QuotePreparationStage.partial,
          progressPercentage: 45,
          fields: [QuoteExtractedField(
            id: 'very-long',
            label: 'Installation details for external fixtures',
            value: 'Removal of old windows, all labour, disposal and necessary safety and weatherproofing precautions for the complete renovation of this building',
            status: QuoteExtractionStatus.unclear,
          )],
        ),
      )));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'Failed viewport $size');
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('Create Quote Text Generate Draft uses real service injection', (tester) async {
    final service = _FakeService();
    addTearDown(service.dispose);
    await tester.pumpWidget(MaterialApp(home: CreateQuoteScreen(
      quotePreparationService: service,
    )));
    await tester.tap(find.byKey(const Key('quote-method-text')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('quote-text-input')),
        'Replace three windows, including removal of old frames');
    await tester.ensureVisible(find.byKey(const Key('quote-generate-draft')));
    await tester.tap(find.byKey(const Key('quote-generate-draft')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(QuoteAiProcessingScreen), findsOneWidget);
    expect(find.text('Connect Quote AI'), findsNothing);
    service.controller.add(const QuotePreparationSnapshot(
      stage: QuotePreparationStage.completed,
      items: [QuotePreparedWorkItem(title: 'Replace three windows',
        description: 'Removal of old frames', quantity: 3)],
      fields: [QuoteExtractedField(id: 'real-window', label: 'Work item 1',
        value: 'Replace three windows',
        status: QuoteExtractionStatus.needsReview)],
    ));
    await tester.pump();
    expect(find.text('Replace three windows'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('quote-processing-review')));
    await tester.tap(find.byKey(const Key('quote-processing-review')));
    await tester.pumpAndSettle();
    expect(find.text('Review Quote'), findsOneWidget);
  });
  testWidgets('completed AI reports extraction complete without verifying suggestions',
      (tester) async {
    final service = _FakeService();
    addTearDown(service.dispose);
    await tester.pumpWidget(MaterialApp(home: QuoteAiProcessingScreen(
      input: sampleInput, service: service,
    )));
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    service.controller.add(const QuotePreparationSnapshot(
      stage: QuotePreparationStage.completed,
      items: [
        QuotePreparedWorkItem(title: 'Kitchen demolition',
          description: 'Remove cabinets', quantity: 1),
      ],
      fields: [
        QuoteExtractedField(id: 'ai-work-1', label: 'Work item 1',
          value: 'Kitchen demolition', status: QuoteExtractionStatus.needsReview),
        QuoteExtractedField(id: 'ai-price-warning', label: 'Pricing',
          value: 'Enter prices', status: QuoteExtractionStatus.missing),
      ],
    ));
    await tester.pump();
    expect(find.text('Quote Draft Ready'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    expect(find.byKey(const Key('quote-processing-progress')), findsOneWidget);
    expect(find.byKey(const Key('quote-field-ai-extracted')), findsOneWidget);
    expect(find.byKey(const Key('quote-field-missing')), findsOneWidget);
    expect(find.byKey(const Key('quote-processing-complete-label')),
      findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('eight real AI work items appear on Review Quote, not an empty page',
      (tester) async {
    final service = _FakeService();
    addTearDown(service.dispose);
    await tester.pumpWidget(MaterialApp(home: QuoteAiProcessingScreen(
      input: sampleInput, service: service,
    )));
    service.controller.add(QuotePreparationSnapshot(
      stage: QuotePreparationStage.completed,
      currency: 'CHF',
      items: [
        for (var i = 1; i <= 8; i++)
          QuotePreparedWorkItem(title: 'Kitchen task $i',
            description: 'Real source detail $i', quantity: i),
      ],
      fields: [
        for (var i = 1; i <= 8; i++)
          QuoteExtractedField(id: 'ai-work-$i', label: 'Work item $i',
            value: 'Kitchen task $i', status: QuoteExtractionStatus.needsReview),
      ],
    ));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('quote-processing-review')));
    await tester.tap(find.byKey(const Key('quote-processing-review')));
    await tester.pumpAndSettle();
    expect(find.byType(ReviewQuoteScreen), findsOneWidget);
    expect(find.byKey(const Key('quote-edit-details')), findsOneWidget);
    expect(find.byKey(const Key('quote-add-items')), findsOneWidget);
    expect(find.byType(Sign2DigitalQuoteWorkItemCard), findsNWidgets(8));
    final page = tester.widget<ReviewQuoteScreen>(find.byType(ReviewQuoteScreen));
    expect(page.initialDraft.items.length, 8);
    expect(page.initialDraft.items.last.title, 'Kitchen task 8');
    expect(page.initialDraft.items.first.unitPrice, isEmpty);
    await tester.ensureVisible(find.byKey(const Key('quote-approve')));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('extracted details use white rows and filled blue checks; only missing fields amber',
      (tester) async {
    const snapshot = QuotePreparationSnapshot(
      stage: QuotePreparationStage.completed,
      items: [QuotePreparedWorkItem(title: 'Window replacement', quantity: 3,
        description: 'Remove and replace three windows')],
      fields: [
        QuoteExtractedField(id: 'ai-items', label: 'Items',
          value: '1 work item', status: QuoteExtractionStatus.needsReview),
        QuoteExtractedField(id: 'ai-quantity', label: 'Quantity',
          value: '1 of 1 specified', status: QuoteExtractionStatus.needsReview),
        QuoteExtractedField(id: 'ai-price-warning', label: 'Pricing',
          value: 'Enter and confirm unit prices', status: QuoteExtractionStatus.missing),
      ],
    );
    await tester.pumpWidget(const MaterialApp(home: QuoteAiProcessingScreen(
      initialSnapshot: snapshot,
    )));
    expect(find.byKey(const Key('quote-field-ai-extracted')), findsNWidgets(2));
    expect(find.byKey(const Key('quote-field-missing')), findsOneWidget);
    final goodRow = tester.widget<Container>(find.byKey(
      const Key('quote-extracted-row-ai-items')));
    final warningRow = tester.widget<Container>(find.byKey(
      const Key('quote-extracted-row-ai-price-warning')));
    expect(goodRow.color, Colors.white);
    expect(warningRow.color, isNot(Colors.white));
    expect(find.text('1 work item'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

}
