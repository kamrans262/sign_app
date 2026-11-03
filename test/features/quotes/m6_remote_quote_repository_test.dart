import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:sign2digital/core/services/active_company_session.dart';
import 'package:sign2digital/core/services/sign_api_client.dart';
import 'package:sign2digital/features/quotes/data/remote_quote_repository.dart';
import 'package:sign2digital/features/quotes/domain/quote_draft_input.dart';
import 'package:sign2digital/features/quotes/domain/quote_extraction_models.dart';
import 'package:sign2digital/features/quotes/domain/quote_review_models.dart';
import 'package:sign2digital/features/quotes/services/remote_quote_preparation_service.dart';

Map<String,dynamic> serverQuote({int company=5,int id=22,
    String status='draft'}) => {
  'id':id,'company_id':company,'client_id':8,'job_id':11,
  'reference_number':'Q-2026-000022','revision':1,
  'client_name':'Marc Dupont',
  'client_email':'marc@example.test','client_phone':'','billing_address':'Lausanne',
  'quote_date':'2026-11-03','valid_until':null,
  'currency':'CHF','vat_basis_points':810,'deposit_basis_points':0,
  'terms':'Payment terms','source_method':'text','status':status,
  'items':[{
    'id':1,'title':'Install windows','description':'Work','quantity':3,
    'dimensions':'1.2 m x 1.5 m','unit_price_minor':12550,
    'other_fields':{},'unresolved_fields':[],
  }],
};
QuoteReviewDraft draft() => QuoteReviewDraft(
  id:'local-quote-1',clientId:'8',jobId:'11',
  clientName:'Marc Dupont',clientEmail:'marc@example.test',
  date:DateTime(2026,11,3),currency:'CHF',
  vatBasisPoints:810,terms:'Payment terms',sourceMethod:'text',
  items:[QuoteReviewWorkItem(
    id:'line-1',title:'Install windows',description:'Work',
    quantity:'3',unitPrice:'125.50',dimensions:'1.2 m x 1.5 m',
  )],
);
SignApiClient client(http.Client httpClient) => SignApiClient(
  baseUrl:Uri.parse('https://example.test'),
  httpClient:httpClient,
  activeCompanyId:()=>ActiveCompanySession.companyId,
  tokenProvider:() async=>'verified-token',
);

