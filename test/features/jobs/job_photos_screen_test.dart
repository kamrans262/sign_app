import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/features/jobs/data/job_photo_local_store.dart';
import 'package:sign2digital/features/jobs/data/local_job_photo_source.dart';
import 'package:sign2digital/features/jobs/data/mock_jobs.dart';
import 'package:sign2digital/features/jobs/domain/job_photo_model.dart';
import 'package:sign2digital/features/jobs/presentation/screens/job_details_screen.dart';
import 'package:sign2digital/features/jobs/presentation/screens/job_photos_screen.dart';
import 'package:sign2digital/features/jobs/presentation/screens/add_photos_screen.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:sign2digital/features/jobs/presentation/widgets/sign2digital_job_photo_card.dart';

class _FakeSource implements JobPhotoSource {
  _FakeSource(this.items);

  final List<LocalJobPhotoSelection> items;
  int uploadCount = 0;
  int cameraCount = 0;

  @override
  Future<List<LocalJobPhotoSelection>> upload() async {
    uploadCount++;
    return items;
  }

  @override
  Future<LocalJobPhotoSelection?> camera() async {
    cameraCount++;
    return items.isEmpty ? null : items.first;
  }
}

void main() {
  final job = MockJobsData.jobs.first;
  final png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/m1cAAAAASUVORK5CYII=',
  );

  LocalJobPhotoSelection chosen(String name) =>
      LocalJobPhotoSelection(name: name, bytes: png, sourceKey: 'test/$name');

  Future<void> setSize(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  test('both demo JPG files are bundled as Flutter assets', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    for (final asset in const [
      'assets/images/jp1.jpg',
      'assets/images/jp2.jpg',
    ]) {
      final bytes = await rootBundle.load(asset);
      expect(bytes.lengthInBytes, greaterThan(100), reason: asset);
    }
  });

  testWidgets('Add Photos button is full width and opens photo editor', (
    tester,
  ) async {
    await setSize(tester, const Size(430, 932));
    await tester.pumpWidget(
      MaterialApp(
        home: JobPhotosScreen(
          job: job,
          store: JobPhotoLocalStore(),
          source: _FakeSource([]),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final button = find.byKey(const Key('job-photos-add-button'));
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    final width = tester.getSize(button).width;
    expect(width, closeTo(390, 1));
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.byType(AddPhotosScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('photo demo entries have unique IDs and real categories', () {
    final records = JobPhotoModel.demoFor(job.id);
    expect(records.length, 4);
    expect(records.map((photo) => photo.id).toSet().length, 4);
    expect(
      records.where((photo) => photo.category == JobPhotoCategory.before),
      hasLength(1),
    );
    expect(
      records.where((photo) => photo.category == JobPhotoCategory.during),
      hasLength(2),
    );
    expect(
      records.where((photo) => photo.category == JobPhotoCategory.after),
      hasLength(1),
    );
    expect(
      JobPhotoModel.formattedDate(DateTime(2026, 3, 12, 10)),
      '12 Mar 2026 10:00',
    );
  });

  test('image data validation rejects wrong formats', () {
    expect(
      () => DeviceJobPhotoSource.validate('photo.txt', png),
      throwsFormatException,
    );
    expect(
      () => DeviceJobPhotoSource.validate('photo.jpg', png),
      throwsFormatException,
    );
    expect(
      () => DeviceJobPhotoSource.validate('photo.png', png),
      returnsNormally,
    );
  });

  testWidgets('tabs filter photos and banner can be dismissed', (tester) async {
    await setSize(tester, const Size(430, 932));
    await tester.pumpWidget(
      MaterialApp(
        home: JobPhotosScreen(
          job: job,
          store: JobPhotoLocalStore(),
          source: _FakeSource([]),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Sign2DigitalJobPhotoCard), findsNWidgets(4));
    await tester.tap(find.byKey(const Key('details-tab-1')));
    await tester.pumpAndSettle();
    expect(find.byType(Sign2DigitalJobPhotoCard), findsOneWidget);
    await tester.tap(find.byKey(const Key('details-tab-2')));
    await tester.pumpAndSettle();
    expect(find.byType(Sign2DigitalJobPhotoCard), findsNWidgets(2));
    await tester.tap(find.byKey(const Key('details-tab-3')));
    await tester.pumpAndSettle();
    expect(find.byType(Sign2DigitalJobPhotoCard), findsOneWidget);
    await tester.tap(find.byKey(const Key('details-tab-0')));
    await tester.pumpAndSettle();
    expect(find.byType(Sign2DigitalJobPhotoCard), findsNWidgets(4));
    await tester.tap(find.byKey(const Key('job-photo-dismiss-banner')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('job-photo-dismiss-banner')), findsNothing);
    expect(find.byKey(const Key('dashboard-tab-1')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('upload stages image, Add Photos commits, preview closes', (
    tester,
  ) async {
    await setSize(tester, const Size(430, 932));
    final fake = _FakeSource([chosen('photo.png')]);
    final store = JobPhotoLocalStore();
    await tester.pumpWidget(
      MaterialApp(
        home: JobPhotosScreen(job: job, source: fake, store: store),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('job-photos-upload')));
    await tester.tap(find.byKey(const Key('job-photos-upload')));
    await tester.pumpAndSettle();
    expect(fake.uploadCount, 1);
    expect(find.byKey(const Key('job-photo-pending-panel')), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const Key('job-photos-confirm-pending')),
    );
    await tester.tap(find.byKey(const Key('job-photos-confirm-pending')));
    await tester.pumpAndSettle();
    expect(store.photosFor(job.id), hasLength(5));
    expect(find.byKey(const Key('job-photo-pending-panel')), findsNothing);
    await tester.ensureVisible(find.byKey(const Key('job-photos-upload')));
    await tester.tap(find.byKey(const Key('job-photos-upload')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('job-photo-pending-panel')), findsNothing);
    await tester.ensureVisible(
      find.byKey(Key('job-photo-card-demo-${job.id}-0')),
    );
    await tester.tap(find.byKey(Key('job-photo-card-demo-${job.id}-0')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('job-photo-close-preview')), findsOneWidget);
    await tester.tap(find.byKey(const Key('job-photo-close-preview')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('job-photo-close-preview')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('camera stages image but cancelling selection adds none', (
    tester,
  ) async {
    await setSize(tester, const Size(430, 932));
    final fake = _FakeSource([chosen('camera.png')]);
    final store = JobPhotoLocalStore();
    await tester.pumpWidget(
      MaterialApp(
        home: JobPhotosScreen(job: job, source: fake, store: store),
      ),
    );
    await tester.ensureVisible(find.byKey(const Key('job-photos-camera')));
    await tester.tap(find.byKey(const Key('job-photos-camera')));
    await tester.pumpAndSettle();
    expect(fake.cameraCount, 1);
    expect(find.byKey(const Key('job-photo-pending-panel')), findsOneWidget);
    await tester.tap(find.byKey(const Key('remove-pending-0')));
    await tester.pumpAndSettle();
    expect(store.photosFor(job.id), hasLength(4));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Job Details Photos card opens gallery; back returns details', (
    tester,
  ) async {
    await setSize(tester, const Size(430, 932));
    await tester.pumpWidget(MaterialApp(home: JobDetailsScreen(job: job)));
    await tester.pumpAndSettle();
    final photos = find.byKey(const Key('job-section-photos'));
    await tester.ensureVisible(photos);
    await tester.pumpAndSettle();
    await tester.tap(photos);
    await tester.pumpAndSettle();
    expect(find.byType(JobPhotosScreen), findsOneWidget);
    expect(find.byKey(const Key('dashboard-tab-1')), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pumpAndSettle();
    expect(find.byType(JobPhotosScreen), findsNothing);
    expect(find.byType(JobDetailsScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(430, 932),
    const Size(932, 430),
    const Size(1024, 768),
    const Size(1180, 820),
  ]) {
    testWidgets('photo screen adapts without overflow at $size', (
      tester,
    ) async {
      await setSize(tester, size);
      await tester.pumpWidget(
        MaterialApp(
          home: JobPhotosScreen(
            job: job,
            source: _FakeSource([]),
            store: JobPhotoLocalStore(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('dashboard-tab-1')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.drag(
        find.byKey(const Key('job-photos-scroll')),
        const Offset(0, -1800),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('job-photos-camera')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
