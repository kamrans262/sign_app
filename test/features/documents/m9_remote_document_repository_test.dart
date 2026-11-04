import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:sign2digital/core/services/active_company_session.dart';
import 'package:sign2digital/core/services/sign_api_client.dart';
import 'package:sign2digital/features/documents/data/remote_document_repository.dart';
import 'package:sign2digital/features/documents/domain/document_record.dart';

void main() {
  setUp(() => ActiveCompanySession.set(5));
  tearDown(ActiveCompanySession.clear);

  test('live M9 list and history use company-scoped records only', () async {
    final calls = <String>[];
    final api = SignApiClient(
      baseUrl: Uri.parse('https://example.test'),
      tokenProvider: () async => 'authorized',
      activeCompanyId: () => ActiveCompanySession.companyId,
      httpClient: MockClient((request) async {
        calls.add('${request.method} ${request.url.path}');
        expect(request.headers['X-Company-Id'], '5');
        expect(request.headers['Authorization'], 'Bearer authorized');
        if (request.url.path == '/api/v1/documents') {
          expect(request.url.queryParameters['job_id'], '9');
          return http.Response(jsonEncode({'data': {
            'documents': [{
              'id': 'managed-3', 'kind': 'managed',
              'number': 'R-3', 'title': 'Real site report',
              'category': 'reports', 'status': 'file',
              'version': 1, 'job_id': 9, 'customer': 'Customer',
              'project': 'Site', 'has_pdf': true,
              'sha256': List.filled(64, 'a').join(),
              'created_at': '2026-11-04T11:00:00Z',
            }], 'page': 1, 'last_page': 1, 'total': 1,
          }}), 200);
        }
        if (request.url.path == '/api/v1/documents/managed-3') {
          return http.Response(jsonEncode({'data': {
            'document': {
              'id': 'managed-3', 'kind': 'managed',
              'number': 'R-3', 'title': 'Real site report',
              'category': 'reports', 'status': 'file',
              'version': 2, 'job_id': 9, 'has_pdf': true,
              'sha256': List.filled(64, 'a').join(),
              'created_at': '2026-11-04T11:00:00Z',
            },
            'attachments': [{'id': 8, 'original_name': 'photo.png',
              'mime_type': 'image/png',
              'sha256': List.filled(64, 'b').join()}],
            'history': [{
              'id': 'event-1', 'type': 'version_changed',
              'occurred_at': '2026-11-04T12:00:00Z',
            }],
          }}), 200);
        }
        throw StateError('Unexpected endpoint');
      }),
    );
    final repo = RemoteDocumentRepository(api: api);
    final listed = await repo.listDocuments(jobId: '9');
    expect(listed, hasLength(1));
    expect(listed.first.jobId, '9');
    expect(listed.first.category, DocumentCategory.reports);
    final detail = await repo.details('managed-3');
    expect(detail.version, 2);
    expect(detail.attachmentNames, ['photo.png']);
    expect(detail.history.single.type, DocumentHistoryType.versionChanged);
    expect(calls, [
      'GET /api/v1/documents', 'GET /api/v1/documents/managed-3',
    ]);
  });

  test('PDF must match the signed SHA-256 digest from details', () async {
    final pdf = utf8.encode('%PDF-1.4\n1 0 obj\nendobj\n%%EOF\n');
    final sha = sha256.convert(pdf).toString();
    var corrupt = false;
    final api = SignApiClient(
      baseUrl: Uri.parse('https://example.test'),
      tokenProvider: () async => 'authorized',
      activeCompanyId: () => ActiveCompanySession.companyId,
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/pdf')) {
          return http.Response.bytes(corrupt
              ? utf8.encode('%PDF-1.4\naltered\n%%EOF\n') : pdf, 200,
              headers: {'content-type': 'application/pdf'});
        }
        return http.Response(jsonEncode({'data': {'document': {
          'id': 'signed-8', 'kind': 'signed', 'number': 'Q-4',
          'title': 'Signed Quote Q-4', 'category': 'quotes',
          'status': 'signed', 'version': 1, 'has_pdf': true,
          'sha256': sha, 'created_at': '2026-11-04T11:00:00Z',
        }}}), 200);
      }),
    );
    final repo = RemoteDocumentRepository(api: api);
    final doc = await repo.details('signed-8');
    expect(await repo.downloadPdf(doc), orderedEquals(pdf));
    corrupt = true;
    await expectLater(repo.downloadPdf(doc), throwsA(isA<SignApiException>()));
  });

  test('wrong job document response must be rejected', () async {
    final api = SignApiClient(
      baseUrl: Uri.parse('https://example.test'),
      tokenProvider: () async => 'authorized',
      activeCompanyId: () => ActiveCompanySession.companyId,
      httpClient: MockClient((_) async => http.Response(jsonEncode({'data': {
        'documents': [{
          'id': 'managed-9', 'category': 'other',
          'title': 'Wrong job', 'number': 'D-9', 'status': 'file',
          'version': 1, 'job_id': 99, 'has_pdf': false,
          'created_at': '2026-11-04T11:00:00Z',
        }], 'last_page': 1,
      }}), 200)),
    );
    await expectLater(
      RemoteDocumentRepository(api: api).listDocuments(jobId: '9'),
      throwsA(isA<SignApiException>()),
    );
  });
  test('private attachment content and SHA must both be verified', () async {
    const png = <int>[137, 80, 78, 71, 13, 10, 26, 10, 0, 1];
    final digest = sha256.convert(png).toString();
    var damaged = false;
    final calls = <String>[];
    final api = SignApiClient(
      baseUrl: Uri.parse('https://example.test'),
      tokenProvider: () async => 'authorized',
      activeCompanyId: () => ActiveCompanySession.companyId,
      httpClient: MockClient((request) async {
        calls.add(request.url.path);
        expect(request.headers['X-Company-Id'], '5');
        if (request.url.path.endsWith('/download')) {
          return http.Response.bytes(damaged
              ? <int>[137, 80, 78, 71, 13, 10, 26, 10, 0, 2] : png,
              200, headers: {'content-type': 'image/png'});
        }
        return http.Response(jsonEncode({'data': {
          'document': {
            'id': 'managed-3', 'category': 'reports', 'number': 'R-3',
            'title': 'Report', 'status': 'file', 'version': 1,
            'has_pdf': false, 'created_at': '2026-11-04T11:00:00Z',
          },
          'related': [],
          'history': [],
          'attachments': [{
            'id': 8, 'original_name': 'photo.png',
            'mime_type': 'image/png', 'sha256': digest,
          }],
        }}), 200);
      }),
    );
    final repository = RemoteDocumentRepository(api: api);
    final document = await repository.details('managed-3');
    final attachment = document.attachments.single;
    expect(document.attachmentNames, ['photo.png']);
    expect(await repository.downloadAttachment(document, attachment),
        orderedEquals(png));
    expect(calls.last,
        '/api/v1/documents/managed-3/attachments/8/download');
    damaged = true;
    await expectLater(
      repository.downloadAttachment(document, attachment),
      throwsA(isA<SignApiException>()),
    );
  });

}
