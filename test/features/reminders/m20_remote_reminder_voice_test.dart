import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:sign2digital/core/services/active_company_session.dart';
import 'package:sign2digital/core/services/sign_api_client.dart';
import 'package:sign2digital/features/reminders/services/remote_reminder_voice_extraction_service.dart';

void main() {
  setUp(() => ActiveCompanySession.set(7));
  tearDown(ActiveCompanySession.clear);

  test('M20 reminder AI sends audio to authenticated tenant backend without API key', () async {
    final dir = await Directory.systemTemp.createTemp('reminder-ai-');
    addTearDown(() => dir.delete(recursive: true));
    final recording = File.fromUri(dir.uri.resolve('reminder.m4a'));
    await recording.writeAsBytes(List<int>.filled(20, 1));
    var calls = 0;
    final api = SignApiClient(
      baseUrl: Uri.parse('https://example.test'),
      tokenProvider: () async => 'test-auth-token',
      activeCompanyId: () => ActiveCompanySession.companyId,
      httpClient: MockClient((request) async {
        calls++;
        expect(request.url.path, '/api/v1/reminders/ai/voice');
        expect(request.method, 'POST');
        expect(request.headers['Authorization'], 'Bearer test-auth-token');
        expect(request.headers['X-Company-Id'], '7');
        return http.Response(jsonEncode({
          'data': {
            'suggestion': {
              'title': 'Follow up with the client',
              'type': 'client',
              'reminderDate': '2026-11-12',
              'reminderTime': '16:00',
              'notes': 'Ask about the quote',
              'relatedItem': null,
            },
            'saved': false, 'scheduled': false, 'notified': false,
            'requires_user_review': true,
          },
        }), 200);
      }),
    );
    final result = await RemoteReminderVoiceExtractionService(api: api)
        .extract(recording.path);
    expect(result.title, 'Follow up with the client');
    expect(result.date, DateTime(2026, 11, 12));
    expect(result.time!.hour, 16);
    expect(calls, 1);
    api.dispose();
  });

  test('M20 reminder AI rejects missing company before network request', () async {
    ActiveCompanySession.clear();
    final api = SignApiClient(
      baseUrl: Uri.parse('https://example.test'),
      tokenProvider: () async => 'test-auth-token',
      activeCompanyId: () => ActiveCompanySession.companyId,
      httpClient: MockClient((_) async => throw StateError('Unexpected call')),
    );
    await expectLater(
      RemoteReminderVoiceExtractionService(api: api).extract('/missing.m4a'),
      throwsA(isA<SignApiException>()),
    );
    api.dispose();
  });
}
