import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sign2digital/core/services/active_company_session.dart';
import 'package:sign2digital/core/services/sign_api_client.dart';
import 'package:sign2digital/features/quotes/data/remote_quote_repository.dart';
import 'package:sign2digital/features/quotes/domain/quote_review_models.dart';
import 'package:sign2digital/features/quotes/domain/quote_tracking_home_session.dart';
import 'package:sign2digital/features/quotes/presentation/screens/send_quote_screen.dart';

QuoteReviewDraft sampleQuote({String number = 'R-2026/004'}) =>
    QuoteReviewDraft(
      id: 'local-test-quote',
      clientId: '8',
      jobId: '11',
      companyId: '5',
      clientName: 'A. Example',
      quoteNumber: number,
      date: DateTime(2026, 11, 3),
      terms: 'Verified contract terms',
      items: [
        QuoteReviewWorkItem(
          id: '1',
          title: 'Window service',
          description: 'Replace one pane',
          quantity: '1',
          unitPrice: '160.00',
        ),
      ],
    );

SignApiClient fakeClient(http.Client httpClient) => SignApiClient(
      baseUrl: Uri.parse('https://api.example.test'),
      httpClient: httpClient,
      activeCompanyId: () => ActiveCompanySession.companyId,
      tokenProvider: () async => 'test-token',
    );

void main() {
  setUp(() => ActiveCompanySession.set(5));
  tearDown(() {
    ActiveCompanySession.clear();
    QuoteReviewSessionStore.clear();
    QuoteSendSessionStore.clear();
    QuoteTrackingHomeSession.clear();
  });

  test('switching company clears local quote draft and prevents reappearance',
      () {
    final quote = sampleQuote();
    QuoteReviewSessionStore.save(quote);
    expect(QuoteReviewSessionStore.load(quote.id), isNotNull);
    ActiveCompanySession.set(6);
    expect(QuoteReviewSessionStore.load(quote.id), isNull);
    expect(QuoteReviewSessionStore.savedDrafts, isEmpty);
    ActiveCompanySession.set(5);
    expect(QuoteReviewSessionStore.load(quote.id), isNull);
  });

  test('logout clears recipient message and quote tracking in memory', () {
    final quote = sampleQuote();
    final recipient = QuoteSendDraft(
      name: 'Private Customer',
      email: 'customer@example.test',
      phone: '12345',
      address: 'Confidential Street',
      message: 'Internal terms',
    );
    QuoteSendSessionStore.save(quote.id, recipient);
    QuoteTrackingHomeSession.remember(quote);
    expect(QuoteSendSessionStore.load(quote.id)?.email,
        'customer@example.test');
    expect(QuoteTrackingHomeSession.currentQuote, isNotNull);
    ActiveCompanySession.clear();
    expect(QuoteSendSessionStore.load(quote.id), isNull);
    expect(QuoteTrackingHomeSession.currentQuote, isNull);
  });

  test('server retains user editable quote number separately from reference',
      () async {
    var requests = 0;
    final service = RemoteQuoteRepository(
      api: fakeClient(MockClient((request) async {
        requests += 1;
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/quotes');
        expect(request.headers['X-Company-Id'], '5');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['quote_number'], 'R-2026/004');
        expect(body.containsKey('reference_number'), isFalse);
        expect(body.containsKey('status'), isFalse);
        return http.Response(jsonEncode({
          'data': {
            'quote': {
              'id': 52,
              'company_id': 5,
              'reference_number': 'Q-2026-000052',
              'quote_number': 'R-2026/004',
              'status': 'draft',
              'revision': 1,
            },
          },
        }), 201);
      })),
    );
    final saved = await service.saveDraft(sampleQuote());
    expect(saved.serverId, 52);
    expect(saved.quoteNumber, 'R-2026/004');
    expect(saved.approvedLocally, isFalse);
    expect(requests, 1);
  });

  test('cannot share an unapproved quote or fabricated demo quote', () async {
    final repo = RemoteQuoteRepository(api: fakeClient(MockClient((_) async {
      throw StateError('No network request should be made');
    })));
    final unsent = sampleQuote();
    unsent.serverId = 100;
    await expectLater(
      repo.share(unsent, method: 'email', email: 'customer@example.test'),
      throwsA(isA<SignApiException>()),
    );
    final demo = QuoteReviewDraft.figmaDemo();
    await expectLater(
      repo.saveDraft(demo),
      throwsA(isA<SignApiException>()),
    );
  });

  test('approved email with Attach PDF sends the real PDF multipart',
      () async {
    var requests=0;
    final repository=RemoteQuoteRepository(
      api:fakeClient(MockClient((request) async {
        requests++;
        expect(request.method,'POST');
        expect(request.url.path,'/api/v1/quotes/91/share-email-pdf');
        expect(request.headers['Authorization'],'Bearer test-token');
        expect(request.headers['X-Company-Id'],'5');
        expect(request.headers['content-type']?.contains('multipart/form-data'),
            isTrue);
        return http.Response(jsonEncode({'data':{
          'delivered':true,'pdf_attached':true,
        }}),200);
      })),
    );
    final approved=sampleQuote();
    approved.serverId=91;
    approved.approvedLocally=true;
    approved.serverStatus='approved';
    final pdf=Uint8List.fromList(utf8.encode(
      '%PDF-1.7\n1 0 obj\n<</Type/Catalog>>\nendobj\n%%EOF\n'));
    final result=await repository.shareEmailWithPdf(approved,
      email:'customer@example.test',
      message:'Please check the attached quote',
      pdfBytes:pdf,
    );
    expect(result['delivered'],true);
    expect(result['pdf_attached'],true);
    expect(requests,1);
  });

  test('invalid or oversized PDF is rejected before the email network call',
      () async {
    final repo=RemoteQuoteRepository(api:fakeClient(MockClient((_) async {
      throw StateError('Must not send invalid PDF to server');
    })));
    final quote=sampleQuote();
    quote.serverId=91;
    quote.approvedLocally=true;
    await expectLater(repo.shareEmailWithPdf(quote,
      email:'customer@example.test',message:'',
      pdfBytes:Uint8List.fromList([1,2,3,4,5,6,7,8,9]),
    ),throwsA(isA<SignApiException>()));
    await expectLater(repo.shareEmailWithPdf(quote,
      email:'customer@example.test',message:'',
      pdfBytes:Uint8List(5*1024*1024+1),
    ),throwsA(isA<SignApiException>()));
  });

  test('company switch stops save before presenting foreign quote response',
      () async {
    final repo = RemoteQuoteRepository(api: fakeClient(MockClient((request) async {
      ActiveCompanySession.set(6);
      return http.Response(jsonEncode({
        'data': {
          'quote': {
            'id': 52,
            'company_id': 5,
            'reference_number': 'Q-2026-000052',
            'quote_number': 'R-2026/004',
            'status': 'draft',
            'revision': 1,
          },
        },
      }), 201);
    })));
    await expectLater(
      repo.saveDraft(sampleQuote()),
      throwsA(isA<SignApiException>()),
    );
  });
}
