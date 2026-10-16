import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/features/clients/data/demo_client_repository.dart';
import 'package:sign2digital/features/clients/domain/client_profile.dart';
import 'package:sign2digital/features/clients/presentation/screens/client_details_screen.dart';
import 'package:sign2digital/features/jobs/domain/job_model.dart';
import 'package:sign2digital/features/jobs/presentation/screens/job_details_screen.dart';
import 'package:sign2digital/features/quotes/domain/quote_draft_input.dart';
import 'package:sign2digital/features/quotes/domain/quote_extraction_models.dart';
import 'package:sign2digital/features/quotes/domain/quote_review_models.dart';
import 'package:sign2digital/features/quotes/domain/quote_preparation_service.dart';
import 'package:sign2digital/features/quotes/presentation/screens/quote_ai_processing_screen.dart';
import 'package:sign2digital/features/quotes/presentation/screens/create_quote_screen.dart';
import 'package:sign2digital/features/quotes/presentation/screens/quote_preview_screen.dart';
import 'package:sign2digital/features/quotes/presentation/screens/review_quote_screen.dart';
import 'package:sign2digital/features/quotes/presentation/screens/send_quote_screen.dart';

class _CompletedQuoteService implements QuotePreparationService {
  @override
  Stream<QuotePreparationSnapshot> prepare(QuoteDraftInput input) async* {
    yield const QuotePreparationSnapshot(
      stage: QuotePreparationStage.completed,
      items: [QuotePreparedWorkItem(
        title: 'Replace windows', description: 'Remove old frames', quantity: 3,
      )],
    );
  }
}

