import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sign2digital/core/services/active_company_session.dart';
import 'package:sign2digital/core/services/sign_api_client.dart';
import 'package:sign2digital/features/invoices/data/remote_invoice_repository.dart';

void main(){
  setUp(()=>ActiveCompanySession.set(7));
  tearDown(()=>ActiveCompanySession.clear());

  final pdf=Uint8List.fromList(utf8.encode(
    '%PDF-1.4\n1 0 obj\n<</Type/Catalog>>\nendobj\n%%EOF\n'));
  final hash=sha256.convert(pdf).toString();
  Map<String,dynamic> issue()=>{'data':{'document':{
    'invoice_id':31,'revision':1,'sha256':hash,'byte_size':pdf.length,
  }}};
  SignApiClient api(Future<http.Response> Function(http.Request) callback)=>
      SignApiClient(baseUrl:Uri.parse('https://example.test'),
        tokenProvider:() async=>'m17-stage2-test',
        activeCompanyId:()=>ActiveCompanySession.companyId,
        httpClient:MockClient(callback));

  test('download obtains the genuine issued PDF and verifies SHA-256',() async{
    final requests=<String>[];
    final client=api((request) async{
      requests.add('${request.method} ${request.url.path}');
      expect(request.headers['X-Company-Id'],'7');
      if(request.method=='POST'){
        expect(jsonDecode(request.body)['confirm'],true);
        return http.Response(jsonEncode(issue()),200);
      }
      return http.Response.bytes(pdf,200,
        headers:{'content-type':'application/pdf'});
    });
    final bytes=await RemoteInvoiceRepository(api:client)
        .issuedPdf('invoice-31');
    expect(bytes,pdf);
    expect(requests,[
      'POST /api/v1/invoices/31/issue',
      'GET /api/v1/invoices/31/pdf',
    ]);
    client.dispose();
  });

  test('tampered or unexpected invoice PDF is rejected',() async{
    final client=api((request) async{
      if(request.method=='POST')return http.Response(jsonEncode(issue()),200);
      return http.Response.bytes(Uint8List.fromList(utf8.encode(
        '%PDF-1.4\nModified PDF\n%%EOF\n')),200,
        headers:{'content-type':'application/pdf'});
    });
    await expectLater(RemoteInvoiceRepository(api:client)
        .issuedPdf('invoice-31'),throwsA(isA<SignApiException>()));
    client.dispose();
  });

  test('send requires verified issuance and confirms server delivery',() async{
    final calls=<String>[];
    final client=api((request) async{
      calls.add(request.url.path);
      if(request.url.path.endsWith('/issue')){
        return http.Response(jsonEncode(issue()),200);
      }
      final data=jsonDecode(request.body) as Map;
      expect(data['recipient_email'],'jean@example.test');
      expect(data['mode'],'pdf');
      expect((data['request_key'] as String).startsWith('invoice-send-31-'),true);
      return http.Response(jsonEncode({'data':{
        'delivered':true,'pdf_attached':true,'pdf_sha256':hash,
      }}),200);
    });
    await RemoteInvoiceRepository(api:client).sendIssuedInvoice(
      'invoice-31',recipientEmail:'jean@example.test');
    expect(calls,[
      '/api/v1/invoices/31/issue',
      '/api/v1/invoices/31/send',
    ]);
    client.dispose();
  });

  test('send cannot accept unconfirmed delivery',() async{
    final client=api((request) async{
      if(request.url.path.endsWith('/issue')){
        return http.Response(jsonEncode(issue()),200);
      }
      return http.Response(jsonEncode({'data':{
        'delivered':false,'pdf_attached':false,'pdf_sha256':hash,
      }}),200);
    });
    await expectLater(RemoteInvoiceRepository(api:client).sendIssuedInvoice(
      'invoice-31',recipientEmail:'jean@example.test'),
      throwsA(isA<SignApiException>()));
    client.dispose();
  });

  test('generates a private 7-day customer link instead of raw IDs',() async{
    const token='aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    final client=api((request) async{
      if(request.url.path.endsWith('/issue')){
        return http.Response(jsonEncode(issue()),200);
      }
      return http.Response(jsonEncode({'data':{
        'secure_link':'https://example.test/invoice-view/$token',
        'delivered':false,
        'expires_at':'2026-11-12T13:00:00Z',
      }}),200);
    });
    final link=await RemoteInvoiceRepository(api:client)
        .customerLink('invoice-31');
    expect(link,endsWith(token));
    client.dispose();
  });

  test('company switch invalidates an in-flight issuance response',() async{
    final client=api((request) async{
      ActiveCompanySession.set(8);
      return http.Response(jsonEncode(issue()),200);
    });
    await expectLater(RemoteInvoiceRepository(api:client)
        .issuedPdf('invoice-31'),throwsA(isA<SignApiException>()));
    client.dispose();
  });
}
