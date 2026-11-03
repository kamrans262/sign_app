import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:sign2digital/core/services/active_company_session.dart';
import 'package:sign2digital/core/services/sign_api_client.dart';
import 'package:sign2digital/features/quotes/data/remote_in_person_signing_repository.dart';
import 'package:sign2digital/features/quotes/domain/quote_signature_draft.dart';
import 'package:sign2digital/features/quotes/domain/quote_review_models.dart';

QuoteReviewDraft realQuote() {
  final q=QuoteReviewDraft(
    id:'local-quote',jobId:'9',
    quoteNumber:'Q-2026-000022',
    clientName:'Signing Customer',clientEmail:'customer@example.test',
    date:DateTime.utc(2026,11,4),terms:'Approved terms',
    items:[QuoteReviewWorkItem(id:'line',title:'Repair',description:'Work',
      quantity:'1',unitPrice:'120.00')],
  );
  q.serverId=22;q.serverRevision=2;q.approvedLocally=true;
  return q;
}

Map<String,dynamic> sessionData()=>{
  'request_id':6,
  'quoteId':'22',
  'documentId':'00000000-1111-4222-8333-000000000001',
  'requestId':'00000000-1111-4222-8333-000000000002',
  'customerSignerId':'00000000-1111-4222-8333-000000000003',
  'businessSignerId':'00000000-1111-4222-8333-000000000004',
  'documentVersion':'2:1234',
  'consentReference':'consent-verified',
  'expiresAt':'2030-01-01T00:00:00Z',
};

void main() {
  setUp(()=>ActiveCompanySession.set(5));
  tearDown(ActiveCompanySession.clear);

  test('in-person signing validates two real signer IDs and final PDF hash',() async {
    final pdf=utf8.encode('%PDF-1.4\n1 0 obj\nendobj\n%%EOF\n');
    final calls=<String>[];
    final api=SignApiClient(
      baseUrl:Uri.parse('https://example.test'),
      activeCompanyId:()=>ActiveCompanySession.companyId,
      tokenProvider:() async=>'real-token',
      httpClient:MockClient((request) async {
        expect(request.headers['Authorization'],'Bearer real-token');
        expect(request.headers['X-Company-Id'],'5');
        calls.add(request.method+' '+request.url.path);
        if(request.url.path.endsWith('/in-person-signing')) {
          return http.Response(jsonEncode({'data':sessionData()}),201);
        }
        final body=jsonDecode(request.body) as Map<String,dynamic>;
        expect(body['consentAccepted'],true);
        expect(body['customerSignerId'],sessionData()['customerSignerId']);
        expect(body['businessSignerId'],sessionData()['businessSignerId']);
        expect((body['customerStrokes'] as List).first.first['x'],0.1);
        return http.Response(jsonEncode({'data':{
          'documentId':sessionData()['documentId'],
          'quoteId':'22',
          'jobId':'9',
          'quoteNumber':'Q-2026-000022',
          'projectName':'Repair',
          'signerName':'Signing Customer',
          'signedAt':'2026-11-04T10:00:00Z',
          'signedPdfSha256':sha256.convert(pdf).toString(),
          'signedPdfBase64':base64Encode(pdf),
        }}),201);
      }),
    );
    final repo=RemoteInPersonSigningRepository(api:api);
    final quote=realQuote();
    final session=await repo.start(quote);
    final draft=QuoteInPersonSignatureSubmission(
      quoteId:quote.id,
      documentId:session.documentId,
      customerSignerId:session.customerSignerId,
      businessSignerId:session.businessSignerId,
      customerStrokes:[[const Offset(.1,.2),const Offset(.3,.5)]],
      businessStrokes:[[const Offset(.2,.1),const Offset(.4,.7)]],
      capturedAt:DateTime.utc(2026,11,4),
      consentAccepted:true,
    );
    final receipt=await repo.complete(quote,session,draft);
    expect(receipt?.documentId,session.documentId);
    expect(receipt?.quoteId,quote.id);
    expect(receipt?.signedPdfBytes,orderedEquals(pdf));
    expect(calls,[
      'POST /api/v1/quotes/22/in-person-signing',
      'POST /api/v1/signature-requests/6/complete-in-person',
    ]);
  });

  test('in-person completion rejects foreign signer before sending',() async {
    final api=SignApiClient(
      baseUrl:Uri.parse('https://example.test'),
      activeCompanyId:()=>ActiveCompanySession.companyId,
      tokenProvider:() async=>'real-token',
      httpClient:MockClient((_) async=>throw StateError('No request allowed')),
    );
    final quote=realQuote();
    final session=RemoteInPersonSession(
      id:6,quoteId:'22',documentId:'document',
      requestId:'request',customerSignerId:'customer',
      businessSignerId:'business',documentVersion:'2:hash',
      consentReference:'consent',expiresAt:DateTime.utc(2030),
    );
    final draft=QuoteInPersonSignatureSubmission(
      quoteId:quote.id,documentId:session.documentId,
      customerSignerId:'different-customer',
      businessSignerId:session.businessSignerId,
      customerStrokes:[[const Offset(.1,.2),const Offset(.3,.5)]],
      businessStrokes:[[const Offset(.2,.1),const Offset(.4,.7)]],
      capturedAt:DateTime.utc(2026,11,4),consentAccepted:true,
    );
    await expectLater(
      RemoteInPersonSigningRepository(api:api).complete(quote,session,draft),
      throwsA(isA<SignApiException>()),
    );
  });
}
