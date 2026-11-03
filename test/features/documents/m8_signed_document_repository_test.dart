import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:sign2digital/core/services/active_company_session.dart';
import 'package:sign2digital/core/services/sign_api_client.dart';
import 'package:sign2digital/features/documents/data/remote_signed_document_repository.dart';

void main() {
  setUp(()=>ActiveCompanySession.set(5));
  tearDown(ActiveCompanySession.clear);

  test('signed job document history and verified bytes use current company',() async {
    final pdf=utf8.encode('%PDF-1.4\n1 0 obj\nendobj\n%%EOF\n');
    final hash=sha256.convert(pdf).toString();
    final calls=<String>[];
    final api=SignApiClient(
      baseUrl:Uri.parse('https://example.test'),
      tokenProvider:() async=>'verified-token',
      activeCompanyId:()=>ActiveCompanySession.companyId,
      httpClient:MockClient((request) async {
        calls.add(request.method+' '+request.url.path);
        expect(request.headers['Authorization'],'Bearer verified-token');
        expect(request.headers['X-Company-Id'],'5');
        if(request.url.path=='/api/v1/signed-documents') {
          expect(request.url.queryParameters['job_id'],'9');
          return http.Response(jsonEncode({'data':{
            'total':1,'documents':[{
              'id':7,'document_id':'document-uuid',
              'quote_number':'Q-2026-000022','job_id':9,
              'signed_at':'2026-11-04T12:00:00Z',
              'signed_pdf_sha256':hash,
            }],
          }}),200);
        }
        if(request.url.path=='/api/v1/signed-documents/7/pdf') {
          return http.Response.bytes(pdf,200,
              headers:{'content-type':'application/pdf'});
        }
        throw StateError('Unknown endpoint');
      }),
    );
    final repo=RemoteSignedDocumentRepository(api:api);
    final records=await repo.list(jobId:'9');
    expect(records.single.id,7);
    final bytes=await repo.download(records.single);
    expect(bytes,orderedEquals(pdf));
    expect(calls,[
      'GET /api/v1/signed-documents',
      'GET /api/v1/signed-documents/7/pdf',
    ]);
  });

  test('reject signed documents from another job',() async {
    final api=SignApiClient(
      baseUrl:Uri.parse('https://example.test'),
      tokenProvider:() async=>'verified-token',
      activeCompanyId:()=>ActiveCompanySession.companyId,
      httpClient:MockClient((_) async=>http.Response(jsonEncode({'data':{
        'documents':[{
          'id':7,'document_id':'document-uuid',
          'quote_number':'Q-1','job_id':99,
          'signed_at':'2026-11-04T12:00:00Z',
          'signed_pdf_sha256':List.filled(64,'a').join(),
        }],
      }}),200)),
    );
    await expectLater(
      RemoteSignedDocumentRepository(api:api).list(jobId:'9'),
      throwsA(isA<SignApiException>()),
    );
  });
}
