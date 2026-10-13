import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/features/clients/presentation/screens/clients_screen.dart';
import 'package:sign2digital/features/jobs/data/mock_jobs.dart';
import 'package:sign2digital/features/jobs/domain/job_model.dart';
import 'package:sign2digital/features/jobs/presentation/widgets/sign2digital_job_card.dart';
import 'package:sign2digital/features/jobs/presentation/widgets/sign2digital_job_progress_indicator.dart';

void main() {
  test('demo category counts and combined search are coherent', () {
    expect(MockJobsData.count(JobCategory.active), 12);
    expect(MockJobsData.count(JobCategory.completed), 8);
    expect(MockJobsData.count(JobCategory.archived), 2);
    expect(
      MockJobsData.search(
        category: JobCategory.active,
        query: 'JOB-A-001',
      ).single.id,
      'demo-active-1',
    );
    expect(
      MockJobsData.search(category: JobCategory.archived, query: 'JOB-A-001'),
      isEmpty,
    );
    expect(MockJobsData.jobs.first.formattedAmount, 'CHF 24,500');
    expect(MockJobsData.jobs.first.formattedDueDate, 'Due 12 Aug, 2026');
  });

  testWidgets('bottom Jobs tab shows working filters, cards, and search', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: ClientsScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('dashboard-tab-1')));
    await tester.pumpAndSettle();
    expect(find.text('Jobs'), findsWidgets);
    expect(find.text('Active (12)'), findsOneWidget);
    expect(find.text('Completed (8)'), findsOneWidget);
    expect(find.text('Archived (2)'), findsOneWidget);
    expect(find.byType(Sign2DigitalJobCard), findsWidgets);
    expect(find.byKey(const Key('create-job-button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('details-tab-1')));
    await tester.pumpAndSettle();
    final completed = tester.widgetList<Sign2DigitalJobCard>(
      find.byType(Sign2DigitalJobCard),
    );
    expect(completed, isNotEmpty);
    expect(
      completed.every((card) => card.job.category == JobCategory.completed),
      isTrue,
    );

    await tester.enterText(find.byType(TextField), 'not-a-matching-job');
    await tester.pumpAndSettle();
    expect(find.text('No jobs found'), findsOneWidget);
    expect(find.byKey(const Key('create-job-button')), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Terrace');
    await tester.pumpAndSettle();
    expect(find.byType(Sign2DigitalJobCard), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('progress clamps invalid percentages', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 250,
            child: Sign2DigitalJobProgressIndicator(percentage: 150),
          ),
        ),
      ),
    );
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      1,
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 250,
            child: Sign2DigitalJobProgressIndicator(percentage: -20),
          ),
        ),
      ),
    );
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      0,
    );
  });

  for (final size in [
    const Size(320, 568),
    const Size(430, 932),
    const Size(800, 1180),
  ]) {
    testWidgets(
      'Jobs content and bottom navigation at ${size.width}x${size.height}',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(const MaterialApp(home: ClientsScreen()));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('dashboard-tab-1')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('dashboard-tab-1')), findsOneWidget);
        expect(find.text('Jobs'), findsWidgets);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
