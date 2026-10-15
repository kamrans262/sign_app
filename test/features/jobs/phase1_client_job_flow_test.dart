import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sign2digital/features/clients/data/demo_client_repository.dart';
import 'package:sign2digital/features/clients/domain/client_profile.dart';
import 'package:sign2digital/features/clients/presentation/screens/client_details_screen.dart';
import 'package:sign2digital/features/jobs/data/demo_created_job_repository.dart';
import 'package:sign2digital/features/jobs/domain/create_job_draft.dart';
import 'package:sign2digital/features/jobs/domain/job_details_model.dart';
import 'package:sign2digital/features/jobs/domain/job_model.dart';
import 'package:sign2digital/features/jobs/presentation/screens/job_details_screen.dart';
import 'package:sign2digital/features/jobs/presentation/screens/jobs_screen.dart';
import 'package:sign2digital/features/jobs/presentation/widgets/sign2digital_job_card.dart';

const _client = ClientProfile(
  id: 'local-client-phase1',
  companyName: 'Phase One Client',
  companyType: 'Client',
  email: 'phase1@example.com',
  phone: '+41 21 555 12 12',
  jobCount: 0,
);

CreateJobDraft _draft({String description = 'Phase One Renovation'}) =>
    CreateJobDraft(
      clientId: _client.id,
      clientName: _client.companyName,
      address: '12 Main Street',
      description: description,
      startDate: DateTime(2026, 8, 25),
      endDate: DateTime(2026, 9, 15),
      budgetChf: 1500.50,
      teamMemberIds: const ['demo-member-1'],
    );

void main() {
  test('new jobs retain their client association and original draft', () {
    final jobs = DemoCreatedJobRepository();
    final first = jobs.create(_draft());
    final second = jobs.create(_draft(description: 'Other Job'));
    expect(first.clientId, _client.id);
    expect(first.clientName, _client.companyName);
    expect(first.title, 'Phase One Renovation');
    expect(first.category, JobCategory.active);
    expect(first.stage, JobStage.planning);
    expect(first.amountChf, 1501);
    expect(first.referenceNumber, 'JOB-L-001');
    expect(second.id, isNot(first.id));
    expect(jobs.forClient(_client.id).length, 2);
    expect(jobs.forClient('other-client'), isEmpty);
    expect(jobs.originalDraft(first.id)?.address, '12 Main Street');
    expect(jobs.originalDraft(first.id)?.teamMemberIds, ['demo-member-1']);
    final details = JobDetailsModel.demoFor(first);
    expect(details.quoteAmountChf, 0);
    expect(details.invoicedChf, 0);
    expect(details.expensesChf, 0);
  });

  testWidgets('Jobs tab shows session jobs without removing sample jobs',
      (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final job = DemoCreatedJobRepository().create(_draft());
    JobModel? opened;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: JobsScreen(
        createdJobs: [job],
        onJobTap: (value) => opened = value,
      )),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Active (13)'), findsOneWidget);
    expect(find.text('Phase One Renovation'), findsOneWidget);
    expect(find.byType(Sign2DigitalJobCard), findsWidgets);
    await tester.tap(find.text('Phase One Renovation'));
    await tester.pump();
    expect(opened?.id, job.id);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Client Details creates a job, opens Job Details and returns',
      (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = DemoClientRepository();
    await tester.pumpWidget(MaterialApp(
      home: ClientDetailsScreen(client: _client, repository: repository),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('New Job'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('create-job-scroll')), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('job-description-input')),
      'Phase One Renovation',
    );
    for (final key in ['job-start-date', 'job-end-date']) {
      final control = find.byKey(Key(key));
      await tester.ensureVisible(control);
      await tester.pumpAndSettle();
      await tester.tap(control);
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);
      await tester.tap(find.text('OK').last);
      await tester.pumpAndSettle();
    }
    final create = find.byKey(const Key('create-new-job-button'));
    await tester.ensureVisible(create);
    await tester.pumpAndSettle();
    await tester.tap(create);
    await tester.pumpAndSettle();

    expect(find.byType(JobDetailsScreen), findsOneWidget);
    expect(find.text('Phase One Renovation'), findsWidgets);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(ClientDetailsScreen), findsOneWidget);
    expect(find.text('Jobs (1)'), findsOneWidget);
    expect(find.text('Phase One Renovation'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
