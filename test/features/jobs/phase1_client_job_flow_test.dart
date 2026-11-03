import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/features/clients/presentation/screens/clients_screen.dart';
import 'package:sign2digital/features/clients/presentation/screens/client_details_screen.dart';
import 'package:sign2digital/features/clients/presentation/widgets/sign2digital_client_card.dart';
import 'package:sign2digital/features/jobs/data/demo_created_job_repository.dart';
import 'package:sign2digital/features/jobs/domain/create_job_draft.dart';
import 'package:sign2digital/features/jobs/domain/job_details_model.dart';
import 'package:sign2digital/features/jobs/domain/job_model.dart';
import 'package:sign2digital/features/jobs/presentation/screens/job_details_screen.dart';
import 'package:sign2digital/features/jobs/presentation/screens/jobs_screen.dart';
import 'package:sign2digital/features/jobs/presentation/widgets/sign2digital_job_card.dart';

CreateJobDraft _draft() => CreateJobDraft(
  clientId: 'client-42',
  clientName: 'Example Client',
  address: 'Rue du Centre 12',
  description: 'New Roof Repair',
  startDate: DateTime(2026, 8, 25),
  endDate: DateTime(2026, 9, 15),
  budgetChf: 1200.50,
  teamMemberIds: const ['demo-member-1'],
);

Future<void> _completeJobForm(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const Key('job-description-input')),
    'New Roof Repair',
  );
  for (final key in ['job-start-date', 'job-end-date']) {
    final field = find.byKey(Key(key));
    await tester.ensureVisible(field);
    await pumpUi(tester);
    await tester.tap(field);
    await pumpUi(tester);
    expect(find.byType(DatePickerDialog), findsOneWidget);
    await tester.tap(find.text('OK').last);
    await pumpUi(tester);
  }
  final create = find.byKey(const Key('create-new-job-button'));
  await tester.ensureVisible(create);
  await pumpUi(tester);
  await tester.tap(create);
  await pumpUi(tester);
}

// The existing Home dashboard has unrelated ongoing asynchronous widgets.
 // Use bounded frames, as the M4 client tests do, instead of pumpAndSettle.
Future<void> pumpUi(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  test('session jobs preserve real client ID and do not inherit demo costs', () {
    final store = DemoCreatedJobRepository();
    final first = store.create(_draft());
    final second = store.create(_draft());
    expect(first.clientId, 'client-42');
    expect(first.title, 'New Roof Repair');
    expect(first.clientName, 'Example Client');
    expect(first.referenceNumber, 'JOB-L-001');
    expect(first.stage, JobStage.planning);
    expect(first.category, JobCategory.active);
    expect(first.amountChf, 1201);
    expect(store.forClient('client-42').length, 2);
    expect(store.forClient('another-client'), isEmpty);
    expect(second.id, isNot(first.id));
    expect(store.draftFor(first.id)?.address, 'Rue du Centre 12');
    expect(store.draftFor(first.id)?.teamMemberIds, ['demo-member-1']);
    final details = JobDetailsModel.demoFor(first);
    expect(details.expensesChf, 0);
    expect(details.quoteAmountChf, 0);
    expect(details.invoicedChf, 0);
  });

  testWidgets('Jobs list displays new jobs alongside existing demo jobs',
      (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final job = DemoCreatedJobRepository().create(_draft());
    JobModel? selected;
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: JobsScreen(
        createdJobs: [job],
        onJobTap: (value) => selected = value,
      ),
    )));
    await pumpUi(tester);
    expect(find.text('Active (13)'), findsOneWidget);
    expect(find.text('New Roof Repair'), findsOneWidget);
    expect(find.byType(Sign2DigitalJobCard), findsWidgets);
    await tester.tap(find.text('New Roof Repair'));
    await tester.pump();
    expect(selected?.id, job.id);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Clients -> Create Job -> Job Details -> Jobs list',
      (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(
      home: ClientsScreen(initialTab: 2),
    ));
    await pumpUi(tester);
    await tester.tap(find.byType(Sign2DigitalClientCard).first);
    await pumpUi(tester);
    expect(find.byType(ClientDetailsScreen), findsOneWidget);
    await tester.ensureVisible(find.text('New Job'));
    await pumpUi(tester);
    await tester.tap(find.text('New Job'));
    await pumpUi(tester);
    expect(find.byKey(const Key('create-job-scroll')), findsOneWidget);
    await _completeJobForm(tester);

    expect(find.byType(JobDetailsScreen), findsOneWidget);
    expect(find.text('New Roof Repair'), findsWidgets);
    await tester.tap(find.descendant(
      of: find.byType(JobDetailsScreen),
      matching: find.byIcon(Icons.arrow_back_ios_new_rounded),
    ));
    await pumpUi(tester);
    expect(find.byType(ClientDetailsScreen), findsOneWidget);
    expect(find.text('Jobs (5)'), findsOneWidget);
    expect(find.text('New Roof Repair'), findsOneWidget);

    await tester.tap(find.descendant(
      of: find.byType(ClientDetailsScreen),
      matching: find.byIcon(Icons.arrow_back_ios_new_rounded),
    ));
    await pumpUi(tester);
    await tester.tap(find.byKey(const Key('dashboard-tab-1')));
    await pumpUi(tester);
    expect(find.text('Active (13)'), findsOneWidget);
    expect(find.text('New Roof Repair'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
