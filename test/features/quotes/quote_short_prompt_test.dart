import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sign2digital/core/services/active_company_session.dart';
import 'package:sign2digital/core/services/sign_api_client.dart';
import 'package:sign2digital/features/quotes/domain/quote_draft_input.dart';
import 'package:sign2digital/features/quotes/domain/quote_extraction_models.dart';
import 'package:sign2digital/features/quotes/services/remote_quote_preparation_service.dart';

void main() {
  setUp(() => ActiveCompanySession.set(5));
  tearDown(ActiveCompanySession.clear);

  test('vague short quote returns clarification with 200 and no invented item',
      () async {
    final sent = <Map<String, dynamic>>[];
    final client = MockClient((request) async {
      expect(request.url.path, '/api/v1/quotes/prepare/text');
      expect(request.headers['X-Company-Id'], '5');
      sent.add(jsonDecode(request.body) as Map<String, dynamic>);
      return http.Response(jsonEncode({
        'data': {'snapshot': {
          'stage': 'needs_clarification',
          'items': [],
          'clarification_question': 'What work should we quote?',
        }}
      }), 200);
    });
    final api = SignApiClient(
      baseUrl: Uri.parse('https://example.test'),
      httpClient: client,
      tokenProvider: () async => 'token',
      activeCompanyId: () => ActiveCompanySession.companyId,
    );
    final original = QuoteDraftInput(
      method: QuoteInputMethod.text,
      createdAt: DateTime(2026, 11, 14),
      description: 'Bathroom quotation',
      clarification: 'Replace the sink.',
      jobId: '91',
      clientId: '55',
    );
    final results = await RemoteQuotePreparationService(api: api)
        .prepare(original).toList();
    expect(results.last.stage, QuotePreparationStage.needsClarification);
    expect(results.last.items, isEmpty);
    expect(results.last.clarificationQuestion, 'What work should we quote?');
    expect(sent.single['text'], 'Bathroom quotation');
    expect(sent.single['clarification'], 'Replace the sink.');
    expect(sent.single.containsKey('client_id'), isFalse);
    client.close();
  });

  test('short actionable prompt produces unpriced review items', () async {
    final client = MockClient((_) async => http.Response(jsonEncode({
      'data': {'snapshot': {
        'stage':'completed',
        'items':[{
          'title':'Paint bedroom', 'description':'',
          'quantity':null,'dimensions':null,
        }],
      }}
    }),200));
    final api = SignApiClient(
      baseUrl: Uri.parse('https://example.test'),
      httpClient: client,
      tokenProvider: () async => 'token',
      activeCompanyId: () => ActiveCompanySession.companyId,
    );
    final results = await RemoteQuotePreparationService(api: api)
      .prepare(QuoteDraftInput(
        method: QuoteInputMethod.text,
        description: 'Paint bedroom',
        createdAt: DateTime(2026, 11, 14),
      )).toList();
    expect(results.last.stage, QuotePreparationStage.completed);
    expect(results.last.items.single.title, 'Paint bedroom');
    expect(results.last.items.single.quantity, isNull);
    client.close();
  });
}
