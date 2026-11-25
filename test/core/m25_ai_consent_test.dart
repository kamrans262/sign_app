import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sign2digital/core/services/sign_api_client.dart';

void main() {
  tearDown(() => SignApiClient.aiConsentPrompt = null);
  test('declined consent sends no AI payload and does not block manual features', () async {
    var sends = 0;
    final api = SignApiClient(baseUrl: Uri.parse('https://example.test'),
      tokenProvider: () async => 'test-token',
      httpClient: MockClient((request) async {
        sends++;
        expect(request.url.path, '/api/v1/jobs');
        return http.Response('{}',200);
      }));
    SignApiClient.aiConsentPrompt = (_) async {
      throw const SignApiException('AI permission declined.');
    };
    await expectLater(api.post('/api/v1/quotes/prepare/text',
      data: {'text':'private data'}), throwsA(isA<SignApiException>()));
    expect(sends,0);
    await api.post('/api/v1/jobs', data: {'title':'Manual job'});
    expect(sends,1);
  });
  test('account change during consent prevents request', () async {
    var token = 'first';
    final api = SignApiClient(baseUrl: Uri.parse('https://example.test'),
      tokenProvider: () async => token,
      httpClient: MockClient((request) async {
        fail('AI data must not be sent under a different account');
      }));
    SignApiClient.aiConsentPrompt = (_) async {token='second';};
    await expectLater(api.post('/api/v1/support/assistant',
      data: {'message':'private data'}),throwsA(isA<SignApiException>()));
  });
}
