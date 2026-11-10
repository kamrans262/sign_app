import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:sign2digital/core/services/active_company_session.dart';
import 'package:sign2digital/core/services/sign_api_client.dart';
import 'package:sign2digital/features/jobs/data/job_photo_local_store.dart';
import 'package:sign2digital/features/jobs/data/local_job_photo_source.dart';
import 'package:sign2digital/features/jobs/data/remote_job_media_repository.dart';
import 'package:sign2digital/features/jobs/data/remote_job_repository.dart';
import 'package:sign2digital/features/jobs/domain/job_details_model.dart';
import 'package:sign2digital/features/jobs/domain/job_model.dart';
import 'package:sign2digital/features/jobs/domain/job_photo_model.dart';
import 'package:sign2digital/features/jobs/presentation/screens/job_photos_screen.dart';
import 'package:sign2digital/features/jobs/presentation/screens/add_photos_screen.dart';
import 'package:sign2digital/features/jobs/presentation/widgets/job_photo_gallery_dialog.dart';

class _Source implements JobPhotoSource {
  _Source(this.photos);
  final List<LocalJobPhotoSelection> photos;

  @override
  Future<List<LocalJobPhotoSelection>> upload() async => photos;

  @override
  Future<LocalJobPhotoSelection?> camera() async =>
      photos.isEmpty ? null : photos.first;
}

JobModel _job(String id) => JobModel(
  id: id, title: 'Window refurbishment', clientId: '12',
  clientName: 'Customer', description: 'Replace windows',
  referenceNumber: 'JOB-00000051',
  imageAsset: 'assets/images/jobs_image.jpg',
  amountChf: 0, progressPercentage: 0,
  dueDate: DateTime(2026, 12, 30),
  stage: JobStage.planning, category: JobCategory.active,
);

final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRzcAAAAASUVORK5CYII=');