void main() {
  testWidgets('Job Details Quotes opens existing Create Quote with IDs',
      (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final job = JobModel(
      id: 'job-42', title: 'Renovation', clientId: 'client-42',
      clientName: 'Alpine Builds', description: 'Repair a roof',
      referenceNumber: 'JOB-042', imageAsset: 'assets/images/jobs_image.jpg',
      amountChf: 1200, progressPercentage: 0,
      dueDate: DateTime(2026, 11, 12),
      stage: JobStage.planning, category: JobCategory.active,
    );
    const linkedClient = ClientProfile(
      id: 'client-42', companyName: 'Alpine Builds',
      companyType: 'Business', email: 'alpine@example.com',
      phone: '+41 44 111 22 33', address: 'Swiss Street 4', jobCount: 1,
    );
    await tester.pumpWidget(MaterialApp(
      home: JobDetailsScreen(
        job: job, companyId: 'company-7', client: linkedClient),
    ));
    await tester.pumpAndSettle();
    final quotes = find.byKey(const Key('job-section-quotes'));
    await tester.ensureVisible(quotes);
    await tester.pumpAndSettle();
    await tester.tap(quotes);
    await tester.pumpAndSettle();
    final create = tester.widget<CreateQuoteScreen>(
      find.byType(CreateQuoteScreen),
    );
    expect(create.jobId, job.id);
    expect(create.clientId, job.clientId);
    expect(create.clientName, job.clientName);
    expect(create.companyId, 'company-7');
    expect(create.clientEmail, 'alpine@example.com');
    expect(create.clientPhone, '+41 44 111 22 33');
    expect(create.clientAddress, 'Swiss Street 4');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Client Details New Quote carries actual client contact details',
      (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const client = ClientProfile(
      id: 'client-22', companyName: 'House Builders',
      companyType: 'Business', email: 'client@example.com',
      phone: '+41 123 456', address: 'Lake Road 1', jobCount: 0,
    );
    await tester.pumpWidget(MaterialApp(home: ClientDetailsScreen(
      client: client, repository: DemoClientRepository(),
      companyId: 'company-7',
    )));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('New Quote'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New Quote'));
    await tester.pumpAndSettle();
    final create = tester.widget<CreateQuoteScreen>(
      find.byType(CreateQuoteScreen),
    );
    expect(create.clientId, client.id);
    expect(create.clientName, client.companyName);
    expect(create.clientEmail, client.email);
    expect(create.clientPhone, client.phone);
    expect(create.clientAddress, client.address);
    expect(create.companyId, 'company-7');
    expect(create.jobId, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Text quote flows through AI Processing to linked Review',
      (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: CreateQuoteScreen(
      clientId: 'client-22', jobId: 'job-42',
      companyId: 'company-7', clientName: 'House Builders',
      clientEmail: 'client@example.com',
      quotePreparationService: _CompletedQuoteService(),
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('quote-method-text')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('quote-text-input')),
      'Replace three windows and remove old frames.',
    );
    final generate = find.byKey(const Key('quote-generate-draft'));
    await tester.ensureVisible(generate);
    await tester.pumpAndSettle();
    await tester.tap(generate);
    await tester.pumpAndSettle();
    expect(find.byType(QuoteAiProcessingScreen), findsOneWidget);
    final review = find.byKey(const Key('quote-processing-review'));
    await tester.ensureVisible(review);
    await tester.pumpAndSettle();
    await tester.tap(review);
    await tester.pumpAndSettle();
    final screen = tester.widget<ReviewQuoteScreen>(
      find.byType(ReviewQuoteScreen),
    );
    expect(screen.initialDraft.clientId, 'client-22');
    expect(screen.initialDraft.jobId, 'job-42');
    expect(screen.initialDraft.companyId, 'company-7');
    expect(screen.initialDraft.clientName, 'House Builders');
    expect(screen.initialDraft.items.single.unitPrice, isEmpty);
    expect(tester.takeException(), isNull);
  });

  test('AI extraction preserves trusted context and still requires pricing',
      () {
    final input = QuoteDraftInput(
      method: QuoteInputMethod.text,
      createdAt: DateTime(2026, 10, 16),
      description: 'Install windows',
      clientId: 'client-22', jobId: 'job-42',
      companyId: 'company-7',
      clientName: 'House Builders', clientEmail: 'client@example.com',
      clientPhone: '+41 123 456', clientAddress: 'Lake Road 1',
    );
    const extraction = QuotePreparationSnapshot(
      stage: QuotePreparationStage.completed,
      items: [QuotePreparedWorkItem(
        title: 'Install windows', description: 'Three windows', quantity: 3,
      )],
    );
    final draft = QuoteReviewDraft.fromExtraction(extraction, input);
    expect(draft.clientId, 'client-22');
    expect(draft.jobId, 'job-42');
    expect(draft.companyId, 'company-7');
    expect(draft.clientName, 'House Builders');
    expect(draft.clientEmail, 'client@example.com');
    expect(draft.clientPhone, '+41 123 456');
    expect(draft.billingAddress, 'Lake Road 1');
    expect(draft.items.single.unitPrice, isEmpty);
    expect(draft.approvalIssues, contains('Quote Number is required.'));
    QuoteReviewSessionStore.save(draft);
    final restored = QuoteReviewSessionStore.load(draft.id)!;
    expect(restored.jobId, 'job-42');
    expect(restored.companyId, 'company-7');
    QuoteReviewSessionStore.clear();
  });

  testWidgets('approved quote keeps job/client/company through Preview and Send',
      (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final draft = QuoteReviewDraft(
      id: 'phase2-review-to-send',
      clientId: 'client-22', jobId: 'job-42',
      companyId: 'company-7',
      clientName: 'House Builders', clientEmail: 'client@example.com',
      quoteNumber: 'Q-042', date: DateTime(2026, 10, 16),
      terms: 'Payment due in 30 days.',
      items: [QuoteReviewWorkItem(
        id: 'item-1', title: 'Repair roof', description: 'Replace tiles',
        quantity: '1', unitPrice: '200.00',
      )],
    );
    await tester.pumpWidget(MaterialApp(
      home: ReviewQuoteScreen(initialDraft: draft),
    ));
    await tester.pumpAndSettle();
    final approve = find.byKey(const Key('quote-approve'));
    await tester.ensureVisible(approve);
    await tester.pumpAndSettle();
    await tester.tap(approve);
    await tester.pumpAndSettle();
    final preview = tester.widget<QuotePreviewScreen>(
      find.byType(QuotePreviewScreen),
    );
    expect(preview.quote.approvedLocally, isTrue);
    expect(preview.quote.jobId, 'job-42');
    expect(preview.quote.clientId, 'client-22');
    expect(preview.quote.companyId, 'company-7');
    final send = find.byKey(const Key('quote-preview-share'));
    await tester.ensureVisible(send);
    await tester.pumpAndSettle();
    await tester.tap(send);
    await tester.pumpAndSettle();
    final sending = tester.widget<SendQuoteScreen>(
      find.byType(SendQuoteScreen),
    );
    expect(sending.quote.jobId, 'job-42');
    expect(sending.quote.clientId, 'client-22');
    expect(sending.quote.companyId, 'company-7');
    expect(sending.quote.clientEmail, 'client@example.com');
    expect(tester.takeException(), isNull);
    QuoteReviewSessionStore.clear();
  });
}
