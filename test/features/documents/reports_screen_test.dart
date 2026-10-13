import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/core/widgets/sign2digital_bottom_navigation_bar.dart';
import 'package:sign2digital/core/widgets/sign2digital_dashboard_header.dart';
import 'package:sign2digital/features/clients/presentation/screens/clients_screen.dart';
import 'package:sign2digital/features/clients/presentation/widgets/sign2digital_status_badge.dart';
import 'package:sign2digital/features/documents/data/demo_report_repository.dart';
import 'package:sign2digital/features/documents/domain/document_record.dart';
import 'package:sign2digital/features/documents/presentation/screens/document_details_screen.dart';
import 'package:sign2digital/features/documents/presentation/screens/reports_screen.dart';
import 'package:sign2digital/features/quotes/presentation/widgets/sign2digital_quote_summary_card.dart';

class _FakeReportRepository implements DocumentRepository {
  _FakeReportRepository(this.load);
  final Future<List<DocumentRecord>> Function() load;
  @override
  Future<List<DocumentRecord>> listDocuments() => load();
}

void main() {
  setUp(DemoReportDraftSession.clear);

  test('sample reports have unique identifiers and real report categories', () async {
    final reports = await const DemoReportRepository().listDocuments();
    expect(reports.length, 6);
    expect(reports.take(5).map((r) => r.title).toSet(),
      {'Site Report- Week 3'});
    expect(reports.take(5).map((r) => r.status).toList(),
      ['Completed', 'Completed', 'Draft', 'Draft', 'Completed']);
    expect(reports.map((r) => r.id).toSet().length, 6);
    expect(reports.last.reportKind, ReportKind.workAcceptance);
    expect(reports.every((r) => r.demoOnly), isTrue);
    expect(reports.every((r) => r.category == DocumentCategory.reports), isTrue);
    expect(reports.last.matches('work acceptance'), isTrue);
  });

  testWidgets('client route reuses global header, nav, search, tabs and cards',
      (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: ClientsScreen()));
    await tester.tap(find.byKey(const Key('open-reports')));
    await tester.pumpAndSettle();
    expect(find.byType(ReportsScreen), findsOneWidget);
    expect(find.byType(Sign2DigitalDashboardHeader), findsOneWidget);
    expect(find.text('Search documents'), findsOneWidget);
    expect(find.text('All Report'), findsOneWidget);
    expect(find.text('Site Report'), findsOneWidget);
    expect(find.text('Work acceptance'), findsOneWidget);
    expect(find.byType(Sign2DigitalQuoteSummaryCard), findsWidgets);
    final nav = tester.widget<Sign2DigitalBottomNavigationBar>(
      find.byType(Sign2DigitalBottomNavigationBar));
    expect(nav.selectedIndex, 2);
    expect(find.byKey(const Key('reports-create-button')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('category selection and searching operate together',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ReportsScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('details-tab-2')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('report-card-report-demo-work-acceptance-1')),
      findsOneWidget);
    expect(find.text('Site Report- Week 3'), findsNothing);
    await tester.enterText(find.byKey(const Key('clients-search-input')),
      'not matched');
    await tester.pump();
    expect(find.text('No reports match your search'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('clients-search-input')),
      'kitchen');
    await tester.pump();
    expect(find.byKey(const Key('report-card-report-demo-work-acceptance-1')),
      findsOneWidget);
    await tester.tap(find.byKey(const Key('details-tab-1')));
    await tester.pumpAndSettle();
    expect(find.text('Site Report- Week 3'), findsWidgets);
    expect(find.text('Work acceptance- Kitchen renovation'), findsNothing);
    await tester.tap(find.byKey(const Key('details-tab-0')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('reports-scroll')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('report badge stays right of title, chevron centered, cards 20px apart',
      (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: ReportsScreen()));
    await tester.pumpAndSettle();
    final first = find.byKey(const Key('report-card-report-figma-site-1'));
    final second = find.byKey(const Key('report-card-report-figma-site-2'));
    expect(first, findsOneWidget);
    expect(second, findsOneWidget);
    expect(tester.getTopLeft(second).dy - tester.getBottomLeft(first).dy,
      closeTo(20, 0.01));
    final badge = find.descendant(of: first, matching:
      find.byType(Sign2DigitalStatusBadge));
    expect(badge, findsOneWidget);
    expect(tester.widget<Sign2DigitalStatusBadge>(badge).status, 'Completed');
    final badgeContainer = tester.widget<Container>(
      find.descendant(of: badge, matching: find.byType(Container)));
    expect(badgeContainer.padding,
      const EdgeInsets.symmetric(horizontal: 10, vertical: 4));
    final card = tester.widget<Sign2DigitalQuoteSummaryCard>(first);
    expect(card.listStyle, isTrue);
    final title = find.text('Site Report- Week 3').first;
    expect(tester.getTopLeft(badge).dy,
      closeTo(tester.getTopLeft(title).dy, 10));
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping Completed fixture opens matching report details',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ReportsScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('report-card-report-figma-site-1')));
    await tester.pumpAndSettle();
    expect(find.byType(DocumentDetailsScreen), findsOneWidget);
    final details = tester.widget<DocumentDetailsScreen>(
      find.byType(DocumentDetailsScreen));
    expect(details.documentId, 'report-figma-site-1');
    expect(details.document?.category, DocumentCategory.reports);
    expect(details.document?.status, 'Completed');
    expect(find.text('Report Number:'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('floating plus creates genuine session draft and allows editing',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ReportsScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('reports-create-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('create-site-report')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('report-save-draft')));
    await tester.pump();
    expect(find.text('Title, job and customer are required.'), findsOneWidget);
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Site Inspection');
    await tester.enterText(fields.at(1), 'Kitchen extension');
    await tester.enterText(fields.at(2), 'Customer One');
    await tester.ensureVisible(find.byKey(const Key('report-save-draft')));
    await tester.tap(find.byKey(const Key('report-save-draft')));
    await tester.pumpAndSettle();
    expect(DemoReportDraftSession.drafts, hasLength(1));
    final draft = DemoReportDraftSession.drafts.single;
    expect(draft.status, 'Draft');
    expect(draft.reportKind, ReportKind.siteReport);
    expect(draft.title, 'Site Inspection');

    // Search the newly saved record, open for editing rather than a fake PDF.
    await tester.enterText(find.byKey(const Key('clients-search-input')),
      'Site Inspection');
    await tester.pump();
    final draftCard = find.byKey(Key('report-card-${draft.id}'));
    expect(draftCard, findsOneWidget);
    await tester.tap(draftCard);
    await tester.pumpAndSettle();
    expect(find.text('Edit Site Report Draft'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(0), 'Updated inspection');
    await tester.ensureVisible(find.byKey(const Key('report-save-draft')));
    await tester.tap(find.byKey(const Key('report-save-draft')));
    await tester.pumpAndSettle();
    expect(DemoReportDraftSession.find(draft.id)?.title, 'Updated inspection');
    expect(DemoReportDraftSession.drafts, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('loading, retry and empty states use supplied repository',
      (tester) async {
    final first = Completer<List<DocumentRecord>>();
    var calls = 0;
    final repo = _FakeReportRepository(() {
      calls++;
      if (calls == 1) return first.future;
      return Future.value(<DocumentRecord>[]);
    });
    await tester.pumpWidget(MaterialApp(home: ReportsScreen(repository: repo)));
    expect(find.byKey(const Key('reports-loading')), findsOneWidget);
    first.completeError(StateError('offline'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('reports-retry')), findsOneWidget);
    await tester.tap(find.byKey(const Key('reports-retry')));
    await tester.pumpAndSettle();
    expect(find.text('No reports yet'), findsOneWidget);
    expect(calls, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('all viewports preserve scrolling, nav and floating button',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final size in [const Size(320, 650), const Size(375, 667),
      const Size(430, 932), const Size(720, 390),
      const Size(1024, 768)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(const MaterialApp(home: ReportsScreen()));
      await tester.pumpAndSettle();
      final scroll = find.byKey(const Key('reports-scroll'));
      final nav = find.byType(Sign2DigitalBottomNavigationBar);
      final fab = find.byKey(const Key('reports-create-button'));
      expect(tester.getBottomRight(scroll).dy,
        lessThanOrEqualTo(tester.getTopLeft(nav).dy + 1));
      expect(tester.getBottomRight(fab).dy,
        lessThanOrEqualTo(tester.getTopLeft(nav).dy + 1));
      await tester.scrollUntilVisible(
        find.byKey(const Key('report-card-report-figma-site-5')),
        150,
        scrollable: find.descendant(
          of: scroll, matching: find.byType(Scrollable),
        ).first,
      );
      await tester.ensureVisible(find.byKey(
        const Key('report-card-report-figma-site-5')));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: '$size');
    }
  });
}
