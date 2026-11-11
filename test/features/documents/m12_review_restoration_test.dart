import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sign2digital/core/services/active_company_session.dart';
import 'package:sign2digital/core/services/sign_api_client.dart';
import 'package:sign2digital/features/documents/data/remote_site_report_repository.dart';
import 'package:sign2digital/features/documents/domain/document_record.dart';
import 'package:sign2digital/features/documents/presentation/screens/report_review_screen.dart';
import 'package:sign2digital/features/documents/presentation/screens/site_report_wizard_screen.dart';
import 'package:sign2digital/features/documents/presentation/widgets/site_report_review_content.dart';

DocumentRecord _fixture() => DocumentRecord(
  id: 'report-4', category: DocumentCategory.reports,
  reportKind: ReportKind.siteReport, number: 'SR-4',
  title: 'Custom safety inspection', project: 'Roof restoration',
  customer: 'Test client', jobId: '3', version: 2,
  timestamp: DateTime(2026, 11, 12), status: 'draft',
  siteReportDetails: SiteReportDetails(
    reportDate: DateTime(2026, 11, 12),
    preparedBy: 'Reviewer', weatherCondition: 'Other: Fog and poor visibility',
    location: 'Roof area', selectedSections: const [
      SiteReportSection.siteProgress,
      SiteReportSection.notes,
      SiteReportSection.issues,
    ],
    sectionContent: const {
      SiteReportSection.siteProgress: 'Roof installation 50 percent',
      SiteReportSection.notes: 'Inspected waterproof coating',
      SiteReportSection.issues: 'Other: Fall risk at north edge',
    },
    attendees: const ['A', 'B'],
    actionItems: [
      MeetingActionItem(description: 'Secure the ladder',
        assignee: 'Original owner', dueDate: DateTime(2026, 12, 1)),
    ],
  ),
);

Map<String, dynamic> _response(String status) => {
  'id': 4, 'company_id': 5, 'client_id': 6, 'job_id': 3,
  'kind': 'site_report', 'number': 'SR-4',
  'title': 'Custom safety inspection', 'report_date': '2026-11-12',
  'prepared_by': 'Reviewer', 'weather': 'Other: Fog and poor visibility',
  'location': 'Roof area', 'project': 'Roof restoration',
  'customer': 'Test client', 'status': status, 'revision': 2,
  'managed_document_id': status == 'draft' ? null : 15,
  'created_at': '2026-11-12T00:00:00Z',
  'updated_at': '2026-11-12T00:00:00Z',
  'photo_ids': <int>[],
  'content': {
    'sections': {
      'siteProgress': 'Roof installation 50 percent',
      'notes': 'Inspected waterproof coating',
      'issues': 'Other: Fall risk at north edge',
    },
    'attendees': ['A', 'B'],
    'action_items': [
      {'description': 'Secure the ladder',
       'assignee': 'Original owner', 'due_date': '2026-12-01'},
    ],
  },
};

RemoteSiteReportRepository _repository(String status) {
  final api = SignApiClient(
    baseUrl: Uri.parse('https://example.test'),
    tokenProvider: () async => 'test-token',
    activeCompanyId: () => ActiveCompanySession.companyId,
    httpClient: MockClient((request) async => http.Response(
      jsonEncode({'data': {
        'report': _response(status),
        'photos': <Map<String, dynamic>>[],
        'events': <Map<String, dynamic>>[],
        'revisions': <Map<String, dynamic>>[],
      }}), 200)),
  );
  return RemoteSiteReportRepository(api: api);
}

void main() {
  setUp(() => ActiveCompanySession.set(5));
  tearDown(ActiveCompanySession.clear);

  testWidgets('saved and creation reviews share the approved cover and data components',
      (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body:
      SingleChildScrollView(child: SiteReportReviewContent(report: _fixture())),
    )));
    expect(find.byKey(const Key('review-report-cover')), findsOneWidget);
    expect(find.byKey(const Key('review-reports-body')), findsOneWidget);
    expect(find.text('Custom safety inspection'), findsOneWidget);
    expect(find.text('Other: Fog and poor visibility'), findsOneWidget);
    expect(find.text('Other: Fall risk at north edge'), findsOneWidget);
    expect(find.text('Secure the ladder • Owner: Original owner • Due: December 1, 2026'),
      findsOneWidget);
    expect(find.text('Roof installation 50 percent'), findsOneWidget);
    expect(find.byKey(const Key('review-report-info')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final status in ['draft', 'approved', 'sent', 'archived']) {
    testWidgets('server $status displays correct review and approval actions',
        (tester) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(home: ReportReviewScreen(
        report: _fixture(), repository: _repository(status),
      )));
      await tester.pumpAndSettle();
      expect(find.byType(SiteReportReviewContent), findsOneWidget);
      expect(find.text('Custom safety inspection'), findsOneWidget);
      if (status == 'draft') {
        expect(find.text('Edit Draft'), findsOneWidget);
        expect(find.text('Prepare with AI'), findsOneWidget);
        expect(find.text('Approve Report'), findsOneWidget);
        expect(find.text('Archive Report'), findsOneWidget);
        final edit = find.text('Edit Draft');
        final ai = find.text('Prepare with AI');
        final approve = find.text('Approve Report');
        final archive = find.text('Archive Report');
        expect((tester.getTopLeft(edit).dy - tester.getTopLeft(ai).dy).abs(),
          lessThan(5));
        expect((tester.getTopLeft(approve).dy - tester.getTopLeft(archive).dy).abs(),
          lessThan(5));
        expect(tester.getTopLeft(approve).dy, greaterThan(tester.getTopLeft(edit).dy));
      } else if (status == 'archived') {
        expect(find.text('Edit Draft'), findsNothing);
        expect(find.text('Already Approved'), findsNothing);
        expect(find.text('View Approved PDF'), findsOneWidget);
      } else {
        expect(find.text('Edit Draft'), findsNothing);
        expect(find.text('Approve Report'), findsNothing);
        expect(find.text('Already Approved'), findsOneWidget);
        final button = tester.widget<FilledButton>(find.ancestor(
          of: find.text('Already Approved'), matching: find.byType(FilledButton)));
        expect(button.onPressed, isNull);
        expect(find.text('View Approved PDF'), findsOneWidget);
        expect(find.text('Send to Client'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('existing Other condition and risk are restored as editable inputs',
      (tester) async {
    await tester.pumpWidget(MaterialApp(home:
      SiteReportWizardScreen(initial: _fixture())));
    expect(find.byKey(const Key('site-report-custom-title')), findsOneWidget);
    expect(find.byKey(const Key('site-report-other-condition')), findsOneWidget);
    expect(find.text('Fog and poor visibility'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('site-report-next')));
    await tester.tap(find.byKey(const Key('site-report-next')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('site-report-other-risk')), findsOneWidget);
    expect(find.text('Fall risk at north edge'), findsOneWidget);
    expect(find.textContaining('one per line'), findsNothing);
    expect(find.textContaining('Task Owner'), findsNothing);
    expect(find.textContaining('YYYY-MM-DD'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
