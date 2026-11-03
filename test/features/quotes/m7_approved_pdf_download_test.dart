import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sign2digital/core/services/active_company_session.dart';
import 'package:sign2digital/core/services/sign_api_client.dart';
import 'package:sign2digital/features/quotes/data/remote_quote_repository.dart';
import 'package:sign2digital/features/quotes/domain/quote_review_models.dart';

const pdfExample = '%PDF-1.4\n1 0 obj\n<</Type/Catalog>>\nendobj\n%%EOF\n';

SignApiClient api(http.Client httpClient) => SignApiClient(
  baseUrl:Uri.parse('https://test.example'),
  httpClient:httpClient,
  tokenProvider:() async => 'verified-token',
  activeCompanyId:() => ActiveCompanySession.companyId,
);

QuoteReviewDraft approvedQuote({String company = '5'}) {
  final q=QuoteReviewDraft(
    id:'approved-91', companyId:company, clientName:'Test Customer',
    date:DateTime(2026,11,4), terms:'Reviewed terms',
    items:[QuoteReviewWorkItem(
      id:'item1', title:'Repair', description:'Work', quantity:'1',
      unitPrice:'100.00')],
  );
  q.serverId=91;
  q.serverRevision=3;
  q.serverStatus='approved';
  q.approvedLocally=true;
  return q;
}

void main() {
  setUp(() => ActiveCompanySession.set(5));
  tearDown(ActiveCompanySession.clear);

  test('approved quote fetches exact private PDF bytes, scoped to company', () async {
    var requests=0;
    final repository=RemoteQuoteRepository(api:api(MockClient((request) async {
      requests++;
      expect(request.method,'GET');
      expect(request.url.path,'/api/v1/quotes/91/approved-pdf');
      expect(request.headers['Authorization'],'Bearer verified-token');
      expect(request.headers['X-Company-Id'],'5');
      return http.Response(pdfExample,200,
          headers:{'content-type':'application/pdf'});
    })));
    final result=await repository.fetchApprovedPdf(approvedQuote());
    expect(utf8.decode(result),pdfExample);
    expect(requests,1);
  });

  test('missing approved PDF fails closed with server status and no fallback', () async {
    final repository=RemoteQuoteRepository(api:api(MockClient((_) async =>
        http.Response(jsonEncode({
          'message':'This quote has no verified approved PDF.',
        }),409,headers:{'content-type':'application/json'}))));
    await expectLater(repository.fetchApprovedPdf(approvedQuote()),
        throwsA(isA<SignApiException>().having(
          (e)=>e.statusCode,'statusCode',409)));
  });

  test('rejects non-PDF responses, stale company and unapproved documents', () async {
    var requests=0;
    final repository=RemoteQuoteRepository(api:api(MockClient((_) async {
      requests++;
      return http.Response('<html>Error page</html>',200,
          headers:{'content-type':'text/html'});
    })));
    await expectLater(repository.fetchApprovedPdf(approvedQuote()),
        throwsA(isA<SignApiException>()));
    final wrongCompany=approvedQuote(company:'6');
    await expectLater(repository.fetchApprovedPdf(wrongCompany),
        throwsA(isA<SignApiException>()));
    final draft=approvedQuote()..approvedLocally=false;
    await expectLater(repository.fetchApprovedPdf(draft),
        throwsA(isA<SignApiException>()));
    expect(requests,1);
  });
}
