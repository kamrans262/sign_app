import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/features/documents/data/remote_work_acceptance_repository.dart';
import 'package:sign2digital/features/documents/domain/document_record.dart';
import 'package:sign2digital/features/documents/presentation/screens/work_acceptance_editor_screen.dart';
import 'package:sign2digital/features/jobs/data/local_job_photo_source.dart';
import 'package:sign2digital/features/jobs/data/remote_job_media_repository.dart';
import 'package:sign2digital/features/jobs/domain/job_model.dart';
import 'package:sign2digital/features/jobs/domain/job_photo_model.dart';
import 'package:sign2digital/features/jobs/presentation/widgets/sign2digital_photo_preview.dart';

final _image=base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJ'
  'AAAADUlEQVQIHWP4z8DwHwAFgAI/ScL/nwAAAABJRU5ErkJggg==',
);
JobModel _job()=>JobModel(
  id:'44',title:'Completed roof',clientId:'12',clientName:'Test Client',
  description:'Completed job',referenceNumber:'JOB-44',
  imageAsset:'',amountChf:0,progressPercentage:100,
  dueDate:DateTime(2026,11,12),
  stage:JobStage.completed,category:JobCategory.completed,
);

class _PickedPhotos implements JobPhotoSource {
  int cameraCalls=0, galleryCalls=0;

  @override
  Future<LocalJobPhotoSelection?> camera() async {
    cameraCalls++;
    return LocalJobPhotoSelection(
      name:'new-camera.png',bytes:_image,sourceKey:'camera-1',
    );
  }

  @override
  Future<List<LocalJobPhotoSelection>> upload() async {
    galleryCalls++;
    return [
      LocalJobPhotoSelection(
        name:'gallery-1.png',bytes:_image,sourceKey:'gallery-1',
      ),
      LocalJobPhotoSelection(
        name:'gallery-2.png',bytes:_image,sourceKey:'gallery-2',
      ),
    ];
  }
}

class _SavedMedia extends RemoteJobMediaRepository {
  _SavedMedia();
  int uploads=0;
  final List<JobPhotoModel> saved=[];

  @override
  Future<JobPhotoModel> uploadPhoto(String jobId,
    LocalJobPhotoSelection file, JobPhotoCategory category,
    String caption) async {
    expect(jobId,'44');
    expect(category,JobPhotoCategory.after);
    final photo=JobPhotoModel(
      id:'${++uploads}',jobId:jobId,title:caption,caption:caption,
      category:category,createdAt:DateTime(2026,11,12),
      bytes:file.bytes,sourceKey:file.sourceKey,
    );
    saved.add(photo);
    return photo;
  }

  @override
  Future<List<JobPhotoModel>> listPhotos(String jobId) async {
    expect(jobId,'44');
    return saved;
  }
}

class _SavedAcceptance extends RemoteWorkAcceptanceRepository {
  _SavedAcceptance();
  WorkAcceptanceDraft? latest;
  int saves=0;

  @override
  Future<DocumentRecord> saveDraft(WorkAcceptanceDraft draft) async {
    saves++;
    latest=draft;
    return DocumentRecord(
      id:'acceptance-45', category:DocumentCategory.reports,
      reportKind:ReportKind.workAcceptance,
      number:'WA-45',title:'Work Acceptance',
      project:'Completed roof',customer:'Test Client',
      timestamp:DateTime(2026,11,12),status:'draft',jobId:'44',
    );
  }
}

void main() {
  testWidgets('Camera + multiple Gallery photos use original two-column '
      'previews, removals and save only selected IDs', (tester) async {
    final photos=_PickedPhotos(),media=_SavedMedia(),repo=_SavedAcceptance();
    await tester.pumpWidget(MaterialApp(home: WorkAcceptanceEditorScreen(
      initialJobId:'44',photoSource:photos,mediaRepository:media,
      repository:repo,jobLoader:() async=>[_job()],
    )));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('acceptance-select-photos')), 160,
      scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('acceptance-select-photos')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('acceptance-choose-camera')), findsOneWidget);
    expect(find.byKey(const Key('acceptance-choose-gallery')), findsOneWidget);
    await tester.tap(find.byKey(const Key('acceptance-choose-camera')));
    await tester.pumpAndSettle();
    expect(photos.cameraCalls,1);
    await tester.scrollUntilVisible(
      find.byKey(const Key('acceptance-photo-grid')), 160,
      scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('acceptance-photo-grid')), findsOneWidget);
    expect(find.byKey(const Key('acceptance-photo-0')), findsOneWidget);
    expect(find.byType(Sign2DigitalPhotoPreview), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const Key('acceptance-select-photos')), 160,
      scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('acceptance-select-photos')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('acceptance-choose-gallery')));
    await tester.pumpAndSettle();
    expect(photos.galleryCalls,1);
    expect(find.byType(Sign2DigitalPhotoPreview), findsNWidgets(3));

    await tester.scrollUntilVisible(
      find.byKey(const Key('acceptance-photo-1')), 100,
      scrollable: find.byType(Scrollable).first);
    await tester.tap(find.descendant(
      of:find.byKey(const Key('acceptance-photo-1')),
      matching:find.byType(IconButton)));
    await tester.pumpAndSettle();
    expect(find.byType(Sign2DigitalPhotoPreview), findsNWidgets(2));

    await tester.enterText(find.byType(TextFormField).first,'Roof finished');
    await tester.scrollUntilVisible(
      find.byKey(const Key('acceptance-save-draft')), 160,
      scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byKey(const Key('acceptance-save-draft')));
    await tester.pumpAndSettle();
    expect(repo.saves,1);
    expect(repo.latest!.photoIds.length,2);
    expect(media.uploads,2);
    expect(repo.latest!.jobId,'44');
    expect(tester.takeException(), isNull);
  });

  testWidgets('editing restores only previously linked photo previews',
      (tester) async {
    final media=_SavedMedia(),repo=_SavedAcceptance();
    media.saved.add(JobPhotoModel(
      id:'8',jobId:'44',title:'Work acceptance photo',
      category:JobPhotoCategory.after,
      createdAt:DateTime(2026,11,12),bytes:_image,
    ));
    final draft=WorkAcceptanceDraft(
      id:45,jobId:'44',revision:2,completedWork:'Roof finished',
      completionDate:DateTime(2026,11,12),
      cleaningStatus:'cleaned',photoIds:const [8],
    );
    await tester.pumpWidget(MaterialApp(home: WorkAcceptanceEditorScreen(
      initial:draft,photoSource:_PickedPhotos(),mediaRepository:media,
      repository:repo,jobLoader:() async=>[_job()],
    )));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('acceptance-photo-grid')), 160,
      scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('acceptance-photo-grid')), findsOneWidget);
    expect(find.byType(Sign2DigitalPhotoPreview), findsOneWidget);
    expect(find.textContaining('Select Photos (1/8)'), findsOneWidget);
    expect(find.text('Select Job Photos'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
