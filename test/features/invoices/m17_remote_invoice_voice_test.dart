import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:sign2digital/core/services/active_company_session.dart';
import 'package:sign2digital/core/services/sign_api_client.dart';
import 'package:sign2digital/features/invoices/services/invoice_voice_extraction_service.dart';

void main() {
  setUp(() => ActiveCompanySession.set(7));
  tearDown(ActiveCompanySession.clear);

  test('invoice voice uses signed-in company backend without any API key', () async {
    final temp = await Directory.systemTemp.createTemp('invoice-voice-');
    addTearDown(() => temp.delete(recursive: true));
    final voice = File.fromUri(temp.uri.resolve('invoice.m4a'));
    await voice.writeAsBytes(List<int>.filled(24, 1));
    var uploaded = 0;
    final api = SignApiClient(
      baseUrl: Uri.parse('https://example.test'),
      tokenProvider: () async => 'login-session-token',
      activeCompanyId: () => ActiveCompanySession.companyId,
      httpClient: MockClient((request) async {
        uploaded++;
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/invoices/ai/voice');
        expect(request.headers['Authorization'], 'Bearer login-session-token');
        expect(request.headers['X-Company-Id'], '7');
        expect(request.headers.entries.any((entry) =>
          entry.key.toLowerCase() == 'content-type' &&
          entry.value.contains('multipart/form-data')), isTrue);
        return http.Response(jsonEncode({
          'data': {
            'suggestion': {
              'jobReference': 'JOB-8', 'clientName': 'Marie Dubois',
              'invoiceNumber': null, 'iban': null, 'issueDate': null,
              'dueDate': null, 'notes': 'Installed two windows',
              'items': [
                {'description': 'Windows', 'quantity': 2, 'unitPrice': 85},
                {'description': 'Unpriced labour', 'quantity': 1,
                  'unitPrice': null},
              ],
            },
            'saved': false, 'approved': false, 'issued': false,
            'requires_user_review': true,
          },
        }), 200);
      }),
    );
    final suggestion =
        await RemoteInvoiceVoiceExtractionService(api: api).extract(voice.path);
    expect(suggestion.clientName, 'Marie Dubois');
    expect(suggestion.items, hasLength(2));
    expect(suggestion.items[0].unitPriceMinor, 8500);
    expect(suggestion.items[1].unitPriceMinor, isNull);
    expect(uploaded, 1);
    api.dispose();
  });

  test('invoice voice rejects missing company before upload', () async {
    ActiveCompanySession.clear();
    final api = SignApiClient(
      baseUrl: Uri.parse('https://example.test'),
      tokenProvider: () async => 'login-session-token',
      activeCompanyId: () => ActiveCompanySession.companyId,
      httpClient: MockClient((_) async =>
          throw StateError('Should not contact backend')),
    );
    await expectLater(
      RemoteInvoiceVoiceExtractionService(api: api).extract('nonexistent.m4a'),
      throwsA(isA<SignApiException>()),
    );
    api.dispose();
  });

  test('untrusted AI response cannot mark invoice approved or issued', () async {
    final temp = await Directory.systemTemp.createTemp('invoice-voice-');
    addTearDown(() => temp.delete(recursive: true));
    final voice = File.fromUri(temp.uri.resolve('invoice.m4a'));
    await voice.writeAsBytes(List<int>.filled(24, 1));
    final api = SignApiClient(
      baseUrl: Uri.parse('https://example.test'),
      tokenProvider: () async => 'login-session-token',
      activeCompanyId: () => ActiveCompanySession.companyId,
      httpClient: MockClient((_) async => http.Response(jsonEncode({
        'data': {
          'suggestion': {'notes': 'some work', 'items': []},
          'saved': false, 'approved': true, 'issued': false,
          'requires_user_review': true,
        },
      }), 200)),
    );
    await expectLater(
      RemoteInvoiceVoiceExtractionService(api: api).extract(voice.path),
      throwsA(isA<SignApiException>()),
    );
    api.dispose();
  });
}
