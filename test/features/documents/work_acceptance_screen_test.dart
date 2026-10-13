import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/core/theme/app_colors.dart';
import 'package:sign2digital/core/widgets/sign2digital_bottom_navigation_bar.dart';
import 'package:sign2digital/features/documents/data/demo_report_repository.dart';
import 'package:sign2digital/features/documents/domain/document_record.dart';
import 'package:sign2digital/features/documents/domain/work_acceptance_data.dart';
import 'package:sign2digital/features/documents/presentation/screens/reports_screen.dart';
import 'package:sign2digital/features/documents/presentation/screens/work_acceptance_screen.dart';
import 'package:sign2digital/features/documents/presentation/widgets/sign2digital_document_history.dart';
import 'package:sign2digital/features/quotes/presentation/widgets/sign2digital_signature_draw_canvas.dart';

final _signature = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJ'
  'AAAADUlEQVQIHWP4z8DwHwAFgAI/ScL/nwAAAABJRU5ErkJggg==',
);

DocumentRecord _record({
  bool demo = false,
  List<WorkAcceptanceStage> done = const [],
  bool signature = false,
  bool reportPdf = false,
  String name = 'Signer One',
}) {
  return DocumentRecord(
    id: 'wa-test-1',
    category: DocumentCategory.reports,
    reportKind: ReportKind.workAcceptance,
    number: 'WA-TEST-1',
    title: 'Work acceptance – Kitchen renovation',
    project: 'Kitchen renovation',
    customer: name,
    timestamp: DateTime(2026, 8, 12, 10, 15),
    status: done.contains(WorkAcceptanceStage.completed)
        ? 'Completed' : 'Pending',
    demoOnly: demo,
    workAcceptance: WorkAcceptanceEvidence(
      events: [
        for (final stage in done)
          WorkAcceptanceEvent(
            id: 'event-${stage.name}',
            documentId: 'wa-test-1',
            stage: stage,
            actorName: name,
            occurredAt: DateTime(2026, 8, 12, 10, 15),
          ),
      ],
      verifiedSignaturePng: signature ? _signature : null,
      verifiedReportPdf: reportPdf
          ? Uint8List.fromList('%PDF-1.4\n'.codeUnits) : null,
    ),
  );
}