void main() {
  setUp(()=>ActiveCompanySession.set(5));
  tearDown(ActiveCompanySession.clear);

  test('save, approve and email use verified tenant and server identity',() async {
    final calls=<String>[];
    final api=client(MockClient((request) async {
      calls.add('${request.method} ${request.url.path}');
      expect(request.headers['Authorization'],'Bearer verified-token');
      expect(request.headers['X-Company-Id'],'5');
      final body=request.body.isEmpty
          ? <String,dynamic>{}
          : jsonDecode(request.body) as Map<String,dynamic>;
      if(request.url.path == '/api/v1/quotes') {
        expect(body.containsKey('company_id'),isFalse);
        expect(body.containsKey('reference_number'),isFalse);
        expect(body['client_id'],8);
        expect(body['job_id'],11);
        final item=body['items'][0] as Map<String,dynamic>;
        expect(item['unit_price_minor'],12550);
        expect(item['quantity'],3);
        return http.Response(jsonEncode({'data':{'quote':serverQuote()}}),201);
      }
      if(request.url.path.endsWith('/approve')) {
        expect(body['confirmed'],isTrue);
        expect(body['expected_revision'],1);
        return http.Response(jsonEncode({'data':{'quote':
          serverQuote(status:'approved')}}),200);
      }
      if(request.url.path.endsWith('/share')) {
        expect(body['method'],'email');
        expect(body['recipient_email'],'marc@example.test');
        return http.Response(jsonEncode({'data':{'delivered':true}}),200);
      }
      throw StateError('Unexpected quote endpoint');
    }));
    final repo=RemoteQuoteRepository(api:api);
    final approved=await repo.approve(draft());
    expect(approved.serverId,22);
    expect(approved.quoteNumber,'Q-2026-000022');
    expect(approved.approvedLocally,isTrue);
    final shared=await repo.share(approved,method:'email',email:'marc@example.test');
    expect(shared['delivered'],isTrue);
    expect(calls,[
      'POST /api/v1/quotes',
      'POST /api/v1/quotes/22/approve',
      'POST /api/v1/quotes/22/share',
    ]);
  });

  test('approval sends saved revision and rejects a stale server response',() async {
    var approvals=0;
    final api=client(MockClient((request) async {
      if(request.url.path == '/api/v1/quotes') {
        return http.Response(jsonEncode({'data':{'quote':serverQuote()}}),201);
      }
      if(request.url.path.endsWith('/approve')) {
        approvals++;
        final body=jsonDecode(request.body) as Map<String,dynamic>;
        expect(body['confirmed'],true);
        expect(body['expected_revision'],1);
        return http.Response(jsonEncode({'message':
          'Quote was updated elsewhere. Reload before approving.'}),409);
      }
      throw StateError('Unexpected request');
    }));
    await expectLater(RemoteQuoteRepository(api:api).approve(draft()),
        throwsA(isA<SignApiException>()));
    expect(approvals,1);
  });

  test('rejects fabricated foreign tenant quote and company switches',() async {
    final repository=RemoteQuoteRepository(api:client(MockClient((_) async =>
      http.Response(jsonEncode({'data':{'quote':serverQuote(company:99)}}),201))));
    await expectLater(repository.saveDraft(draft()),
      throwsA(isA<SignApiException>()));
    final switching=RemoteQuoteRepository(api:client(MockClient((_) async {
      ActiveCompanySession.set(6);
      return http.Response(jsonEncode({'data':{'quote':serverQuote()}}),201);
    })));
    await expectLater(switching.saveDraft(draft()),
      throwsA(isA<SignApiException>()));
  });

  test('unpriced and unresolved work must not be approved',() async {
    final data=draft();
    data.items.first.unitPrice='';
    final repo=RemoteQuoteRepository(api:client(MockClient((_) async =>
      throw StateError('Approval must not invoke network'))));
    await expectLater(repo.approve(data),throwsA(isA<SignApiException>()));
  });

  test('real text AI backend never supplies prices, VAT or an API secret',() async {
    final api=client(MockClient((request) async {
      expect(request.url.path,'/api/v1/quotes/prepare/text');
      expect(request.headers.containsKey('Authorization'),isTrue);
      expect(request.body.contains('OPENAI_API_KEY'),isFalse);
      expect(jsonDecode(request.body)['text'],'Install 3 windows');
      return http.Response(jsonEncode({'data':{'snapshot':{
        'stage':'completed','items':[{
          'title':'Install windows','description':'Install white PVC',
          'quantity':3,'dimensions':'1.2 m',
          'unit_price_minor':100000000,
        }],
        'currency':null,'notes':null,'location':'Lausanne',
      }}}),200);
    }));
    final service=RemoteQuotePreparationService(api:api);
    final result=await service.prepare(QuoteDraftInput(
      method:QuoteInputMethod.text,createdAt:DateTime(2026,11,3),
      description:'Install 3 windows',
    )).toList();
    expect(result.map((s)=>s.stage),
      [QuotePreparationStage.extracting,QuotePreparationStage.completed]);
    final complete=result.last;
    expect(complete.items.single.title,'Install windows');
    expect(complete.items.single.quantity,3);
    final review=QuoteReviewDraft.fromExtraction(complete,
      QuoteDraftInput(method:QuoteInputMethod.text,
        createdAt:DateTime(2026,11,3),description:'Install 3 windows'));
    expect(review.items.single.unitPrice,isEmpty);
    expect(review.vatBasisPoints,0);
    expect(review.approvedLocally,isFalse);
  });
}
