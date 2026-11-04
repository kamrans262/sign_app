import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sign2digital/core/services/active_company_session.dart';
import 'package:sign2digital/core/services/sign_api_client.dart';
import 'package:sign2digital/features/documents/data/remote_site_report_repository.dart';
import 'package:sign2digital/features/documents/domain/document_record.dart';

Map<String, dynamic> report({
  String kind = 'site_report',
  String status = 'draft',
  int? managedDocumentId,
}) => {
  'id': 21, 'company_id': 7, 'job_id': 34,
  'client_id': 4, 'number': 'SR-00000021',
  'kind': kind, 'title': 'Site visit - Week 1',
  'project': 'New glazing', 'customer': 'Jean Client',
  'report_date': '2026-11-04',
  'prepared_by': 'Site Inspector', 'location': 'Client property',
  'weather': 'Sunny', 'status': status, 'revision': 1,
  'managed_document_id': managedDocumentId,
  'created_at': '2026-11-04T12:00:00Z',
  'updated_at': '2026-11-04T12:00:00Z',
  'photo_ids': <int>[],
  'content': kind == 'site_report'
      ? {'sections': {'siteProgress': 'Windows checked'}}
      : {'sections': {'summary': 'Discussed glazing'},
         'attendees': ['Jean Client'], 'absentees': <String>[],
         'decisions': ['Replace one pane'],
         'next_steps': ['Order glass'],
         'outstanding_points': ['Approve supplier selection'],
         'action_items': [{'description': 'Contact supplier',
             'assignee': 'Inspector', 'due_date': '2026-11-12'}]},
};

void main() {
  setUp(() => ActiveCompanySession.set(7));
  tearDown(() => ActiveCompanySession.clear());

  SignApiClient client(Future<http.Response> Function(http.Request) handler) =>
      SignApiClient(
        baseUrl: Uri.parse('https://api.test'),
        tokenProvider: () async => 'm12-test-token',
        activeCompanyId: () => ActiveCompanySession.companyId,
        httpClient: MockClient(handler),
      );

  test('site report list is authenticated and scoped to selected company', () async {
    final api = client((req) async {
      expect(req.headers['Authorization'], 'Bearer m12-test-token');
      expect(req.headers['X-Company-Id'], '7');
      expect(req.url.path, '/api/v1/reports');
      return http.Response(jsonEncode({'data': {
        'reports': [report()], 'last_page': 1, 'page': 1,
      }}), 200, headers: {'content-type': 'application/json'});
    });
    final records = await RemoteSiteReportRepository(api: api).listDocuments();
    expect(records.single.id, 'report-21');
    expect(records.single.reportKind, ReportKind.siteReport);
    expect(records.single.siteReportDetails!.sectionContent[
        SiteReportSection.siteProgress], 'Windows checked');
    api.dispose();
  });

  test('meeting minutes parsing preserves actions and decisions', () async {
    final api = client((req) async => http.Response(jsonEncode({
      'data': {'reports': [report(kind: 'meeting_minutes')],
          'last_page': 1, 'page': 1},
    }), 200));
    final records = await RemoteSiteReportRepository(api: api).listDocuments();
    expect(records.single.reportKind, ReportKind.meetingMinutes);
    expect(records.single.meetingMinutesDetails!.attendees, ['Jean Client']);
    expect(records.single.meetingMinutesDetails!.decisions, ['Replace one pane']);
    expect(records.single.meetingMinutesDetails!.actionItems, ['Contact supplier']);
    expect(records.single.meetingMinutesDetails!.outstandingPoints,
        ['Approve supplier selection']);
    expect(records.single.meetingMinutesDetails!.actionDetails.single.assignee,
        'Inspector');
    expect(records.single.meetingMinutesDetails!.actionDetails.single.dueDate,
        DateTime(2026,11,12));
    api.dispose();
  });

  test('approved PDF identity requires linked verified M9 document', () async {
    final api = client((req) async => http.Response(jsonEncode({
      'data': {'reports': [report(status: 'approved')],
          'last_page': 1},
    }), 200));
    await expectLater(
      RemoteSiteReportRepository(api: api).listDocuments(),
      throwsA(isA<SignApiException>()),
    );
    api.dispose();
  });

  test('report AI result must remain draft-only until approved explicitly', () async {
    final api = client((req) async {
      expect(req.method, 'POST');
      expect(req.url.path, '/api/v1/reports/21/prepare-ai');
      expect(req.headers['X-Company-Id'], '7');
      return http.Response(jsonEncode({'data': {'suggestion': {
        'title': 'Updated report',
        'sections': {'siteProgress': 'Windows checked'},
        'revision': 1, 'approved': false, 'applied': false,
      }}}), 200);
    });
    final draft = DocumentRecord(
      id: 'report-21', category: DocumentCategory.reports,
      number: 'SR-00000021', title: 'Site visit - Week 1',
      project: 'New glazing', customer: 'Jean Client',
      timestamp: DateTime(2026,11,4), status: 'draft', version: 1,
      jobId: '34', reportKind: ReportKind.siteReport,
    );
    final suggestion = await RemoteSiteReportRepository(api: api).suggestAi(draft);
    expect(suggestion['approved'], false);
    expect(suggestion['applied'], false);
    api.dispose();
  });
}
