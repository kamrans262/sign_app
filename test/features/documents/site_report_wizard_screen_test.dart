import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/core/widgets/sign2digital_bottom_navigation_bar.dart';
import 'package:sign2digital/core/widgets/sign2digital_checkbox.dart';
import 'package:sign2digital/features/documents/data/demo_report_repository.dart';
import 'package:sign2digital/features/documents/domain/document_record.dart';
import 'package:sign2digital/features/documents/presentation/screens/site_report_wizard_screen.dart';
import 'package:sign2digital/features/jobs/data/local_job_photo_source.dart';
import 'package:sign2digital/features/jobs/data/mock_jobs.dart';
import 'package:sign2digital/core/widgets/sign2digital_info_banner.dart';

class _PhotoSource implements JobPhotoSource {
  @override
  Future<LocalJobPhotoSelection?> camera() async => null;

  @override
  Future<List<LocalJobPhotoSelection>> upload() async => [
    LocalJobPhotoSelection(
      name: 'site-progress.png',
      bytes: Uint8List.fromList([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
      sourceKey: 'fake-photo-1',
    ),
  ];
}

Future<void> _details(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const Key('site-report-title')));
  await tester.pump();
  await tester.tap(find.byKey(const Key('site-report-title')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('site-report-title-option-0')));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.byKey(const Key('site-report-date')));
  await tester.pump();
  await tester.tap(find.byKey(const Key('site-report-date')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
  await tester.enterText(find.descendant(
    of: find.byKey(const Key('site-report-preparer')),
    matching: find.byType(TextFormField),
  ), 'Jean Dupont');
  await tester.ensureVisible(find.byKey(const Key('site-report-weather')));
  await tester.tap(find.byKey(const Key('site-report-weather')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('site-report-weather-option-0')));
  await tester.pumpAndSettle();
}

DocumentRecord _figmaContentFixture() {
  final photos = List.generate(3, (i) => LocalJobPhotoSelection(
    name: 'photo-$i.png',
    bytes: Uint8List.fromList(
      [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    sourceKey: 'figma-photo-$i',
  ));
  return DocumentRecord(
    id: 'site-content-fixture',
    category: DocumentCategory.reports,
    reportKind: ReportKind.siteReport,
    number: 'SR-TEST-1',
    title: 'Site Report',
    project: 'Kitchen renovations',
    customer: 'Jean Dupont',
    timestamp: DateTime(2026, 8, 25),
    status: 'Draft',
    demoOnly: true,
    siteReportDetails: SiteReportDetails(
      reportDate: DateTime(2026, 8, 25),
      preparedBy: 'Jean Dupont',
      weatherCondition: 'Sunny',
      selectedSections: const [
        SiteReportSection.siteProgress,
        SiteReportSection.photos,
        SiteReportSection.notes,
        SiteReportSection.issues,
      ],
      sectionContent: const {
        SiteReportSection.siteProgress: 'Existing kitchen renovations',
        SiteReportSection.notes: 'Renovation observations',
        SiteReportSection.issues: 'No issues',
      },
      photos: photos,
    ),
  );
}

DocumentRecord _completeReviewFixture({bool photo = true, String? title}) {
  final job = MockJobsData.jobs.first;
  return DocumentRecord(
    id: 'site-review-test-1',
    category: DocumentCategory.reports,
    reportKind: ReportKind.siteReport,
    number: 'SR-TEST-10',
    title: title ?? 'Site Report - Week 3',
    project: job.title,
    customer: job.clientName,
    timestamp: DateTime(2026, 8, 25),
    status: 'Draft',
    demoOnly: true,
    siteReportDetails: SiteReportDetails(
      reportDate: DateTime(2026, 8, 25),
      preparedBy: 'Jean Dupont',
      weatherCondition: 'Sunny',
      selectedSections: [
        SiteReportSection.siteProgress,
        if (photo) SiteReportSection.photos,
        SiteReportSection.notes,
      ],
      sectionContent: const {
        SiteReportSection.siteProgress: 'Real site progress description',
        SiteReportSection.notes: 'Actual site observations',
      },
      photos: photo ? [
        LocalJobPhotoSelection(
          name: 'real-cover.png',
          bytes: base64Decode(
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJ'
            'AAAADUlEQVQIHWP4z8DwHwAFgAI/ScL/nwAAAABJRU5ErkJggg=='),
          sourceKey: 'cover-1',
        ),
      ] : [],
    ),
  );
}

Future<void> _openReview(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const Key('site-report-next')));
  await tester.tap(find.byKey(const Key('site-report-next')));
  await tester.pump();
  await tester.ensureVisible(find.byKey(const Key('site-report-next')));
  await tester.tap(find.byKey(const Key('site-report-next')));
  await tester.pump();
}

void main() {
  setUp(DemoReportDraftSession.clear);


  testWidgets('Review shows the selected cover, actual fields, sections and info',
      (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: SiteReportWizardScreen(
      initial: _completeReviewFixture(),
    )));
    await _openReview(tester);
    expect(find.text('Review Reports'), findsOneWidget);
    expect(find.text('Site Reports'), findsNothing);
    expect(find.byKey(const Key('review-reports-body')), findsOneWidget);
    final cover = find.byKey(const Key('review-report-cover'));
    expect(cover, findsOneWidget);
    expect(find.byKey(const Key('review-report-cover-image')), findsOneWidget);
    final image = tester.widget<Image>(
      find.byKey(const Key('review-report-cover-image')));
    expect(image.fit, BoxFit.cover);
    final aspect = tester.widget<AspectRatio>(
      find.descendant(of: cover, matching: find.byType(AspectRatio)));
    expect(aspect.aspectRatio, closeTo(390/182, 0.001));
    expect(find.text('Site Report - Week 3'), findsOneWidget);
    expect(find.text(MockJobsData.jobs.first.title), findsOneWidget);
    expect(find.text(MockJobsData.jobs.first.clientName), findsOneWidget);
    expect(find.text('August 25, 2026'), findsOneWidget);
    expect(find.text('Jean Dupont'), findsOneWidget);
    for (final item in ['siteProgress', 'photos', 'notes']) {
      final box = tester.widget<Sign2DigitalCheckbox>(
        find.byKey(Key('review-report-section-$item')));
      expect(box.value, isTrue);
    }
    expect(find.byKey(const Key('review-report-section-materials')), findsNothing);
    final info = tester.widget<Sign2DigitalInfoBanner>(
        find.byKey(const Key('review-report-info')));
    expect(info.message,
      'Please review all information before generating the report');
    expect(find.text('Generate Report'), findsOneWidget);
    expect(tester.widget<Sign2DigitalBottomNavigationBar>(
      find.byType(Sign2DigitalBottomNavigationBar)).selectedIndex, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Review back preserves all entered content and photo selection',
      (tester) async {
    await tester.pumpWidget(MaterialApp(home: SiteReportWizardScreen(
      initial: _completeReviewFixture(),
    )));
    await _openReview(tester);
    await tester.ensureVisible(find.byKey(const Key('site-report-content-back')));
    await tester.tap(find.byKey(const Key('site-report-content-back')));
    await tester.pump();
    expect(find.text('Site Programs'), findsOneWidget);
    expect(find.byKey(const Key('site-report-photo-0')), findsOneWidget);
    final text = tester.widget<TextFormField>(
        find.byKey(const Key('site-report-content-siteProgress')));
    expect(text.controller!.text, 'Real site progress description');
    await tester.ensureVisible(find.byKey(const Key('site-report-next')));
    await tester.tap(find.byKey(const Key('site-report-next')));
    await tester.pump();
    expect(find.byKey(const Key('review-report-cover-image')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Without a cover image, an honest empty image state is used',
      (tester) async {
    await tester.pumpWidget(MaterialApp(home: SiteReportWizardScreen(
      initial: _completeReviewFixture(photo: false),
    )));
    await _openReview(tester);
    expect(find.text('No report photo selected'), findsOneWidget);
    expect(find.byKey(const Key('review-report-cover-image')), findsNothing);
    expect(find.byKey(const Key('review-report-section-photos')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('No generation service offers an explicitly local draft',
      (tester) async {
    DocumentRecord? saved;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(
      builder: (context) => TextButton(
        onPressed: () async {
          saved = await Navigator.of(context).push<DocumentRecord>(
            MaterialPageRoute(builder: (_) => SiteReportWizardScreen(
              initial: _completeReviewFixture())),
          );
        },
        child: const Text('Open report'),
      ),
    ))));
    await tester.tap(find.text('Open report'));
    await tester.pumpAndSettle();
    await _openReview(tester);
    await tester.ensureVisible(find.byKey(const Key('site-report-next')));
    await tester.tap(find.byKey(const Key('site-report-next')));
    await tester.pumpAndSettle();
    expect(find.text('Report generation unavailable'), findsOneWidget);
    await tester.tap(find.byKey(const Key('review-report-save-local-draft')));
    await tester.pumpAndSettle();
    expect(saved?.status, 'Draft');
    expect(saved?.demoOnly, isTrue);
    expect(saved?.siteReportDetails?.photos.length, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Failed real generation stays on Review, preventing duplicate calls',
      (tester) async {
    var calls = 0;
    final waiting = Completer<DocumentRecord>();
    await tester.pumpWidget(MaterialApp(home: SiteReportWizardScreen(
      initial: _completeReviewFixture(),
      reportGenerator: (draft) {
        calls++;
        expect(draft.title, 'Site Report - Week 3');
        expect(draft.project, MockJobsData.jobs.first.title);
        expect(draft.siteReportDetails?.sectionContent[
            SiteReportSection.siteProgress], 'Real site progress description');
        return waiting.future;
      },
    )));
    await _openReview(tester);
    await tester.ensureVisible(find.byKey(const Key('site-report-next')));
    await tester.tap(find.byKey(const Key('site-report-next')));
    await tester.pump();
    expect(calls, 1);
    expect(find.byKey(const Key('site-report-next')), findsOneWidget);
    expect(tester.widget<SiteReportWizardScreen>(
      find.byType(SiteReportWizardScreen)).reportGenerator, isNotNull);
    waiting.completeError(StateError('Server offline'));
    await tester.pumpAndSettle();
    expect(find.textContaining('generation failed'), findsOneWidget);
    expect(find.text('Review Reports'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final size in [
    const Size(320, 650), const Size(375, 667), const Size(390, 844),
    const Size(430, 932), const Size(600, 950), const Size(768, 1024),
    const Size(1024, 768), const Size(720, 390),
  ]) {
    testWidgets('Review responsive scroll, photo ratio, buttons and nav at $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(home: SiteReportWizardScreen(
        initial: _completeReviewFixture(
          title: 'Site Report - Week 3 with a long additional title for the job'),
      )));
      await _openReview(tester);
      final scroll = find.byKey(const Key('site-report-wizard-scroll'));
      final nav = find.byType(Sign2DigitalBottomNavigationBar);
      expect(tester.getBottomRight(scroll).dy,
        lessThanOrEqualTo(tester.getTopLeft(nav).dy + 1));
      final cover = find.byKey(const Key('review-report-cover'));
      final actual = tester.getSize(cover);
      expect(actual.width / actual.height, closeTo(390/182, 0.08));
      await tester.ensureVisible(find.byKey(const Key('site-report-next')));
      await tester.pump();
      expect(find.byKey(const Key('site-report-content-back')), findsOneWidget);
      expect(tester.takeException(), isNull, reason: '$size');
    });
  }

  testWidgets('Figma Details step, shared fields, initial section selection and nav',
      (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: SiteReportWizardScreen()));
    expect(find.text('Site Reports'), findsOneWidget);
    expect(find.text('Report Title'), findsOneWidget);
    expect(find.text('Report Date'), findsOneWidget);
    expect(find.text('Prepared By'), findsOneWidget);
    expect(find.text('Weather Condition'), findsOneWidget);
    expect(find.text('Report Sections'), findsOneWidget);
    expect(find.byKey(const Key('site-report-stepper')), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      expect(find.byKey(Key('wizard-step-$i')), findsOneWidget);
    }
    final checkboxes = SiteReportSection.values;
    expect(checkboxes.length, 6);
    for (var i = 0; i < checkboxes.length; i++) {
      final checked = tester.widget<Sign2DigitalCheckbox>(
        find.byKey(Key('site-report-section-$i')),
      );
      expect(checked.boxSize, 16);
      expect(checked.value, i == 0 || i == 2 || i == 4);
      expect(find.text(checkboxes[i].label), findsOneWidget);
    }
    final nav = tester.widget<Sign2DigitalBottomNavigationBar>(
      find.byType(Sign2DigitalBottomNavigationBar),
    );
    expect(nav.selectedIndex, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Next validates, selected content stays active, back preserves values',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SiteReportWizardScreen()));
    await tester.ensureVisible(find.byKey(const Key('site-report-next')));
    await tester.tap(find.byKey(const Key('site-report-next')));
    await tester.pump();
    expect(find.text('Choose a report title.'), findsOneWidget);
    expect(find.text('Site Programs'), findsNothing);

    await _details(tester);
    await tester.ensureVisible(find.byKey(const Key('site-report-next')));
    await tester.tap(find.byKey(const Key('site-report-next')));
    await tester.pump();
    expect(find.text('Site Programs'), findsOneWidget);
    expect(find.byKey(const Key('wizard-step-1')), findsOneWidget);
    expect(find.byKey(const Key('site-report-content-siteProgress')),
      findsOneWidget);
    expect(find.byKey(const Key('site-report-content-notes')),
      findsOneWidget);
    expect(find.byKey(const Key('site-report-content-materials')),
      findsOneWidget);
    expect(find.byKey(const Key('site-report-content-issues')), findsNothing);
    // Upload stays available even if Photos was not selected in Details.
    expect(find.byKey(const Key('site-report-add-photos')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('site-report-next')));
    await tester.tap(find.byKey(const Key('site-report-next')));
    await tester.pump();
    expect(find.text('Complete the Site Progress section.'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pump();
    expect(find.text('Prepared By'), findsOneWidget);
    expect(find.text('Jean Dupont'), findsOneWidget);
    expect(find.text('Sunny'), findsOneWidget);
    expect(find.text('Site Programs'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('checkbox label toggles, Photo upload uses existing source',
      (tester) async {
    await tester.pumpWidget(MaterialApp(home: SiteReportWizardScreen(
      photoSource: _PhotoSource(),
    )));
    await tester.ensureVisible(find.text('Photos'));
    await tester.tap(find.text('Photos'));
    await tester.pump();
    final photosCheckbox = tester.widget<Sign2DigitalCheckbox>(
      find.byKey(const Key('site-report-section-1')));
    expect(photosCheckbox.value, isTrue);
    await _details(tester);
    await tester.ensureVisible(find.byKey(const Key('site-report-next')));
    await tester.tap(find.byKey(const Key('site-report-next')));
    await tester.pump();
    expect(find.byKey(const Key('site-report-add-photos')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('site-report-add-photos')));
    await tester.tap(find.byKey(const Key('site-report-add-photos')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('site-report-gallery')));
    await tester.pump();
    expect(find.byKey(const Key('site-report-photo-0')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Empty Step 2 photos shows only full-width upload tile and saves selection',
      (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: SiteReportWizardScreen(
      initial: _completeReviewFixture(photo: false),
      photoSource: _PhotoSource(),
    )));
    await tester.ensureVisible(find.byKey(const Key('site-report-next')));
    await tester.tap(find.byKey(const Key('site-report-next')));
    await tester.pump();

    final upload = find.byKey(const Key('site-report-add-photos'));
    final grid = find.byKey(const Key('site-report-photo-grid'));
    expect(upload, findsOneWidget);
    expect(grid, findsOneWidget);
    expect(find.byKey(const Key('site-report-photo-0')), findsNothing);
    expect(tester.getSize(upload).width,
      closeTo(tester.getSize(grid).width, 1));
    await tester.ensureVisible(upload);
    await tester.tap(upload);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('site-report-gallery')));
    await tester.pump();
    expect(find.byKey(const Key('site-report-photo-0')), findsOneWidget);
    expect(find.byKey(const Key('site-report-add-photos')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('site-report-content-back')));
    await tester.tap(find.byKey(const Key('site-report-content-back')));
    await tester.pump();
    final photos = tester.widget<Sign2DigitalCheckbox>(
      find.byKey(const Key('site-report-section-1')));
    expect(photos.value, isTrue,
        reason: 'Uploading should select the Photos section automatically');

    await tester.ensureVisible(find.byKey(const Key('site-report-next')));
    await tester.tap(find.byKey(const Key('site-report-next')));
    await tester.pump();
    final preview = find.byKey(const Key('site-report-photo-0'));
    await tester.ensureVisible(preview);
    await tester.tap(find.descendant(
      of: preview, matching: find.byType(IconButton)));
    await tester.pump();
    expect(find.byKey(const Key('site-report-photo-0')), findsNothing);
    expect(find.byKey(const Key('site-report-add-photos')), findsOneWidget);
    expect(tester.getSize(find.byKey(const Key('site-report-add-photos'))).width,
      closeTo(tester.getSize(find.byKey(const Key('site-report-photo-grid'))).width, 1));
    expect(tester.takeException(), isNull);
  });

  for (final size in [
    const Size(320, 650),
    const Size(430, 932),
    const Size(768, 1024),
  ]) {
    testWidgets('Step 3 displays all 3 selected photos without clipping at $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(home: SiteReportWizardScreen(
        initial: _figmaContentFixture(),
      )));
      await _openReview(tester);
      expect(find.text('Review Reports'), findsOneWidget);
      expect(find.byKey(const Key('review-report-photo-grid')), findsOneWidget);
      for (var i = 0; i < 3; i++) {
        expect(find.byKey(Key('review-report-photo-$i')), findsOneWidget);
      }
      expect(find.byKey(const Key('review-report-cover-image')), findsOneWidget);
      expect(find.byKey(const Key('review-report-photo-image-1')),
        findsOneWidget);
      expect(find.byKey(const Key('review-report-photo-image-2')),
        findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const Key('review-report-photo-2')));
      await tester.pump();
      final gallery = find.byKey(const Key('review-report-photo-grid'));
      final image = find.byKey(const Key('review-report-photo-2'));
      expect(tester.getBottomRight(image).dy,
        lessThanOrEqualTo(tester.getBottomRight(gallery).dy + 1));
      expect(tester.takeException(), isNull, reason: '$size');
    });
  }

  testWidgets('Content matches Figma structure and photo grid at 430dp',
      (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: SiteReportWizardScreen(
      initial: _figmaContentFixture(),
    )));
    await tester.ensureVisible(find.byKey(const Key('site-report-next')));
    await tester.tap(find.byKey(const Key('site-report-next')));
    await tester.pump();

    expect(find.text('Site Programs'), findsOneWidget);
    expect(find.text('Photos'), findsOneWidget);
    expect(find.text('Notes & Observations'), findsOneWidget);
    expect(find.text('Issues & Risks'), findsOneWidget);
    expect(find.byKey(const Key('site-report-photo-grid')), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      expect(find.byKey(Key('site-report-photo-$i')), findsOneWidget);
    }
    expect(find.byKey(const Key('site-report-add-photos')), findsOneWidget);
    expect(find.byKey(const Key('site-report-content-materials')), findsNothing);
    expect(find.byKey(const Key('wizard-connector-0')), findsOneWidget);
    expect(find.byKey(const Key('wizard-connector-1')), findsOneWidget);
    expect(find.byKey(const Key('site-report-content-back')), findsOneWidget);
    expect(find.byKey(const Key('site-report-next')), findsOneWidget);
    final stepper = tester.widgetList<Container>(find.descendant(
      of: find.byKey(const Key('site-report-stepper')),
      matching: find.byType(Container),
    ));
    expect(stepper, isNotEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Content editing, risk selection and photo removal persist on Back',
      (tester) async {
    await tester.pumpWidget(MaterialApp(home: SiteReportWizardScreen(
      initial: _figmaContentFixture(), photoSource: _PhotoSource(),
    )));
    await tester.ensureVisible(find.byKey(const Key('site-report-next')));
    await tester.tap(find.byKey(const Key('site-report-next')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('site-report-content-siteProgress')),
      'Updated site progress',
    );
    await tester.ensureVisible(find.byKey(const Key('site-report-content-issues')));
    await tester.tap(find.byKey(const Key('site-report-content-issues')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('site-report-risk-option-4')));
    await tester.pumpAndSettle();
    expect(find.text('Quality issue'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('site-report-photo-1')));
    final preview = find.byKey(const Key('site-report-photo-1'));
    final remove = find.descendant(
      of: preview, matching: find.byType(IconButton));
    await tester.tap(remove);
    await tester.pump();
    expect(find.byKey(const Key('site-report-photo-2')), findsNothing);
    expect(find.byKey(const Key('site-report-photo-1')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('site-report-content-back')));
    await tester.tap(find.byKey(const Key('site-report-content-back')));
    await tester.pump();
    expect(find.text('Prepared By'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('site-report-next')));
    await tester.tap(find.byKey(const Key('site-report-next')));
    await tester.pump();
    final field = tester.widget<TextFormField>(
      find.byKey(const Key('site-report-content-siteProgress')));
    expect(field.controller!.text, 'Updated site progress');
    expect(find.text('Quality issue'), findsOneWidget);
    expect(find.byKey(const Key('site-report-photo-1')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('site-report-next')));
    await tester.tap(find.byKey(const Key('site-report-next')));
    await tester.pump();
    expect(find.text('Review Reports'), findsOneWidget);
    expect(find.byKey(const Key('review-report-cover-image')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('site-report-content-back')));
    await tester.tap(find.byKey(const Key('site-report-content-back')));
    await tester.pump();
    final retained = tester.widget<TextFormField>(
      find.byKey(const Key('site-report-content-siteProgress')));
    expect(retained.controller!.text, 'Updated site progress');
    expect(find.text('Quality issue'), findsOneWidget);
    expect(find.byKey(const Key('site-report-photo-1')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final size in [
    const Size(320, 650),
    const Size(375, 667),
    const Size(430, 932),
    const Size(720, 390),
    const Size(1024, 768),
  ]) {
    testWidgets('Content photo grid and Back/Next remain usable at $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(home: SiteReportWizardScreen(
        initial: _figmaContentFixture(),
      )));
      await tester.ensureVisible(find.byKey(const Key('site-report-next')));
      await tester.tap(find.byKey(const Key('site-report-next')));
      await tester.pump();
      expect(find.byKey(const Key('site-report-photo-grid')), findsOneWidget);
      expect(find.byKey(const Key('site-report-photo-0')), findsOneWidget);
      final nav = find.byType(Sign2DigitalBottomNavigationBar);
      final scroll = find.byKey(const Key('site-report-wizard-scroll'));
      expect(tester.getBottomRight(scroll).dy,
        lessThanOrEqualTo(tester.getTopLeft(nav).dy + 1));
      await tester.ensureVisible(find.byKey(const Key('site-report-content-back')));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: '$size');
    });
  }

  testWidgets('Review and persisted Details reflect actual entered draft data',
      (tester) async {
    final previous = DocumentRecord(
      id: 'local-site-123',
      category: DocumentCategory.reports,
      reportKind: ReportKind.siteReport,
      number: 'SR-LOCAL-123',
      title: 'Site Inspection',
      project: 'Existing job',
      customer: 'Existing customer',
      timestamp: DateTime(2026, 8, 1),
      status: 'Draft',
      demoOnly: true,
      siteReportDetails: SiteReportDetails(
        reportDate: DateTime(2026, 8, 25),
        preparedBy: 'Original preparer',
        weatherCondition: 'Cloudy',
        selectedSections: const [SiteReportSection.siteProgress],
        sectionContent: const {
          SiteReportSection.siteProgress: 'Verified progress description',
        },
      ),
    );
    await tester.pumpWidget(MaterialApp(home: SiteReportWizardScreen(
      initial: previous,
    )));
    expect(find.text('Original preparer'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('site-report-next')));
    await tester.tap(find.byKey(const Key('site-report-next')));
    await tester.pump();
    expect(find.text('Verified progress description'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('site-report-next')));
    await tester.tap(find.byKey(const Key('site-report-next')));
    await tester.pump();
    expect(find.text('Review Reports'), findsOneWidget);
    expect(find.byKey(const Key('review-report-title')), findsOneWidget);
    expect(find.text('Site Inspection'), findsOneWidget);
    expect(find.text('Original preparer'), findsOneWidget);
    expect(find.text('Existing job'), findsOneWidget);
    expect(find.text('Existing customer'), findsOneWidget);
    expect(find.text('August 25, 2026'), findsOneWidget);
    expect(find.byKey(const Key('review-report-info')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('site-report-content-back')));
    await tester.tap(find.byKey(const Key('site-report-content-back')));
    await tester.pump();
    expect(find.text('Verified progress description'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final size in [
    const Size(320, 650),
    const Size(375, 667),
    const Size(430, 932),
    const Size(720, 390),
    const Size(1024, 768),
  ]) {
    testWidgets('Details form is scrollable and navigation stays fixed at $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const MaterialApp(home: SiteReportWizardScreen()));
      final nav = find.byType(Sign2DigitalBottomNavigationBar);
      final scroll = find.byKey(const Key('site-report-wizard-scroll'));
      expect(tester.getBottomRight(scroll).dy,
        lessThanOrEqualTo(tester.getTopLeft(nav).dy + 1));
      await tester.ensureVisible(find.byKey(const Key('site-report-next')));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: '$size');
    });
  }
}
