import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/features/jobs/data/job_photo_local_store.dart';
import 'package:sign2digital/features/jobs/data/local_job_photo_source.dart';
import 'package:sign2digital/features/jobs/data/mock_jobs.dart';
import 'package:sign2digital/features/jobs/domain/job_photo_model.dart';
import 'package:sign2digital/features/jobs/presentation/screens/add_photos_screen.dart';
import 'package:sign2digital/features/jobs/presentation/screens/job_photos_screen.dart';
import 'package:sign2digital/features/jobs/presentation/widgets/sign2digital_job_photo_card.dart';

class _FakePhotoSource implements JobPhotoSource {
  _FakePhotoSource({this.pick, this.cancel = false});

  final LocalJobPhotoSelection? pick;
  final bool cancel;
  int cameraCalls = 0;
  int galleryCalls = 0;

  @override
  Future<LocalJobPhotoSelection?> camera() async {
    cameraCalls++;
    return cancel ? null : pick;
  }

  @override
  Future<List<LocalJobPhotoSelection>> upload() async {
    galleryCalls++;
    return cancel || pick == null ? [] : [pick!];
  }
}

void main() {
  final job = MockJobsData.jobs.first;
  final png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/m1cAAAAASUVORK5CYII=',
  );
  LocalJobPhotoSelection validSelection() => LocalJobPhotoSelection(
    name: 'photo.png',
    bytes: png,
    sourceKey: 'test/photo-1.png',
  );

  Future<void> size(WidgetTester tester, Size value) async {
    tester.view.physicalSize = value;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> openEditor(
    WidgetTester tester, {
    required _FakePhotoSource source,
    required JobPhotoLocalStore store,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: JobPhotosScreen(job: job, source: source, store: store),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('＋ Add Photos'));
    await tester.tap(find.text('＋ Add Photos'));
    await tester.pumpAndSettle();
    expect(find.byType(AddPhotosScreen), findsOneWidget);
    expect(find.byKey(const Key('dashboard-tab-1')), findsOneWidget);
  }

  testWidgets('Job Photos Add Photos opens editor; demo cannot be saved', (
    tester,
  ) async {
    await size(tester, const Size(430, 932));
    final store = JobPhotoLocalStore();
    await openEditor(tester, source: _FakePhotoSource(), store: store);
    expect(
      find.text('Take a photo or choose from your gallery'),
      findsOneWidget,
    );
    expect(find.text('Photo Preview'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('add-photo-save')));
    await tester.tap(find.byKey(const Key('add-photo-save')));
    await tester.pump();
    expect(find.byType(AddPhotosScreen), findsOneWidget);
    expect(store.photosFor(job.id), hasLength(4));
    expect(tester.takeException(), isNull);
  });

  testWidgets('gallery selection, category, caption, save updates gallery', (
    tester,
  ) async {
    await size(tester, const Size(430, 932));
    final store = JobPhotoLocalStore();
    final source = _FakePhotoSource(pick: validSelection());
    await openEditor(tester, source: source, store: store);
    await tester.ensureVisible(find.byKey(const Key('add-photo-gallery')));
    await tester.tap(find.byKey(const Key('add-photo-gallery')));
    await tester.pumpAndSettle();
    expect(source.galleryCalls, 1);
    await tester.tap(find.byKey(const Key('details-tab-2')));
    await tester.pumpAndSettle();
    final captionField = find.descendant(
      of: find.byKey(const Key('add-photo-caption-field')),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(captionField, 'New kitchen floor');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('add-photo-save')));
    await tester.tap(find.byKey(const Key('add-photo-save')));
    await tester.pumpAndSettle();
    expect(find.byType(AddPhotosScreen), findsNothing);
    expect(find.byType(JobPhotosScreen), findsOneWidget);
    expect(store.photosFor(job.id), hasLength(5));
    final saved = store.photosFor(job.id).last;
    expect(saved.jobId, job.id);
    expect(saved.category, JobPhotoCategory.after);
    expect(saved.caption, 'New kitchen floor');
    expect(saved.title, 'New kitchen floor');
    expect(find.byType(Sign2DigitalJobPhotoCard), findsNWidgets(5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('camera cancellation and image removal never save the demo', (
    tester,
  ) async {
    await size(tester, const Size(430, 932));
    final store = JobPhotoLocalStore();
    final source = _FakePhotoSource(pick: validSelection(), cancel: true);
    await openEditor(tester, source: source, store: store);
    await tester.tap(find.byKey(const Key('add-photo-camera')));
    await tester.pumpAndSettle();
    expect(source.cameraCalls, 1);
    await tester.tap(find.byKey(const Key('add-photo-remove')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('add-photo-remove')), findsNothing);
    expect(store.photosFor(job.id), hasLength(4));
    expect(tester.takeException(), isNull);
  });

  testWidgets('selected photo removal blocks save', (tester) async {
    await size(tester, const Size(390, 844));
    final store = JobPhotoLocalStore();
    await openEditor(
      tester,
      source: _FakePhotoSource(pick: validSelection()),
      store: store,
    );
    await tester.tap(find.byKey(const Key('add-photo-camera')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-photo-remove')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('add-photo-save')));
    await tester.tap(find.byKey(const Key('add-photo-save')));
    await tester.pump();
    expect(store.photosFor(job.id), hasLength(4));
    expect(tester.takeException(), isNull);
  });

  for (final viewport in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(430, 932),
    const Size(932, 430),
    const Size(1024, 768),
  ]) {
    testWidgets('Add Photos fits screen $viewport', (tester) async {
      await size(tester, viewport);
      await tester.pumpWidget(
        MaterialApp(
          home: AddPhotosScreen(
            job: job,
            source: _FakePhotoSource(),
            store: JobPhotoLocalStore(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('dashboard-tab-1')), findsOneWidget);
      expect(tester.takeException(), isNull);
      final scroll = find.byKey(const Key('add-photos-scroll'));
      await tester.drag(scroll, const Offset(0, -1200));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('add-photo-save')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
