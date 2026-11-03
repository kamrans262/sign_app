import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/features/clients/presentation/screens/clients_screen.dart';
import 'package:sign2digital/features/jobs/data/mock_jobs.dart';
import 'package:sign2digital/features/jobs/domain/job_details_model.dart';
import 'package:sign2digital/features/jobs/presentation/screens/job_details_screen.dart';

// The existing Home dashboard has unrelated ongoing asynchronous widgets.
 // Use bounded frames, as the M4 client tests do, instead of pumpAndSettle.
Future<void> pumpUi(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  final job = MockJobsData.jobs.first;

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
    await pumpUi(tester);
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
