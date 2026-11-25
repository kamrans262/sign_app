import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:sign2digital/core/services/active_company_session.dart';
import 'package:sign2digital/core/services/sign_api_client.dart';
import 'package:sign2digital/features/jobs/data/remote_job_repository.dart';
import 'package:sign2digital/features/jobs/data/job_note_local_store.dart';
import 'package:sign2digital/features/jobs/data/job_photo_local_store.dart';
import 'package:sign2digital/features/jobs/domain/create_job_draft.dart';
import 'package:sign2digital/features/jobs/domain/job_details_model.dart';
import 'package:sign2digital/features/jobs/domain/job_model.dart';
import 'package:sign2digital/features/jobs/domain/job_note_model.dart';
import 'package:sign2digital/features/jobs/domain/job_photo_model.dart';
import 'package:sign2digital/features/jobs/presentation/screens/job_details_screen.dart';
import 'package:sign2digital/features/jobs/presentation/screens/jobs_screen.dart';

Map<String, dynamic> responseJob({int company = 5, int id = 12,
    String category = 'active', String stage = 'planning',
    Object? budget = '4500.50'}) => {
  'id': id, 'company_id': company, 'client_id': 8,
  'client_name': 'Dupont SA', 'reference_number': 'JOB-00000012',
  'title': 'Window Installation', 'description': 'Window Installation',
  'address': 'Lausanne', 'start_date': '2026-12-01',
  'due_date': '2026-12-15', 'budget_chf': budget,
  'progress_percentage': 30, 'stage': stage, 'category': category,
  'team_member_ids': [3, 4], 'team_members': [],
};
SignApiClient mockJobApi(
  Future<http.Response> Function(http.Request) handler,
) => SignApiClient(
  baseUrl: Uri.parse('https://example.test'),
  tokenProvider: () async => 'verified-test-token',
  activeCompanyId: () => ActiveCompanySession.companyId,
  httpClient: MockClient(handler),
);

JobModel sampleJob({JobCategory category = JobCategory.active}) => JobModel(
  id: '12', title: 'Window Installation', clientId: '8',
  clientName: 'Dupont SA', description: 'Window Installation',
  referenceNumber: 'JOB-00000012',
  imageAsset: 'assets/images/jobs_image.jpg', amountChf: 4501,
  budgetChfExact: 4500.50,
  progressPercentage: 30, dueDate: DateTime(2026, 12, 15),
  startDate: DateTime(2026, 12, 1), address: 'Lausanne',
  teamMemberIds: const ['3', '4'], stage: JobStage.planning,
  category: category,
);

