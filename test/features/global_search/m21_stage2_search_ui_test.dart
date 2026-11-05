import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sign2digital/core/services/active_company_session.dart';
import 'package:sign2digital/core/services/sign_api_client.dart';
import 'package:sign2digital/features/company/data/remote_company_repository.dart';
import 'package:sign2digital/features/global_search/data/global_search_source.dart';
import 'package:sign2digital/features/global_search/data/global_search_filter_picker.dart';
import 'package:sign2digital/features/global_search/data/remote_global_search_provider.dart';
import 'package:sign2digital/features/global_search/presentation/screens/global_search_screen.dart';

SignApiClient _api(Future<http.Response> Function(http.Request request) serve) =>
  SignApiClient(
    baseUrl: Uri.parse('https://example.test'),
    tokenProvider: () async => 'verified-test-token',
    activeCompanyId: () => ActiveCompanySession.companyId,
    httpClient: MockClient(serve),
  );

http.Response _page(List<Map<String, dynamic>> records, {
  int page = 1, int total = 1, bool hasMore = false,
}) => http.Response(jsonEncode({'data': {
  'records': records,
  'pagination': {
    'page': page, 'per_page': 25, 'total': total,
    'last_page': hasMore ? page + 1 : page, 'has_more': hasMore,
  },
}}), 200);

Map<String, dynamic> _hit(int id, String name, {
  String type = 'jobs', int company = 8,
}) => {
  'type': type, 'id': id, 'company_id': company, 'title': name,
  'subtitle': 'Job ref', 'reference': 'J-$id',
  'status': 'planning', 'date': '2026-11-06',
};

void main() {
  setUp(() => ActiveCompanySession.set(8));
  tearDown(ActiveCompanySession.clear);

  test('date validation rejects normalized/invalid calendar dates', () {
    expect(GlobalSearchFilterPicker.validDay(''), true);
    expect(GlobalSearchFilterPicker.validDay('2026-11-06'), true);
    expect(GlobalSearchFilterPicker.validDay('2026-02-30'), false);
    expect(GlobalSearchFilterPicker.validDay('2026-13-01'), false);
    expect(GlobalSearchFilterPicker.validDay('2026-1-1'), false);
  });

  testWidgets('real search uses server count, fetches pages and preserves original cards',
      (tester) async {
    final pages = <int>[];
    final client = _api((request) async {
      expect(request.url.path, '/api/v1/search');
      expect(request.headers['X-Company-Id'], '8');
      final page = int.parse(request.url.queryParameters['page']!);
      pages.add(page);
      if (page == 1) {
        return _page([
          _hit(1, 'First kitchen installation'),
          _hit(2, 'Second kitchen installation'),
        ], total: 3, hasMore: true);
      }
      return _page([_hit(3, 'Third kitchen installation')],
        page: 2, total: 3);
    });
    await tester.pumpWidget(MaterialApp(
      home: GlobalSearchScreen(provider: RemoteGlobalSearchProvider(api: client))));
    await tester.pumpAndSettle();
    expect(find.text('Results (3)'), findsOneWidget);
    expect(find.text('First kitchen installation'), findsOneWidget);
    expect(find.text('Third kitchen installation'), findsNothing);
    await tester.tap(find.byKey(const Key('global-search-see-all')));
    await tester.pumpAndSettle();
    expect(pages, [1, 2]);
    expect(find.text('Third kitchen installation'), findsOneWidget);
    expect(find.text('All shown'), findsOneWidget);
  });

  testWidgets('fast typing invalidates an older response before debounce expires',
      (tester) async {
    final original = Completer<http.Response>();
    final incoming = Completer<http.Response>();
    final client = _api((request) async {
      if (request.url.queryParameters['q'] == 'new') return incoming.future;
      return original.future;
    });
    await tester.pumpWidget(MaterialApp(
      home: GlobalSearchScreen(provider: RemoteGlobalSearchProvider(api: client))));
    await tester.pump(const Duration(milliseconds: 40));
    await tester.enterText(
      find.byKey(const Key('clients-search-input')), 'new');
    await tester.pump(const Duration(milliseconds: 370));
    incoming.complete(_page([_hit(2, 'New job')]));
    await tester.pumpAndSettle();
    expect(find.text('New job'), findsOneWidget);
    original.complete(_page([_hit(1, 'Stale job')]));
    await tester.pumpAndSettle();
    expect(find.text('Stale job'), findsNothing);
    expect(find.text('Results (1)'), findsOneWidget);
  });

  testWidgets('live company switch invalidates previous tenant results',
      (tester) async {
    final a = Completer<http.Response>();
    final client = _api((request) async {
      if (request.headers['X-Company-Id'] == '8') return a.future;
      return _page([_hit(4, 'Company B job', company: 9)]);
    });
    await tester.pumpWidget(MaterialApp(
      home: GlobalSearchScreen(provider: RemoteGlobalSearchProvider(api: client))));
    await tester.pump(const Duration(milliseconds: 20));
    ActiveCompanySession.set(9);
    await tester.pumpAndSettle();
    expect(find.text('Company B job'), findsOneWidget);
    expect(find.text('Company #9'), findsOneWidget);
    a.complete(_page([_hit(3, 'Company A job')]));
    await tester.pumpAndSettle();
    expect(find.text('Company A job'), findsNothing);
  });

  testWidgets('filter picker selects an existing client by name instead of numeric input',
      (tester) async {
    GlobalSearchFilters? selected;
    final api = _api((request) async {
      if (request.url.path == '/api/v1/companies') {
        return http.Response(jsonEncode({'data': {
          'companies': [{'id': 8, 'name': 'Alpha Company',
            'country_iso_code': 'CH', 'role': 'owner'}],
          'active_company_id': 8,
        }}), 200);
      }
      if (request.url.path == '/api/v1/search') {
        expect(request.url.queryParameters['types'], 'clients');
        return _page([_hit(77, 'Mina Works', type: 'clients')]);
      }
      throw StateError('Unexpected request: ${request.url.path}');
    });
    final companies = RemoteCompanyRepository(api: api);
    final provider = RemoteGlobalSearchProvider(api: api);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(
      builder: (context) => FilledButton(
        onPressed: () async {
          selected = await GlobalSearchFilterPicker.show(context,
            const GlobalSearchFilters(),
            companyRepository: companies, searchProvider: provider);
        },
        child: const Text('Open filters'),
      ),
    ))));
    await tester.tap(find.text('Open filters'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('global-search-filter-sheet')), findsOneWidget);
    await tester.tap(find.text('Client'));
    await tester.pumpAndSettle();
    expect(find.text('Mina Works'), findsOneWidget);
    await tester.tap(find.text('Mina Works'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('search-apply-filters')));
    await tester.tap(find.byKey(const Key('search-apply-filters')));
    await tester.pumpAndSettle();
    expect(selected?.clientId, '77');
  });

  testWidgets('original search screen fits narrow phones and full-width landscape',
      (tester) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: GlobalSearchScreen(
      provider: RemoteGlobalSearchProvider(api: _api((_) async =>
        _page([_hit(1, 'Landscape installation')]))))));
    await tester.pumpAndSettle();
    final scroll = tester.renderObject<RenderBox>(
      find.byKey(const Key('global-search-scroll')));
    expect(scroll.size.width, greaterThan(800));
    expect(tester.takeException(), isNull);
  });
}