void main() {
  testWidgets('Demo lifecycle is linked from Reports and clearly demo only',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ReportsScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('details-tab-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(
        const Key('report-card-report-demo-work-acceptance-1')));
    await tester.pumpAndSettle();
    expect(find.byType(WorkAcceptanceScreen), findsOneWidget);
    expect(find.text('Work Acceptance'), findsOneWidget);
    expect(find.byKey(const Key('work-acceptance-demo-label')), findsOneWidget);
    expect(find.byType(Sign2DigitalTrackingRow), findsNWidgets(5));
    for (final stage in WorkAcceptanceStage.values) {
      expect(find.byKey(Key('work-acceptance-stage-${stage.name}')),
        findsOneWidget);
      expect(find.text(stage.label), findsOneWidget);
    }
    expect(find.byKey(const Key('work-acceptance-saved-signature')),
        findsNothing);
    final nav = tester.widget<Sign2DigitalBottomNavigationBar>(
      find.byType(Sign2DigitalBottomNavigationBar));
    expect(nav.selectedIndex, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Partial real events remain pending with no fictitious dates',
      (tester) async {
    await tester.pumpWidget(MaterialApp(home: WorkAcceptanceScreen(
      report: _record(done: const [
        WorkAcceptanceStage.workCompleted, WorkAcceptanceStage.clientNotified,
        WorkAcceptanceStage.clientSigned, WorkAcceptanceStage.completed,
      ]),
    )));
    expect(find.text('Pending'), findsNWidgets(3));
    expect(find.text('Marked by Signer One'), findsNWidgets(2));
    final signed = tester.widget<Sign2DigitalTrackingRow>(
        find.descendant(
          of: find.byKey(const Key('work-acceptance-stage-clientSigned')),
          matching: find.byType(Sign2DigitalTrackingRow),
        ));
    expect(signed.completed, isFalse);
    final completed = tester.widget<Sign2DigitalTrackingRow>(
        find.descendant(
          of: find.byKey(const Key('work-acceptance-stage-completed')),
          matching: find.byType(Sign2DigitalTrackingRow),
        ));
    expect(completed.completed, isFalse);
    expect(find.byKey(const Key('work-acceptance-demo-label')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Events use real timestamps, icon size and borderless spacing',
      (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: WorkAcceptanceScreen(
      report: _record(done: WorkAcceptanceStage.values.toList(),
          signature: true, reportPdf: true),
    )));
    expect(find.byType(Sign2DigitalTrackingRow), findsNWidgets(5));
    final first = find.byKey(const Key('work-acceptance-stage-workCompleted'));
    final second = find.byKey(const Key('work-acceptance-stage-clientNotified'));
    expect(tester.getTopLeft(second).dy - tester.getBottomLeft(first).dy,
      closeTo(20, 0.05));
    final icon = find.descendant(of: first,
        matching: find.byKey(const Key('work-acceptance-stage-icon')));
    expect(tester.getSize(icon), const Size(30, 30));
    final decorated = tester.widget<Container>(icon);
    expect((decorated.decoration as BoxDecoration).color, AppColors.primary);
    expect(find.text('Wed, 12 Aug 2026, 10:15 AM'), findsNWidgets(5));
    expect(find.text('Marked by Signer One'), findsNWidgets(5));
    final signature = find.byType(Sign2DigitalSignatureDisplay);
    expect(signature, findsOneWidget);
    expect(find.byKey(const Key('work-acceptance-saved-signature')),
      findsOneWidget);
    final image = tester.widget<Image>(
        find.byKey(const Key('work-acceptance-saved-signature')));
    expect(image.fit, BoxFit.contain);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Absent verified PDF gives a clear message and never shares',
      (tester) async {
    var shareCalls = 0;
    await tester.pumpWidget(MaterialApp(home: WorkAcceptanceScreen(
      report: _record(demo: true, done: WorkAcceptanceStage.values.toList(),
          reportPdf: true),
      onShareReport: (_) async { shareCalls++; },
    )));
    await tester.ensureVisible(find.byKey(const Key('work-acceptance-share')));
    await tester.tap(find.byKey(const Key('work-acceptance-share')));
    await tester.pump();
    expect(shareCalls, 0);
    expect(find.textContaining('not available to share'), findsOneWidget);
    await tester.ensureVisible(find.byKey(
      const Key('work-acceptance-view-report')));
    await tester.tap(find.byKey(const Key('work-acceptance-view-report')));
    await tester.pump();
    expect(find.textContaining('not available to view'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Share and report viewer callbacks receive the correct record',
      (tester) async {
    final calls = <String>[];
    final record = _record(done: WorkAcceptanceStage.values.toList(),
      signature: true, reportPdf: true);
    await tester.pumpWidget(MaterialApp(home: WorkAcceptanceScreen(
      report: record,
      onShareReport: (r) async => calls.add('share:${r.id}'),
      onViewReport: (r) async => calls.add('view:${r.id}'),
    )));
    await tester.ensureVisible(find.byKey(const Key('work-acceptance-share')));
    await tester.tap(find.byKey(const Key('work-acceptance-share')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('work-acceptance-view-report')));
    await tester.pump();
    expect(calls, ['share:wa-test-1', 'view:wa-test-1']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Back button returns to the selected Reports screen',
      (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: Builder(builder: (context) => TextButton(
        onPressed: () => Navigator.of(context).push<void>(
          MaterialPageRoute(builder: (_) => WorkAcceptanceScreen(
            report: _record())),
        ),
        child: const Text('Open work acceptance'),
      )),
    )));
    await tester.tap(find.text('Open work acceptance'));
    await tester.pumpAndSettle();
    expect(find.byType(WorkAcceptanceScreen), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pumpAndSettle();
    expect(find.byType(WorkAcceptanceScreen), findsNothing);
    expect(find.text('Open work acceptance'), findsOneWidget);
  });

  for (final size in [
    const Size(320, 650), const Size(375, 667),
    const Size(390, 844), const Size(430, 932),
    const Size(600, 900), const Size(768, 1024),
    const Size(1024, 768), const Size(720, 390),
  ]) {
    testWidgets('Responsive tracking, signature and action row at $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(home: WorkAcceptanceScreen(
        report: _record(done: const [WorkAcceptanceStage.workCompleted],
          name: 'An unusually long name for a client signer that wraps'),
      )));
      final scroll = find.byKey(const Key('work-acceptance-scroll'));
      final nav = find.byType(Sign2DigitalBottomNavigationBar);
      expect(tester.getBottomLeft(scroll).dy,
          lessThanOrEqualTo(tester.getTopLeft(nav).dy + 1));
      await tester.ensureVisible(find.byKey(
        const Key('work-acceptance-view-report')));
      await tester.pump();
      final signature = tester.getSize(find.byKey(
        const Key('work-acceptance-signature-panel')));
      expect(signature.height, lessThanOrEqualTo(216.1));
      expect(tester.takeException(), isNull, reason: '$size');
    });
  }
}