void main() {
  setUp(() => ActiveCompanySession.set(5));
  tearDown(ActiveCompanySession.clear);

  test('lists every category and page without leaking company or losing jobs', () async {
    final seen = <String>[];
    final api = mockJobApi((request) async {
      expect(request.headers['X-Company-Id'], '5');
      expect(request.headers['Authorization'], 'Bearer verified-test-token');
      final category = request.url.queryParameters['category']!;
      final page = int.parse(request.url.queryParameters['page']!);
      seen.add('$category:$page');
      final items = category == 'active'
          ? [responseJob(id: page)]
          : <Map<String, dynamic>>[];
      return http.Response(jsonEncode({'data': {
        'jobs': items,
        'pagination': {'page': page,
          'last_page': category == 'active' ? 2 : 1,
          'total': category == 'active' ? 2 : 0},
      }}), 200);
    });
    final jobs = await RemoteJobRepository(api: api).listJobs();
    expect(jobs.map((job) => job.id), ['1', '2']);
    expect(seen, ['active:1', 'active:2', 'completed:1', 'archived:1']);
    expect(jobs.first.formattedAmount, 'CHF 4,500.50');
    expect(jobs.first.budgetChfExact, 4500.50);
    expect(jobs.first.teamMemberIds, ['3', '4']);
  });

  test('editing transmits original fields, full CHF precision and real team IDs', () async {
    final api = mockJobApi((request) async {
      expect(request.method, 'PATCH');
      expect(request.url.path, '/api/v1/jobs/12');
      expect(request.headers['X-Company-Id'], '5');
      final payload = jsonDecode(request.body) as Map<String, dynamic>;
      expect(payload.containsKey('company_id'), isFalse);
      expect(payload['client_id'], 8);
      expect(payload['team_member_ids'], [4]);
      expect(payload['title'], 'Kitchen Upgrade');
      expect(payload['description'], 'Kitchen Upgrade\nRebuild cabinets');
      expect(payload['address'], 'Rue du Centre 14');
      expect(payload['start_date'], '2026-12-10');
      expect(payload['due_date'], '2026-12-20');
      expect(payload['budget_chf'], 1999.75);
      return http.Response(jsonEncode({'data': {'job': responseJob()}}), 200);
    });
    final draft = CreateJobDraft(
      clientId: '8', clientName: 'Dupont SA',
      address: 'Rue du Centre 14',
      description: 'Kitchen Upgrade\nRebuild cabinets',
      startDate: DateTime(2026, 12, 10), endDate: DateTime(2026, 12, 20),
      budgetChf: 1999.75, teamMemberIds: const ['4'],
    );
    expect((await RemoteJobRepository(api: api)
      .updateDraft(sampleJob(), draft)).id, '12');
  });

  test('archive and restore use scoped endpoints and reject foreign response', () async {
    final seen = <String>[];
    final repo = RemoteJobRepository(api: mockJobApi((request) async {
      seen.add('${request.method} ${request.url.path}');
      expect(request.headers['X-Company-Id'], '5');
      if (request.method == 'DELETE') {
        return http.Response(jsonEncode({'message': 'Job archived.'}), 200);
      }
      return http.Response(jsonEncode({'data': {
        'job': responseJob(category: 'active'),
      }}), 200);
    }));
    await repo.archiveJob(12);
    expect((await repo.restoreJob(12)).category, JobCategory.active);
    expect(seen, [
      'DELETE /api/v1/jobs/12', 'POST /api/v1/jobs/12/restore',
    ]);
    final foreign = RemoteJobRepository(api: mockJobApi((_) async =>
      http.Response(jsonEncode({'data': {
        'job': responseJob(company: 99),
      }}), 200)));
    await expectLater(foreign.restoreJob(12), throwsA(isA<SignApiException>()));
  });

  test('job list requires verified company context, never falls back to demo', () async {
    ActiveCompanySession.clear();
    final repo = RemoteJobRepository(api: mockJobApi((_) async =>
        throw StateError('No HTTP should occur without company')));
    await expectLater(repo.listJobs(), throwsA(isA<SignApiException>()));
    ActiveCompanySession.set(5);
    final revoked = RemoteJobRepository(api: mockJobApi((_) async =>
      http.Response(jsonEncode({'message': 'Company permission denied.'}), 403)));
    await expectLater(revoked.listJobs(), throwsA(isA<SignApiException>()));
  });

  test('local photos and notes never seed demo data for persisted job IDs', () {
    final photos = JobPhotoLocalStore();
    final notes = JobNoteLocalStore();
    expect(photos.photosFor('12'), isEmpty);
    expect(notes.notesFor('12'), isEmpty);
    final image = JobPhotoModel(
      id: 'photo-1', jobId: '12', title: 'Front view',
      createdAt: DateTime(2026, 11, 3), category: JobPhotoCategory.before,
      assetPath: 'assets/images/jp1.jpg',
    );
    final note = JobNoteModel(
      id: 'note-1', jobId: '12', title: 'Inspection',
      body: 'Temporary local draft only', createdAt: DateTime(2026, 11, 3),
      type: JobNoteType.text, visibility: JobNoteVisibility.privateNote,
    );
    photos.addAll('12', [image]);
    notes.add(note);
    expect(photos.photosFor('12'), hasLength(1));
    expect(notes.notesFor('12'), hasLength(1));
    ActiveCompanySession.set(6);
    expect(photos.photosFor('12'), isEmpty);
    expect(notes.notesFor('12'), isEmpty);
    ActiveCompanySession.set(5);
    expect(photos.photosFor('12'), hasLength(1));
    expect(notes.notesFor('12'), hasLength(1));
  });

  testWidgets('live job manage menu uses existing sheet and correct action',
      (tester) async {
    String? selected;
    await tester.pumpWidget(MaterialApp(home: JobDetailsScreen(
      job: sampleJob(), details: JobDetailsModel.liveUnconnected(sampleJob()),
      onManageJob: (job, action) async {
        expect(job.id, '12');
        selected = action;
        return false;
      },
    )));
    await tester.pump();
    await tester.tap(find.byKey(const Key('manage-job-action')));
    await tester.pumpAndSettle();
    expect(find.text('Manage Job'), findsOneWidget);
    await tester.tap(find.text('Start Job'));
    await tester.pumpAndSettle();
    expect(selected, 'Start Job');
    expect(find.text('Not available'), findsWidgets);
  });

  testWidgets('live landscape jobs keep all tabs without demo rows',
      (tester) async {
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: JobsScreen(includeDemoJobs: false)),
    ));
    await tester.pump();
    expect(find.text('Active (0)'), findsOneWidget);
    expect(find.text('Completed (0)'), findsOneWidget);
    expect(find.text('Archived (0)'), findsOneWidget);
    expect(find.text('No jobs found'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
