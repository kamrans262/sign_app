import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:sign2digital/core/services/active_company_session.dart';
import 'package:sign2digital/core/services/sign_api_client.dart';
import 'package:sign2digital/features/jobs/data/remote_job_repository.dart';
import 'package:sign2digital/features/jobs/domain/create_job_draft.dart';
import 'package:sign2digital/features/jobs/domain/job_details_model.dart';
import 'package:sign2digital/features/jobs/domain/job_model.dart';
import 'package:sign2digital/features/jobs/presentation/screens/jobs_screen.dart';

Map<String, dynamic> serverJob({int company = 5, int id = 12,
    Object? budget = '4500.50'}) => {
  'id': id,
  'company_id': company,
  'client_id': 8,
  'client_name': 'Dupont SA',
  'reference_number': 'JOB-00000012',
  'title': 'Install three windows',
  'description': 'Install three windows',
  'address': 'Lausanne',
  'start_date': '2026-12-01',
  'due_date': '2026-12-15',
  'budget_chf': budget,
  'progress_percentage': 0,
  'stage': 'planning',
  'category': 'active',
  'team_member_ids': [],
  'team_members': [],
};

Map<String, dynamic> pagination(List<Map<String, dynamic>> jobs) => {
  'data': {
    'jobs': jobs,
    'pagination': {'page': 1, 'last_page': 1, 'total': jobs.length},
  },
};

SignApiClient api(
  Future<http.Response> Function(http.Request request) callback,
) => SignApiClient(
  baseUrl: Uri.parse('https://example.test'),
  tokenProvider: () async => 'verified-test-token',
  activeCompanyId: () => ActiveCompanySession.companyId,
  httpClient: MockClient(callback),
);

void main() {
  setUp(() => ActiveCompanySession.set(5));
  tearDown(ActiveCompanySession.clear);

  test('reads all categories without displaying unrelated demo jobs', () async {
    final requested = <String>[];
    final repo = RemoteJobRepository(api: api((request) async {
      expect(request.headers['X-Company-Id'], '5');
      expect(request.headers['Authorization'], 'Bearer verified-test-token');
      final category = request.url.queryParameters['category'];
      requested.add(category!);
      return http.Response(jsonEncode(pagination(
        category == 'active' ? [serverJob()] : [],
      )), 200);
    }));
    final jobs = await repo.listJobs();
    expect(requested, ['active', 'completed', 'archived']);
    expect(jobs, hasLength(1));
    expect(jobs.single.clientId, '8');
    expect(jobs.single.amountChf, 4501);
    expect(jobs.single.category, JobCategory.active);
  });

  test('creates a real client job without allowing body-selected tenant', () async {
    final repo = RemoteJobRepository(api: api((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/api/v1/jobs');
      final data = jsonDecode(request.body) as Map<String, dynamic>;
      expect(data['client_id'], 8);
      expect(data['description'], 'Install three windows');
      expect(data['start_date'], '2026-12-01');
      expect(data['due_date'], '2026-12-15');
      expect(data['team_member_ids'], [2]);
      expect(data.containsKey('company_id'), isFalse);
      return http.Response(jsonEncode({'data': {'job': serverJob()}}), 201);
    }));
    final draft = CreateJobDraft(
      clientId: '8', clientName: 'Dupont SA', address: 'Lausanne',
      description: 'Install three windows',
      startDate: DateTime(2026, 12, 1),
      endDate: DateTime(2026, 12, 15),
      budgetChf: 4500.5, teamMemberIds: const ['2'],
    );
    expect((await repo.createJob(draft)).id, '12');
  });

  test('rejects cross-company responses and mid-request company switching', () async {
    final foreign = RemoteJobRepository(api: api((request) async =>
      http.Response(jsonEncode(pagination([serverJob(company: 9)])), 200)));
    await expectLater(foreign.listJobs(), throwsA(isA<SignApiException>()));

    final switching = RemoteJobRepository(api: api((request) async {
      ActiveCompanySession.set(6);
      return http.Response(jsonEncode(pagination([serverJob()])), 200);
    }));
    await expectLater(switching.listJobs(), throwsA(isA<SignApiException>()));
  });

  test('does not invent budget or job finances for live records', () async {
    final raw = serverJob(budget: null);
    final repo = RemoteJobRepository(api: api((request) async {
      expect(request.url.path, '/api/v1/jobs/12');
      return http.Response(jsonEncode({'data': {
        'job': raw,
        'financials': {
          'quote_amount_chf': null, 'expenses_chf': null,
          'labour_cost_chf': null, 'deposits_chf': null,
          'invoiced_chf': null, 'received_chf': null,
          'remaining_balance_chf': null,
        },
      }}), 200);
    }));
    final job = JobModel(
      id: '12', title: 'Install three windows', clientId: '8',
      clientName: 'Dupont SA', description: 'Install three windows',
      referenceNumber: 'JOB-00000012',
      imageAsset: 'assets/images/jobs_image.jpg',
      amountChf: 0, progressPercentage: 0,
      dueDate: DateTime(2026, 12, 15),
      stage: JobStage.planning, category: JobCategory.active,
    );
    final details = await repo.loadDetails(job);
    expect(details.financialsAvailable, isFalse);
    expect(details.job.formattedAmount, 'Budget not set');
    expect(details.sections.length, JobSection.values.length);
    expect(details.sections.every((item) => item.subtitle == 'Tap to view'),
        isTrue);
  });

  testWidgets('signed-in jobs view keeps tabs but hides demo cards',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: JobsScreen(includeDemoJobs: false)),
    ));
    expect(find.text('No jobs found'), findsOneWidget);
    expect(find.text('Active (0)'), findsOneWidget);
    expect(find.text('Completed (0)'), findsOneWidget);
    expect(find.text('Archived (0)'), findsOneWidget);
  });
}
