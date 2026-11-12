import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:sign2digital/core/services/active_company_session.dart';
import 'package:sign2digital/core/services/sign_api_client.dart';
import 'package:sign2digital/features/jobs/data/remote_job_repository.dart';
import 'package:sign2digital/features/jobs/domain/job_model.dart';
import 'package:sign2digital/features/jobs/presentation/screens/job_details_screen.dart';

JobModel _job({bool completed = false}) => JobModel(
  id: 'demo-progress',
  title: 'Window renovation',
  clientId: '8',
  clientName: 'Company Client',
  description: 'Replace the windows',
  referenceNumber: 'JOB-TEST-001',
  imageAsset: 'assets/images/jobs_image.jpg',
  amountChf: 12000,
  progressPercentage: completed ? 100 : 25,
  dueDate: DateTime(2026, 12, 30),
  stage: completed ? JobStage.completed : JobStage.inProgress,
  category: completed ? JobCategory.completed : JobCategory.active,
);

void main() {
  testWidgets('progress can increase and decrease using the approved job menu',
      (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final changes = <int>[];
    await tester.pumpWidget(MaterialApp(
      home: JobDetailsScreen(
        job: _job(),
        onManageJob: (_, _) async => false,
        onProgressChanged: (_, percentage) async {
          changes.add(percentage);
          return false;
        },
      ),
    ));
    await tester.pump();

    for (final selected in [63, 12]) {
      await tester.tap(find.byKey(const Key('manage-job-action')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Update Progress'));
      await tester.pumpAndSettle();
      final slider = tester.widget<Slider>(
        find.byKey(const Key('job-progress-slider')),
      );
      slider.onChanged!(selected.toDouble());
      await tester.pump();
      expect(
        tester.widget<Text>(find.byKey(const Key('job-progress-value'))).data,
        '$selected%',
      );
      await tester.tap(find.byKey(const Key('save-job-progress')));
      await tester.pumpAndSettle();
    }
    expect(changes, [63, 12]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('completed jobs must be reopened before changing progress',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: JobDetailsScreen(
        job: _job(completed: true),
        onManageJob: (_, _) async => false,
        onProgressChanged: (_, _) async => true,
      ),
    ));
    await tester.pump();
    await tester.tap(find.byKey(const Key('manage-job-action')));
    await tester.pumpAndSettle();
    expect(find.text('Update Progress'), findsNothing);
    expect(find.text('Reopen Job'), findsOneWidget);
  });

  test('progress API persists exact percent and parses updated job', () async {
    ActiveCompanySession.set(5);
    addTearDown(ActiveCompanySession.clear);
    final client = SignApiClient(
      baseUrl: Uri.parse('https://example.test'),
      tokenProvider: () async => 'verified-test-token',
      activeCompanyId: () => ActiveCompanySession.companyId,
      httpClient: MockClient((request) async {
        expect(request.method, 'PATCH');
        expect(request.url.path, '/api/v1/jobs/12');
        expect(request.headers['X-Company-Id'], '5');
        final payload = jsonDecode(request.body) as Map<String, dynamic>;
        expect(payload['progress_percentage'], 63);
        expect(payload['stage'], 'in_progress');
        return http.Response(jsonEncode({
          'data': {
            'job': {
              'id': 12,
              'company_id': 5,
              'client_id': 8,
              'client_name': 'Company Client',
              'reference_number': 'JOB-T-012',
              'title': 'Window renovation',
              'description': 'Replace the windows',
              'address': '',
              'start_date': '2026-11-01',
              'due_date': '2026-12-30',
              'budget_chf': '12000.00',
              'progress_percentage': 63,
              'stage': 'in_progress',
              'category': 'active',
              'team_member_ids': [],
              'team_members': [],
            },
          },
        }), 200);
      }),
    );
    final updated = await RemoteJobRepository(api: client).updateJob(
      12,
      {'progress_percentage': 63, 'stage': 'in_progress'},
    );
    expect(updated.progressPercentage, 63);
    expect(updated.stage, JobStage.inProgress);
    client.dispose();
  });
}
