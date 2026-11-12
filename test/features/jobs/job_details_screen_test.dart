import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/features/clients/presentation/screens/clients_screen.dart';
import 'package:sign2digital/features/jobs/data/mock_jobs.dart';
import 'package:sign2digital/features/jobs/domain/job_details_model.dart';
import 'package:sign2digital/features/jobs/domain/job_model.dart';
import 'package:sign2digital/features/jobs/widgets/m14_verified_job_expenses.dart';
import 'package:sign2digital/features/jobs/presentation/screens/job_details_screen.dart';
import 'package:sign2digital/features/jobs/presentation/screens/jobs_screen.dart';
import 'package:sign2digital/features/jobs/presentation/widgets/sign2digital_remaining_balance_card.dart';

// The existing Home dashboard has unrelated ongoing asynchronous widgets.
 // Use bounded frames, as the M4 client tests do, instead of pumpAndSettle.
Future<void> pumpUi(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  final job = MockJobsData.jobs.first;

  testWidgets('list and detail show backend progress, with no manual editor',
      (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final live = JobModel(
      id: 'live-progress-preview',
      title: 'Window refurbishment',
      clientId: '8',
      clientName: 'Company Client',
      description: 'Replace windows',
      referenceNumber: 'JOB-P-001',
      imageAsset: 'assets/images/jobs_image.jpg',
      amountChf: 12000,
      progressPercentage: 45,
      dueDate: DateTime(2026, 12, 30),
      stage: JobStage.inProgress,
      category: JobCategory.active,
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: JobsScreen(
        includeDemoJobs: false,
        createdJobs: [live],
        onCreateJob: () {},
        onJobTap: (_) {},
      )),
    ));
    await pumpUi(tester);
    expect(find.text('45%'), findsOneWidget);

    await tester.pumpWidget(MaterialApp(
      home: JobDetailsScreen(
        job: live,
        details: JobDetailsModel.liveUnconnected(live),
        onManageJob: (_, _) async => false,
      ),
    ));
    await pumpUi(tester);
    expect(find.text('45%'), findsOneWidget);
    await tester.tap(find.byKey(const Key('manage-job-action')));
    await pumpUi(tester);
    expect(find.text('Update Progress'), findsNothing);
    expect(find.text('Edit Job'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('details use the selected JobModel and independent demo values', () {
    final details = JobDetailsModel.demoFor(job);
    expect(details.job.id, job.id);
    expect(details.sections.length, 11);
    expect(details.remainingBalanceChf, 4500);
    expect(details.quoteAmountChf, 24500);
    expect(JobDetailsModel.formatChf(24500), 'CHF 24,500');
    expect(JobDetailsModel.formatChf(-4500), '-CHF 4,500');
    expect(JobDetailsModel.formatChf(0), 'CHF 0');
  });

  testWidgets('job balance unavailable without accepted quote, never fakes zero',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: Center(
        child: Sign2DigitalRemainingBalanceCard(
          balanceChf: 0,
          showAmount: false,
          emptyLabel: 'No accepted quotation',
        ),
      )),
    ));
    expect(find.text('Remaining balance'), findsOneWidget);
    expect(find.text('No accepted quotation'), findsOneWidget);
    expect(find.text('CHF 0'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('M14 totals are used even when authenticated job details loaded',
      (tester) async {
    // Actual server jobs use numeric IDs AND have a loaded JobDetailsModel.
    final savedJob=JobModel(
      id:'123',title:job.title,clientId:job.clientId,
      clientName:job.clientName,description:job.description,
      referenceNumber:job.referenceNumber,imageAsset:job.imageAsset,
      amountChf:job.amountChf,progressPercentage:job.progressPercentage,
      dueDate:job.dueDate,stage:job.stage,category:job.category,
    );
    await tester.pumpWidget(MaterialApp(
      home:JobDetailsScreen(
        job:savedJob,details:JobDetailsModel.liveUnconnected(savedJob),
      ),
    ));
    await pumpUi(tester);
    final totalCards=find.byType(M14VerifiedJobExpensesCard);
    expect(totalCards,findsNWidgets(2));
    expect(tester.widgetList<M14VerifiedJobExpensesCard>(totalCards)
        .every((card)=>card.jobId==123),isTrue);
    expect(tester.takeException(),isNull);
  });

  testWidgets('Jobs card opens selected details and back preserves filter', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: ClientsScreen()));
    await pumpUi(tester);
    await tester.tap(find.byKey(const Key('dashboard-tab-1')));
    await pumpUi(tester);
    await tester.tap(find.byKey(const Key('details-tab-1')));
    await pumpUi(tester);
    await tester.tap(find.byKey(const Key('job-image-demo-completed-1')));
    await pumpUi(tester);
    expect(find.byType(JobDetailsScreen), findsOneWidget);
    expect(find.text('Completed'), findsWidgets);
    // The underlying dashboard route remains mounted but offstage.
    // Assert against the active details route, not the entire Navigator tree.
    final detailsRoute = find.byType(JobDetailsScreen);
    expect(find.descendant(
      of: detailsRoute, matching: find.byKey(const Key('dashboard-tab-1')),
    ), findsOneWidget);
    expect(find.descendant(
      of: detailsRoute, matching: find.byKey(const Key('dashboard-tab-2')),
    ), findsOneWidget);
    expect(find.byKey(const Key('job-details-scroll')), findsOneWidget);
    expect(find.descendant(
      of: detailsRoute, matching: find.byKey(const Key('dashboard-tab-0')),
    ), findsOneWidget);
    await tester.tap(find.descendant(
      of: detailsRoute,
      matching: find.byIcon(Icons.arrow_back_ios_new_rounded),
    ));
    // Finish the outgoing route animation without waiting for the Home tab's
    // unrelated ongoing async widgets.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    expect(find.byType(JobDetailsScreen), findsNothing);
    expect(find.text('Completed (8)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('all section cards forward their own typed callback', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    JobSection? tapped;
    await tester.pumpWidget(
      MaterialApp(
        home: JobDetailsScreen(
          job: job,
          onSectionTap: (section) => tapped = section,
        ),
      ),
    );
    for (final section in JobSection.values) {
      final target = find.byKey(Key('job-section-${section.name}'));
      await tester.scrollUntilVisible(
        target,
        170,
        scrollable: find
            .descendant(
              of: find.byKey(const Key('job-details-scroll')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await pumpUi(tester);
      await tester.tap(target);
      expect(tapped, section);
    }
    expect(tester.takeException(), isNull);
  });

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(430, 932),
    const Size(800, 1180),
    const Size(1024, 768),
  ]) {
    testWidgets('job details renders without overflow at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(home: JobDetailsScreen(job: job)));
      await pumpUi(tester);
      expect(find.text('Job Progress'), findsOneWidget);
      expect(find.byKey(const Key('dashboard-tab-1')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.drag(
        find.byKey(const Key('job-details-scroll')),
        const Offset(0, -2000),
      );
      await pumpUi(tester);
      expect(find.byKey(const Key('job-section-invoices')), findsOneWidget);
      expect(find.byKey(const Key('dashboard-tab-1')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
