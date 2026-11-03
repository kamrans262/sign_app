import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:sign2digital/core/services/active_company_session.dart';
import 'package:sign2digital/core/services/sign_api_client.dart';
import 'package:sign2digital/features/quotes/data/remote_signature_request_repository.dart';
import 'package:sign2digital/features/quotes/domain/quote_document_tracking.dart';
import 'package:sign2digital/features/quotes/domain/quote_review_models.dart';

QuoteReviewDraft approvedSource() {
  final quote = QuoteReviewDraft(
    id:'local-quote',clientId:'7',jobId:'9',
    clientName:'Signer Customer',clientEmail:'signer@example.test',
    date:DateTime.utc(2026,11,4),terms:'Approved terms',
    items:[QuoteReviewWorkItem(
      id:'line',title:'Repair',description:'Work',quantity:'1',unitPrice:'120.00',
    )],
  );
  quote.serverId=22;
  quote.serverRevision=2;
  quote.approvedLocally=true;
  return quote;
}

Map<String,dynamic> requestRecord({String status='ready'}) => {
  'id':101,
  'request_id':'99999999-aaaa-4444-bbbb-aaaaaaaaaaaa',
  'quote_id':22,
  'status':status,
  'expires_at':'2031-01-01T00:00:00Z',
};

SignApiClient client(http.Client httpClient) => SignApiClient(
  baseUrl:Uri.parse('https://example.test'),
  httpClient:httpClient,
  activeCompanyId:()=>ActiveCompanySession.companyId,
  tokenProvider:() async=>'verified-user-token',
);

void main() {
  setUp(()=>ActiveCompanySession.set(5));
  tearDown(ActiveCompanySession.clear);

  test('create signing link uses authenticated tenant and only server events',
      () async {
    final calls=<String>[];
    final api=client(MockClient((request) async {
      calls.add(request.method + ' ' + request.url.path);
      expect(request.headers['Authorization'],'Bearer verified-user-token');
      expect(request.headers['X-Company-Id'],'5');
      if(request.method=='POST' && request.url.path.endsWith('/signature-requests')) {
        final body=jsonDecode(request.body) as Map<String,dynamic>;
        expect(body['delivery'],'link');
        expect(body['signer_name'],'Signer Customer');
        expect(body['signer_email'],'signer@example.test');
        return http.Response(jsonEncode({'data':{
          'request':requestRecord(),
          'secure_link':'https://example.test/sign/opaque-token',
          'delivered':false,
        }}),201);
      }
      if(request.method=='GET' && request.url.path.endsWith('/101')) {
        return http.Response(jsonEncode({'data':{
          'request':requestRecord(),
          'events':[{
            'id':'300','type':'signatureRequested',
            'occurredAt':'2026-11-04T00:00:00Z',
          }],
        }}),200);
      }
      throw StateError('Unexpected endpoint');
    }));
    final result=await RemoteSignatureRequestRepository(api:api).create(
      approvedSource(), signerName:'Signer Customer',
      signerEmail:'signer@example.test',delivery:'link',
    );
    expect(result.id,101);
    expect(result.tracking.requestId,
      '99999999-aaaa-4444-bbbb-aaaaaaaaaaaa');
    expect(result.tracking.secureUrl.toString(),
      'https://example.test/sign/opaque-token');
    expect(result.tracking.events.single.type,
      QuoteDocumentEventType.signatureRequested);
    expect(result.tracking.sent,isFalse);
    expect(result.tracking.viewed,isFalse);
    expect(calls,[
      'POST /api/v1/quotes/22/signature-requests',
      'GET /api/v1/signature-requests/101',
    ]);
  });

  test('company response isolation prevents accepting a foreign quote',() async {
    final api=client(MockClient((request) async =>
      http.Response(jsonEncode({'data':{
        'request':{...requestRecord(),'quote_id':999},'events':[],
      }}),200)));
    await expectLater(
      RemoteSignatureRequestRepository(api:api).show(approvedSource(),101),
      throwsA(isA<SignApiException>()),
    );
  });

  test('new signature requests require real approved server quote',() async {
    final invalid=approvedSource()..approvedLocally=false;
    final api=client(MockClient((_) async =>
      throw StateError('Must not make network requests')));
    await expectLater(
      RemoteSignatureRequestRepository(api:api).create(
        invalid,signerName:'Customer',
        signerEmail:'signer@example.test',delivery:'link',
      ),throwsA(isA<SignApiException>()),
    );
  });

  test('latest reads server events and never fabricates delivery',() async {
    final api=client(MockClient((request) async {
      if(request.url.path.endsWith('/signature-requests')) {
        return http.Response(jsonEncode({'data':{
          'requests':[requestRecord(status:'viewed')],'total':1,
        }}),200);
      }
      if(request.url.path.endsWith('/101')) {
        return http.Response(jsonEncode({'data':{
          'request':requestRecord(status:'viewed'),
          'events':[{
            'id':'301','type':'documentViewed',
            'occurredAt':'2026-11-04T08:00:00Z',
          }],
        }}),200);
      }
      throw StateError('Unexpected endpoint');
    }));
    final result=await RemoteSignatureRequestRepository(api:api).latest(
      approvedSource());
    expect(result?.tracking.viewed,isTrue);
    expect(result?.tracking.sent,isFalse);
    expect(result?.tracking.requestIsActive,isTrue);
    expect(result?.tracking.secureUrl,isNull);
  });
}
