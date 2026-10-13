import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sign2digital/features/jobs/services/voice_job_extraction_service.dart';

void main() {
  test('OpenAI requires a runtime key and does not persist it', () {
    final service = OpenAiVoiceJobExtractionService();
    expect(service.isConfigured, false);
    service.setTemporaryApiKey('temporary-test-key');
    expect(service.isConfigured, true);
    service.clearTemporaryApiKey();
    expect(service.isConfigured, false);
  });

  test(
    'transcription followed by JSON extraction returns validated fields',
    () async {
      final dir = await Directory.systemTemp.createTemp('voice_service_test_');
      addTearDown(() async {
        await dir.delete(recursive: true);
      });
      final file = File('${dir.path}/spoken_job.m4a');
      await file.writeAsBytes([1, 2, 3, 4]);

      final requested = <String>[];
      final service = OpenAiVoiceJobExtractionService(
        client: MockClient((req) async {
          requested.add(req.url.path);
          expect(req.headers['authorization'], 'Bearer temporary-test-key');
          if (req.url.path == '/v1/audio/transcriptions') {
            return http.Response(
              '{"text":"Renovate terrace for Alpine."}',
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          if (req.url.path == '/v1/chat/completions') {
            return http.Response(
              '''{
          "choices": [{"message": {"content": "{\\"clientName\\":\\"Alpine Renovations\\",\\"address\\":\\"Lausanne\\",\\"description\\":\\"Renovate terrace\\",\\"startDate\\":null,\\"endDate\\":null,\\"budgetChf\\":2500,\\"teamMemberNames\\":[\\"Sophie Bernard\\"]}"}}
          ]}''',
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response('not found', 404);
        }),
      );
      service.setTemporaryApiKey('temporary-test-key');

      final result = await service.extract(file.path);
      expect(result.clientName, 'Alpine Renovations');
      expect(result.address, 'Lausanne');
      expect(result.budgetChf, 2500);
      expect(result.startDate, isNull);
      expect(result.teamMemberNames, ['Sophie Bernard']);
      expect(result.transcript, 'Renovate terrace for Alpine.');
      expect(requested, ['/v1/audio/transcriptions', '/v1/chat/completions']);
    },
  );

  test(
    'rejected key raises an authentication error, not a fake success',
    () async {
      final dir = await Directory.systemTemp.createTemp('voice_auth_test_');
      addTearDown(() async {
        await dir.delete(recursive: true);
      });
      final file = File('${dir.path}/spoken_job.m4a');
      await file.writeAsBytes([1]);
      final service = OpenAiVoiceJobExtractionService(
        client: MockClient((req) async => http.Response('unauthorized', 401)),
      );
      service.setTemporaryApiKey('bad-test-key');
      await expectLater(
        service.extract(file.path),
        throwsA(isA<VoiceAiAuthenticationException>()),
      );
    },
  );
}
