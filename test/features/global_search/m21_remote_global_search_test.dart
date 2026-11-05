import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sign2digital/core/services/active_company_session.dart';
import 'package:sign2digital/core/services/sign_api_client.dart';
import 'package:sign2digital/features/global_search/data/global_search_source.dart';
import 'package:sign2digital/features/global_search/data/remote_global_search_provider.dart';

SignApiClient api(Future<http.Response> Function(http.Request) handler) =>
    SignApiClient(
      baseUrl: Uri.parse('https://example.test'),
      tokenProvider: () async => 'test-token',
      activeCompanyId: () => ActiveCompanySession.companyId,
      httpClient: MockClient(handler),
    );

Map<String, dynamic> hit(String type, int id, {int company = 8}) => {
  'id': id, 'company_id': company, 'type': type,
  'title': 'Search result $id', 'subtitle': 'Reference $id',
  'reference': 'REF-$id', 'status': 'draft', 'date': '2026-11-06',
};

http.Response response(List<Map<String, dynamic>> hits, {
  int page = 1, int total = 1, bool hasMore = false,
}) => http.Response(jsonEncode({'data': {
  'records': hits,
  'pagination': {'page': page, 'per_page': 25,
    'total': total, 'last_page': hasMore ? page + 1 : page,
    'has_more': hasMore},
}}), 200);

void main() {
  setUp(() => ActiveCompanySession.set(8));
  tearDown(ActiveCompanySession.clear);

  test('live search sends selected company and all combined filters', () async {
    final provider = RemoteGlobalSearchProvider(api: api((request) async {
      expect(request.url.path, '/api/v1/search');
      expect(request.headers['X-Company-Id'], '8');
      expect(request.headers['Authorization'], 'Bearer test-token');
      expect(request.url.queryParameters, containsPair('q', 'window'));
      expect(request.url.queryParameters, containsPair('types', 'jobs'));
      expect(request.url.queryParameters, containsPair('company_id', '8'));
      expect(request.url.queryParameters, containsPair('client_id', '7'));
      expect(request.url.queryParameters, containsPair('job_id', '12'));
      expect(request.url.queryParameters, containsPair('status', 'planning'));
      expect(request.url.queryParameters, containsPair('date_from', '2026-11-01'));
      expect(request.url.queryParameters, containsPair('date_to', '2026-11-30'));
      expect(request.url.queryParameters, containsPair('page', '2'));
      return response([hit('jobs', 12)], page: 2, total: 33, hasMore: true);
    }));
    final page = await provider.search(query: 'window',
      tab: GlobalSearchTab.jobs, page: 2,
      filters: const GlobalSearchFilters(
        clientId: '7', jobId: '12', status: 'planning',
        dateFrom: '2026-11-01', dateTo: '2026-11-30'));
    expect(page.total, 33);
    expect(page.hasMore, true);
    expect(page.records.single.id, '12');
    expect(page.records.single.category, GlobalSearchCategory.jobs);
    expect((page.records.single.record as GlobalSearchHit).companyId, 8);
  });

  test('quotes and general documents are real supported categories', () async {
    final provider = RemoteGlobalSearchProvider(api: api(
        (request) async => response([
          hit('quotes', 2), hit('general_documents', 3),
        ], total: 2)));
    final page = await provider.search(
      query: '', tab: GlobalSearchTab.all, page: 1);
    expect(page.records.map((r) => r.category),
      [GlobalSearchCategory.quotes, GlobalSearchCategory.generalDocuments]);
    expect(page.records.last.inTab(GlobalSearchTab.documents), true);
    expect(page.records.first.inTab(GlobalSearchTab.more), true);
  });

  test('a cross-company search response is always rejected', () async {
    final provider = RemoteGlobalSearchProvider(api: api(
      (_) async => response([hit('invoices', 13, company: 99)])));
    await expectLater(provider.search(
      query: '', tab: GlobalSearchTab.all, page: 1),
      throwsA(isA<SignApiException>()));
  });

  test('changing company while a search is pending drops response', () async {
    final provider = RemoteGlobalSearchProvider(api: api((_) async {
      ActiveCompanySession.set(11);
      return response([hit('clients', 2)]);
    }));
    await expectLater(provider.search(
      query: '', tab: GlobalSearchTab.clients, page: 1),
      throwsA(isA<SignApiException>()));
  });

  test('no company context never triggers a network search', () async {
    ActiveCompanySession.clear();
    final provider = RemoteGlobalSearchProvider(api: api(
      (_) async => throw StateError('must not send request')));
    await expectLater(provider.search(
      query: '', tab: GlobalSearchTab.all, page: 1),
      throwsA(isA<SignApiException>()));
  });
}
