import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/features/quotes/domain/quote_review_models.dart';
import 'package:sign2digital/features/quotes/domain/quote_extraction_models.dart';

void main() {
  setUp(QuoteReviewSessionStore.clear);

  test('money parses exactly to integer minor units', () {
    expect(parseQuoteMinorUnits('765.00'), 76500);
    expect(parseQuoteMinorUnits('£1,234.50'), 123450);
    expect(parseQuoteMinorUnits('1.999'), isNull);
    expect(parseQuoteMinorUnits('-3'), isNull);
    expect(parseQuoteMinorUnits(''), isNull);
    expect(quoteMoney(123450, 'GBP'), '£1,234.50');
    expect(quoteMoney(76500, 'CHF'), 'CHF 765.00');
  });

  test('demo values calculate consistently and unresolved items block approval', () {
    final draft = QuoteReviewDraft.figmaDemo();
    expect(draft.items.first.totalMinor, 76500);
    expect(draft.validSubtotalMinor, 76500);
    expect(draft.subtotalMinor, isNull); // Second unit price is missing.
    expect(draft.totalMinor, isNull);
    expect(draft.approvalIssues, isNotEmpty);
    draft.items.last.unitPrice = '100.00';
    expect(draft.subtotalMinor, 86500);
    expect(draft.vatMinor, 17300);
    expect(draft.totalMinor, 103800);
    expect(draft.depositMinor, 31140);
    expect(draft.approvalIssues, isEmpty);
  });

  test('new work item with missing prices is not treated as zero', () {
    final draft = QuoteReviewDraft.figmaDemo();
    draft.items.add(QuoteReviewWorkItem(
      id: 'new', title: 'Painting', description: '', quantity: '2'));
    expect(draft.items.last.totalMinor, isNull);
    draft.items.last.unitPrice = '19.99';
    expect(draft.items.last.totalMinor, 3998);
  });

  test('local draft saves include incomplete data without aliasing mutations', () {
    final draft = QuoteReviewDraft.figmaDemo();
    QuoteReviewSessionStore.save(draft);
    draft.items.first.title = 'Modified';
    expect(QuoteReviewSessionStore.load(draft.id)!.items.first.title,
      'PVC Windows (Standard)');
  });

  test('genuine extraction maps actual values and never invents a unit price', () {
    final draft = QuoteReviewDraft.fromExtraction(
      const QuotePreparationSnapshot(stage: QuotePreparationStage.completed,
        fields: [QuoteExtractedField(id: 'i', label: 'Items', value: '4 doors',
          status: QuoteExtractionStatus.verified)]), null);
    expect(draft.items.single.title, '4 doors');
    expect(draft.items.single.priceMinor, isNull);
    expect(draft.quoteNumber, isEmpty);
    expect(draft.clientName, isEmpty);
  });

  test('real AI work items map separately with missing prices and review flags', () {
    final draft = QuoteReviewDraft.fromExtraction(
      const QuotePreparationSnapshot(
        stage: QuotePreparationStage.completed,
        currency: 'GBP',
        items: [
          QuotePreparedWorkItem(title: 'Window removal',
            description: 'Remove old frames', quantity: 3, dimensions: '1.2 m x 1.5 m'),
          QuotePreparedWorkItem(title: 'Painting', description: '', quantity: null),
        ],
        fields: [QuoteExtractedField(id: 'ai-location', label: 'Location',
          value: '12 Oak Road', status: QuoteExtractionStatus.needsReview)],
      ),
      null,
    );
    expect(draft.currency, 'GBP');
    expect(draft.items.length, 2);
    expect(draft.items.first.quantity, '3');
    expect(draft.items.first.dimensions, '1.2 m x 1.5 m');
    expect(draft.items.first.unitPrice, isEmpty);
    expect(draft.items.last.quantity, isEmpty);
    expect(draft.items.first.otherFields['Location'], '12 Oak Road');
    expect(draft.approvalIssues, isNotEmpty);
  });

  test('VAT and deposit use exact percent units and VAT-inclusive total', () {
    final draft = QuoteReviewDraft(
      id: 'percentage-m6', date: DateTime(2026, 11, 4),
      clientName: 'M6 Test Customer', quoteNumber: 'M6-TEST-002',
      currency: 'CHF', vatBasisPoints: 1300, depositBasisPoints: 3000,
      items: [QuoteReviewWorkItem(
        id: 'bricks', title: 'Bricks', description: 'Test only',
        quantity: '4', unitPrice: '150.00',
      )],
      terms: 'Test payment terms',
    );
    expect(quotePercentLabel(1300), '13');
    expect(quotePercentLabel(3000), '30');
    expect(quotePercentLabel(810), '8.1');
    expect(quotePercentLabel(1250), '12.5');
    expect(quotePercentLabel(0), '0');
    expect(quotePercentLabel(10000), '100');
    expect(draft.subtotalMinor, 60000);
    expect(draft.vatMinor, 7800);
    expect(draft.totalMinor, 67800);
    expect(draft.depositMinor, 20340);
    expect(draft.totalMinor! - draft.depositMinor!, 47460);

    draft.vatBasisPoints = 810;
    draft.depositBasisPoints = 1250;
    expect(draft.vatMinor, 4860);
    expect(draft.totalMinor, 64860);
    expect(draft.depositMinor, 8108); // Half-up cent rounding.
    expect(draft.totalMinor! - draft.depositMinor!, 56752);
  });


}
