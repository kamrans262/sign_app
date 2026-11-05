import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sign2digital/core/services/active_company_session.dart';
import 'package:sign2digital/core/services/sign_api_client.dart';
import 'package:sign2digital/features/documents/data/remote_general_document_repository.dart';

final sampleBytes=Uint8List.fromList(utf8.encode(
  '%PDF-1.4\n1 0 obj\n<< >>\nendobj\n%%EOF'));
final digest=sha256.convert(sampleBytes).toString();
final signedBytes=Uint8List.fromList(utf8.encode(
  '%PDF-1.4\n1 0 obj\n<< /Signed true >>\nendobj\n%%EOF'));
final signedHash=sha256.convert(signedBytes).toString();

Map<String,dynamic> issued()=>{
  'document_id':41,'revision':2,'sha256':digest,
  'byte_size':sampleBytes.length,
  'filename':'Sign2Digital_Document_41.pdf',
};
Map<String,dynamic> meta()=>{
  'data':{'issue':issued(),'signatures':[],'deliveries':[],'links':[]}
};

void main(){
  setUp(()=>ActiveCompanySession.set(7));
  tearDown(()=>ActiveCompanySession.clear());

  SignApiClient api(Future<http.Response> Function(http.Request) handler)=>
    SignApiClient(baseUrl:Uri.parse('https://example.test'),
      tokenProvider:() async=>'m18-secure-test',
      activeCompanyId:()=>ActiveCompanySession.companyId,
      httpClient:MockClient(handler));

  test('explicit issue verifies frozen metadata; PDF SHA is checked',() async{
    var issueCount=0;
    final client=api((request) async{
      expect(request.headers['X-Company-Id'],'7');
      switch(request.url.path){
        case '/api/v1/general-documents/41/issue':
          issueCount++;
          expect(request.method,'POST');
          expect(jsonDecode(request.body),{'confirm':true});
          return http.Response(jsonEncode({'data':issued()}),200);
        case '/api/v1/general-documents/41/issued':
          return http.Response(jsonEncode(meta()),200);
        case '/api/v1/general-documents/41/pdf':
          return http.Response.bytes(sampleBytes,200,headers:{
            'content-type':'application/pdf'});
        default:
          throw StateError('Unexpected M18 request');
      }
    });
    final repo=RemoteGeneralDocumentRepository(api:client);
    expect((await repo.issue(41))['sha256'],digest);
    expect(await repo.issuedPdf(41),sampleBytes);
    expect(issueCount,1);
    client.dispose();
  });

  test('tampered issued PDF does not pass local hash verification',() async{
    final client=api((request) async{
      if(request.url.path.endsWith('/issued')){
        return http.Response(jsonEncode(meta()),200);
      }
      return http.Response.bytes(Uint8List.fromList(utf8.encode(
        '%PDF-1.4\n1 0 obj\n<< /Tampered true >>\n%%EOF')),
        200,headers:{'content-type':'application/pdf'});
    });
    await expectLater(RemoteGeneralDocumentRepository(api:client)
      .issuedPdf(41),throwsA(isA<SignApiException>()));
    client.dispose();
  });

  test('private customer link must be HTTPS and not claim email delivery',() async{
    final token='a'*64;
    final client=api((request) async=>http.Response(jsonEncode({'data':{
      'secure_link':'https://example.test/general-document/'+token,
      'delivered':false,'expires_at':'2026-11-12T10:00:00Z',
    }}),200));
    final link=await RemoteGeneralDocumentRepository(api:client).customerLink(41);
    expect(link,contains('/general-document/'));
    client.dispose();
  });

  test('email submission verifies mode and approved PDF SHA',() async{
    final requests=<String>[];
    final client=api((request) async{
      requests.add(request.url.path);
      if(request.url.path.endsWith('/issued')){
        return http.Response(jsonEncode(meta()),200);
      }
      final data=jsonDecode(request.body) as Map;
      expect(data['recipient_email'],'recipient@example.test');
      expect(data['mode'],'pdf');
      expect((data['request_key'] as String).startsWith('general-send-41-'),true);
      return http.Response(jsonEncode({'data':{
        'email_submitted':true,'mode':'pdf','sha256':digest,
      }}),200);
    });
    await RemoteGeneralDocumentRepository(api:client).send(41,
      recipientEmail:'recipient@example.test');
    expect(requests,[
      '/api/v1/general-documents/41/issued',
      '/api/v1/general-documents/41/send',
    ]);
    client.dispose();
  });

  test('signature requests use separate general-sign capabilities',() async{
    final token='b'*64;
    final client=api((request) async{
      expect(request.url.path,'/api/v1/general-documents/41/signature-requests');
      final data=jsonDecode(request.body) as Map;
      expect(data['confirm'],true);
      expect(data['signer_email'],'signer@example.test');
      return http.Response(jsonEncode({'data':{
        'id':9,'status':'ready',
        'signature_link':'https://example.test/general-sign/'+token,
        'signer_name':'Test Signer',
      }}),201);
    });
    final result=await RemoteGeneralDocumentRepository(api:client)
      .requestSignature(41,signerName:'Test Signer',
        signerEmail:'signer@example.test');
    expect(result['id'],9);
    expect(result['signature_link'],endsWith(token));
    client.dispose();
  });

  test('signed PDF is accepted only against its own SHA and status',() async{
    final metadata=meta();
    (metadata['data'] as Map)['signatures']=[
      {'id':9,'status':'signed','signed_pdf_sha256':signedHash},
    ];
    final client=api((request) async{
      if(request.url.path.endsWith('/issued')){
        return http.Response(jsonEncode(metadata),200);
      }
      return http.Response.bytes(signedBytes,200,headers:{
        'content-type':'application/pdf'});
    });
    final signed=await RemoteGeneralDocumentRepository(api:client)
      .signedPdf(41,9);
    expect(sha256.convert(signed).toString(),signedHash);
    client.dispose();
  });

  test('company switch invalidates in-flight issuance metadata',() async{
    final pending=Completer<http.Response>();
    final client=api((request)=>pending.future);
    final future=RemoteGeneralDocumentRepository(api:client).issue(41);
    await Future<void>.delayed(Duration.zero);
    ActiveCompanySession.set(8);
    pending.complete(http.Response(jsonEncode({'data':issued()}),200));
    await expectLater(future,throwsA(isA<SignApiException>()));
    client.dispose();
  });

  test('missing official PDF is explicitly unissued, not fabricated',() async{
    final client=api((request) async=>http.Response(
      jsonEncode({'message':'Not Found'}),404));
    final repo=RemoteGeneralDocumentRepository(api:client);
    expect(await repo.issuedMetadata(41),isNull);
    await expectLater(repo.issuedPdf(41),
      throwsA(isA<SignApiException>()));
    client.dispose();
  });
}
