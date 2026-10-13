import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/core/widgets/sign2digital_bottom_navigation_bar.dart';
import 'package:sign2digital/core/widgets/sign2digital_checkbox.dart';
import 'package:sign2digital/features/documents/data/demo_report_repository.dart';
import 'package:sign2digital/features/documents/domain/document_record.dart';
import 'package:sign2digital/features/documents/presentation/screens/site_report_wizard_screen.dart';
import 'package:sign2digital/features/jobs/data/local_job_photo_source.dart';

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
  await tester.tap(find.byKey(const Key('site-report-title')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('site-report-title-option-0')));
  await tester.pumpAndSettle();
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

void main() {
  setUp(DemoReportDraftSession.clear);

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
    expect(find.byKey(const Key('site-report-add-photos')), findsNothing);

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
    expect(find.text('Review Site Report'), findsOneWidget);
    expect(find.text('Updated site progress'), findsOneWidget);
    expect(find.text('Quality issue'), findsOneWidget);
    expect(find.text('photo-0.png, photo-2.png'), findsOneWidget);
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
    expect(find.text('Review Site Report'), findsOneWidget);
    expect(find.text('Site Inspection'), findsOneWidget);
    expect(find.text('Original preparer'), findsOneWidget);
    expect(find.text('Cloudy'), findsOneWidget);
    expect(find.text('Verified progress description'), findsOneWidget);
    expect(find.byKey(const Key('site-report-demo-notice')), findsOneWidget);
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
