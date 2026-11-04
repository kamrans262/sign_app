import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sign2digital/core/services/active_company_session.dart';
import 'package:sign2digital/core/services/sign_api_client.dart';
import 'package:sign2digital/features/documents/data/remote_document_repository.dart';
import 'package:sign2digital/features/documents/domain/document_record.dart';
import 'package:sign2digital/features/documents/presentation/screens/document_details_screen.dart';
import 'package:sign2digital/features/quotes/domain/quote_review_models.dart';

void main() {
  setUp(() => ActiveCompanySession.set(5));
  tearDown(ActiveCompanySession.clear);

  Map<String, dynamic> catalog(String status, int revision, bool hasPdf) => {
    'data': {
      'document': {
        'id': 'quote-7', 'kind': 'quote', 'number': 'Q-7',
        'title': 'Quote Q-7', 'category': 'quotes',
        'status': status, 'version': revision,
        'has_pdf': hasPdf,
        'sha256': hasPdf ? List.filled(64, 'a').join() : null,
        'created_at': '2026-11-04T09:00:00Z',
      },
      'history': [], 'attachments': [], 'related': [],
    },
  };

  Map<String, dynamic> quote(String status, int revision, {int company = 5}) => {
    'data': {'quote': {
      'id': 7, 'company_id': company, 'quote_number': 'Q-7',
      'revision': revision, 'status': status, 'quote_date': '2026-11-04',
      'valid_until': '2026-11-30', 'client_name': 'Quote customer',
      'currency': 'CHF', 'vat_basis_points': 810,
      'deposit_basis_points': 3000, 'terms': 'Actual saved quote terms',
      'items': [{
        'id': 9, 'title': 'Electrical repair', 'description': 'Repair outlet',
        'quantity': 2, 'unit_price_minor': 12000,
      }],
    }},
  };

  SignApiClient makeApi(String status, int revision, {bool hasPdf = false,
      bool forbidden = false, int quoteRevision = 0, int quoteCompany = 5,
      List<String>? calls}) => SignApiClient(
    baseUrl: Uri.parse('https://example.test'),
    tokenProvider: () async => 'token',
    activeCompanyId: () => ActiveCompanySession.companyId,
    httpClient: MockClient((request) async {
      calls?.add(request.url.path);
      expect(request.headers['X-Company-Id'], '5');
      expect(request.headers['Authorization'], 'Bearer token');
      if (request.url.path == '/api/v1/documents/quote-7') {
        return http.Response(jsonEncode(catalog(status, revision, hasPdf)), 200);
      }
      if (request.url.path == '/api/v1/quotes/7') {
        if (forbidden) {
          return http.Response(jsonEncode({'message': 'Unauthorized'}), 403);
        }
        return http.Response(jsonEncode(quote(
          status, quoteRevision > 0 ? quoteRevision : revision,
          company: quoteCompany,
        )), 200);
      }
      throw StateError('Unexpected endpoint');
    }),
  );

  test('old M6 draft now loads actual persisted items in M9 document preview',
      () async {
    final calls = <String>[];
    final detail = await RemoteDocumentRepository(
      api: makeApi('draft', 1, calls: calls),
    ).details('quote-7');
    expect(detail.quote?.items.single.title, 'Electrical repair');
    expect(detail.quote?.items.single.quantity, '2');
    expect(detail.quote?.items.single.priceMinor, 12000);
    expect(detail.quote?.serverRevision, 1);
    expect(detail.verifiedSignedPdfAvailable, isFalse);
    expect(calls, ['/api/v1/documents/quote-7', '/api/v1/quotes/7']);
  });

  test('legacy approved quote can preview data but cannot export fake PDF',
      () async {
    final repository = RemoteDocumentRepository(
      api: makeApi('approved', 2),
    );
    final detail = await repository.details('quote-7');
    expect(detail.quote?.approvedLocally, isTrue);
    expect(detail.verifiedSignedPdfAvailable, isFalse);
    await expectLater(repository.downloadPdf(detail),
        throwsA(isA<SignApiException>()));
  });

  test('document-only member sees details but not forbidden quote items',
      () async {
    final detail = await RemoteDocumentRepository(
      api: makeApi('draft', 1, forbidden: true),
    ).details('quote-7');
    expect(detail.number, 'Q-7');
    expect(detail.quote, isNull);
  });

  test('cross-company or stale quote content cannot be previewed', () async {
    await expectLater(RemoteDocumentRepository(
      api: makeApi('draft', 1, quoteCompany: 8),
    ).details('quote-7'), throwsA(isA<SignApiException>()));
    await expectLater(RemoteDocumentRepository(
      api: makeApi('draft', 1, quoteRevision: 2),
    ).details('quote-7'), throwsA(isA<SignApiException>()));
  });

  test('approved quotes with frozen PDF never ask to rebuild from items',
      () async {
    final calls = <String>[];
    final doc = await RemoteDocumentRepository(
      api: makeApi('approved', 2, hasPdf: true, calls: calls),
    ).details('quote-7');
    expect(doc.verifiedSignedPdfAvailable, isTrue);
    expect(doc.quote, isNull);
    expect(calls, ['/api/v1/documents/quote-7']);
  });

  testWidgets('legacy approved quote displays original layout with warning',
      (tester) async {
    final quote = QuoteReviewDraft(
      id: 'server-quote-7', serverId: 7, companyId: '5',
      quoteNumber: 'Q-7', date: DateTime(2026, 11, 4),
      clientName: 'Quote customer', terms: 'Saved terms',
      items: [QuoteReviewWorkItem(
        id: '9', title: 'Electrical repair', description: 'Repair outlet',
        quantity: '2', unitPrice: '120.00',
      )],
    );
    await tester.pumpWidget(MaterialApp(home: DocumentDetailsScreen(
      documentId: 'quote-7',
      document: DocumentRecord(
        id: 'quote-7', category: DocumentCategory.quotes,
        number: 'Q-7', title: 'Quote Q-7',
        project: 'Repair project', customer: 'Quote customer',
        timestamp: DateTime(2026, 11, 4),
        status: 'approved', quote: quote,
      ),
      initialTab: 1,
    )));
    expect(find.byKey(const Key('document-read-only-quote-preview')),
        findsOneWidget);
    expect(find.textContaining('UNVERIFIED QUOTE PREVIEW'), findsOneWidget);
    expect(find.textContaining('Electrical repair'), findsWidgets);
    expect(find.byKey(const Key('document-pdf-preview')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
