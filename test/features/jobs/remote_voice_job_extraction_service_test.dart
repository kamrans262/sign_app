import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sign2digital/core/services/active_company_session.dart';
import 'package:sign2digital/core/services/sign_api_client.dart';
import 'package:sign2digital/features/jobs/services/remote_voice_job_extraction_service.dart';

void main() {
  setUp(() => ActiveCompanySession.set(5));
  tearDown(ActiveCompanySession.clear);

  test('uses bearer token and verified tenant for real job AI dictation', () async {
    final temp = await Directory.systemTemp.createTemp('s2d-voice-test');
    addTearDown(() => temp.delete(recursive: true));
    final file = File(temp.path + '/recording.m4a');
    await file.writeAsBytes(List<int>.filled(24, 1));

    final api = SignApiClient(
      baseUrl: Uri.parse('https://example.test'),
      tokenProvider: () async => 'test-token',
      activeCompanyId: () => ActiveCompanySession.companyId,
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/ai/jobs/voice');
        expect(request.headers['Authorization'], 'Bearer test-token');
        expect(request.headers['X-Company-Id'], '5');
        expect(request.headers['Content-Type'], contains('multipart/form-data'));
        return http.Response(jsonEncode({
          'data': {
            'suggestions': {
              'clientName': 'Alpine AG',
              'address': 'Lausanne',
              'description': 'Install three windows',
              'startDate': '2026-12-10',
              'endDate': null,
              'budgetChf': 1200,
              'teamMemberNames': ['Marc Dupont'],
            },
            'transcript': 'Install three windows for Alpine AG.',
          },
        }), 200);
      }),
    );
    final details =
        await RemoteVoiceJobExtractionService(api: api).extract(file.path);
    expect(details.clientName, 'Alpine AG');
    expect(details.description, 'Install three windows');
    expect(details.budgetChf, 1200);
    expect(details.transcript, 'Install three windows for Alpine AG.');
    expect(details.teamMemberNames, ['Marc Dupont']);
    api.dispose();
  });

  test('does not upload a job voice file without a selected company', () async {
    ActiveCompanySession.clear();
    final api = SignApiClient(
      baseUrl: Uri.parse('https://example.test'),
      tokenProvider: () async => 'test-token',
      activeCompanyId: () => ActiveCompanySession.companyId,
      httpClient: MockClient((request) async =>
          throw StateError('Unexpected network request')),
    );
    await expectLater(
      RemoteVoiceJobExtractionService(api: api).extract('/missing.m4a'),
      throwsA(isA<SignApiException>()),
    );
    api.dispose();
  });
}