void main() {
  test('Job Details uses all verified section counts and CHF values',
      () async {
    ActiveCompanySession.set(7);
    addTearDown(ActiveCompanySession.clear);
    final api = SignApiClient(
      baseUrl: Uri.parse('https://example.test'),
      tokenProvider: () async => 'test-auth',
      activeCompanyId: () => ActiveCompanySession.companyId,
      httpClient: MockClient((request) async {
        expect(request.url.path, '/api/v1/jobs/51');
        expect(request.headers['X-Company-Id'], '7');
        return http.Response(jsonEncode({
          'data': {
            'job': {
              'id': 51, 'company_id': 7, 'client_id': 12,
              'client_name': 'Customer', 'reference_number': 'JOB-00000051',
              'title': 'Window refurbishment', 'description': 'Replace windows',
              'start_date': '2026-12-01', 'due_date': '2026-12-30',
              'budget_chf': null, 'progress_percentage': 0,
              'stage': 'planning', 'category': 'active',
            },
            'financials_minor': {
              'quote_amount_minor': 125000,
              'expenses_minor': 10000,
              'labour_cost_minor': null,
              'deposits_minor': 35000,
              'invoiced_minor': 90000,
              'received_minor': 75000,
              'remaining_balance_minor': 15000,
            },
            'section_counts': {
              'quotes': 1, 'addenda': 0, 'documents': 0,
              'photos': 2, 'notes': 0, 'purchases': 1,
              'time': 0, 'deposits': 1, 'site_reports': 0,
              'acceptance': 0, 'invoices': 1,
            },
          },
        }), 200);
      }),
    );
    final result = await RemoteJobRepository(api: api).loadDetails(_job('51'));
    expect(result.quoteAmountChf, 1250);
    expect(result.expensesChf, 100);
    expect(result.depositsChf, 350);
    expect(result.invoicedChf, 900);
    expect(result.receivedChf, 750);
    expect(result.remainingBalanceChf, 150);
    expect(result.financialAvailableFor('labour_cost'), isFalse);
    expect(result.financialAvailableFor('invoiced'), isTrue);
    expect(result.sections.singleWhere(
      (item) => item.section == JobSection.photos).subtitle, '2 photos');
    expect(result.sections.singleWhere(
      (item) => item.section == JobSection.invoices).subtitle, '1 invoice');
    expect(result.sections.any(
      (item) => item.subtitle == 'Not connected yet'), isFalse);
    api.dispose();
  });

  testWidgets('Add Photos previews every selected gallery photo by swiping',
      (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final job = _job('demo-preview');
    final store = JobPhotoLocalStore();
    final source = _Source([
      LocalJobPhotoSelection(name: 'one.png', bytes: _png,
        sourceKey: 'gallery/one'),
      LocalJobPhotoSelection(name: 'two.png', bytes: _png,
        sourceKey: 'gallery/two'),
    ]);
    await tester.pumpWidget(MaterialApp(home:
      JobPhotosScreen(job: job, store: store, source: source)));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('job-photos-add-button')));
    await tester.tap(find.byKey(const Key('job-photos-add-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-photo-gallery')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('add-photo-preview-pages')), findsOneWidget);
    expect(find.text('Photo 1 of 2'), findsOneWidget);
    await tester.drag(find.byKey(const Key('add-photo-preview-pages')),
      const Offset(-280, 0));
    await tester.pumpAndSettle();
    expect(find.text('Photo 2 of 2'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('add-photo-save')));
    await tester.tap(find.byKey(const Key('add-photo-save')));
    await tester.pumpAndSettle();
    expect(find.byType(AddPhotosScreen), findsNothing);
    expect(store.photosFor(job.id), hasLength(6));
    expect(store.photosFor(job.id).last.sourceKey, 'gallery/two');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Saved gallery pages horizontally through existing photos',
      (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final images = [
      JobPhotoModel(
        id: '1', jobId: '51', title: 'Before',
        assetPath: 'assets/images/jp1.jpg',
        createdAt: DateTime(2026, 11, 11), category: JobPhotoCategory.before),
      JobPhotoModel(
        id: '2', jobId: '51', title: 'After',
        assetPath: 'assets/images/jp2.jpg',
        createdAt: DateTime(2026, 11, 12), category: JobPhotoCategory.after),
    ];
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: Builder(builder: (context) => TextButton(
        onPressed: () => showDialog<void>(context: context,
          builder: (_) => JobPhotoGalleryDialog(
            photos: images, initialPhotoId: '1')),
        child: const Text('Open gallery'),
      )),
    )));
    await tester.tap(find.text('Open gallery'));
    await tester.pumpAndSettle();
    expect(find.text('1 / 2'), findsOneWidget);
    expect(find.text('Before'), findsOneWidget);
    await tester.drag(find.byKey(const Key('job-photo-preview-pages')),
      const Offset(-340, 0));
    await tester.pumpAndSettle();
    expect(find.text('2 / 2'), findsOneWidget);
    expect(find.text('After'), findsOneWidget);
    await tester.tap(find.byKey(const Key('job-photo-close-preview')));
    await tester.pumpAndSettle();
    expect(find.byType(JobPhotoGalleryDialog), findsNothing);
  });

  testWidgets('Persisted job upload reaches Laravel, reloads verified DB rows',
      (tester) async {
    ActiveCompanySession.set(7);
    addTearDown(ActiveCompanySession.clear);
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final source = _Source([
      LocalJobPhotoSelection(
        name: 'site.png', bytes: _png, sourceKey: 'gallery/site.png'),
    ]);
    final digest = sha256.convert(_png).toString();
    var posts = 0;
    var reads = 0;
    final photo = {
      'id': 23, 'job_id': 51, 'company_id': 7,
      'title': 'Front View', 'caption': '',
      'category': 'during', 'mime_type': 'image/png',
      'sha256': digest, 'created_at': '2026-11-11T10:00:00Z',
    };
    final api = SignApiClient(
      baseUrl: Uri.parse('https://example.test'),
      tokenProvider: () async => 'test-auth',
      activeCompanyId: () => ActiveCompanySession.companyId,
      httpClient: MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer test-auth');
        expect(request.headers['X-Company-Id'], '7');
        if (request.method == 'POST' &&
            request.url.path == '/api/v1/jobs/51/photos') {
          posts++;
          expect(request.headers.entries.any((e) =>
            e.key.toLowerCase() == 'content-type' &&
            e.value.contains('multipart/form-data')), isTrue);
          return http.Response(jsonEncode({'data': {'photo': photo}}), 201);
        }
        if (request.method == 'GET' &&
            request.url.path == '/api/v1/jobs/51/photos') {
          reads++;
          return http.Response(jsonEncode({'data': {
            'photos': posts == 0 ? [] : [photo],
          }}), 200);
        }
        if (request.method == 'GET' &&
            request.url.path == '/api/v1/jobs/51/photos/23/file') {
          return http.Response.bytes(_png, 200, headers: {
            'content-type': 'image/png',
          });
        }
        throw StateError('Unexpected job media request: ' +
          request.method + ' ' + request.url.path);
      }),
    );
    await tester.pumpWidget(MaterialApp(home: JobPhotosScreen(
      job: _job('51'), source: source,
      remoteRepository: RemoteJobMediaRepository(api: api),
    )));
    await tester.pumpAndSettle();
    expect(posts, 0);
    await tester.ensureVisible(find.byKey(const Key('job-photos-upload')));
    await tester.tap(find.byKey(const Key('job-photos-upload')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('job-photos-confirm-pending')));
    await tester.tap(find.byKey(const Key('job-photos-confirm-pending')));
    await tester.pumpAndSettle();
    expect(posts, 1);
    if (reads < 2) {
      final labels = tester.widgetList<Text>(find.byType(Text))
          .map((widget) => widget.data).whereType<String>().join(' | ');
      debugPrint('Job photo upload diagnostic: reads=$reads, labels=$labels');
    }
    expect(reads, greaterThanOrEqualTo(2));
    expect(find.byKey(const Key('photo-grid-23')), findsOneWidget);
    expect(find.byKey(const Key('job-photo-pending-panel')), findsNothing);
    expect(tester.takeException(), isNull);
    api.dispose();
  });
}
