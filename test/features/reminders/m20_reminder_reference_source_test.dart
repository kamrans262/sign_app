import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sign2digital/core/services/active_company_session.dart';
import 'package:sign2digital/core/services/sign_api_client.dart';
import 'package:sign2digital/features/reminders/data/remote_reminder_reference_source.dart';
import 'package:sign2digital/features/reminders/domain/reminder_record.dart';

void main() {
  setUp(() => ActiveCompanySession.set(7));
  tearDown(ActiveCompanySession.clear);

  test('Job related items use the verified jobs + pagination contract', () async {
    final requested = <String>[];
    final client = MockClient((request) async {
      expect(request.headers['X-Company-Id'], '7');
      expect(request.url.path, '/api/v1/jobs');
      final category = request.url.queryParameters['category']!;
      requested.add(category);
      return http.Response(jsonEncode({'data':{
        'jobs': category == 'active' ? [
          {
            'id': 17, 'company_id': 7, 'client_id': 9,
            'title': 'Bathroom renovation', 'reference_number': 'JOB-17',
            'client_name': 'Kamran', 'description': 'Bathroom upgrade',
            'category': 'active', 'stage': 'planning',
            'due_date': '2026-12-15', 'progress_percentage': 0,
          },
        ] : [],
        'pagination': {'page': 1, 'last_page': 1, 'total':
          category == 'active' ? 1 : 0},
      }}), 200);
    });
    final api = SignApiClient(
      baseUrl: Uri.parse('https://example.test'),
      tokenProvider: () async => 'test-auth',
      activeCompanyId: () => ActiveCompanySession.companyId,
      httpClient: client,
    );
    final records = await RemoteReminderReferenceSource(api: api)
        .listForType(ReminderType.job);
    expect(records, hasLength(1));
    expect(records.single.id, '17');
    expect(records.single.type, ReminderType.job);
    expect(records.single.title, 'JOB-17 — Bathroom renovation');
    expect(requested, containsAll(['active', 'completed', 'archived']));
    client.close();
  });

  test('Company change invalidates in-flight related item results', () async {
    final client = MockClient((request) async {
      ActiveCompanySession.set(8);
      return http.Response(jsonEncode({'data':{
        'jobs': [], 'pagination': {'page': 1, 'last_page': 1, 'total': 0},
      }}),200);
    });
    final api = SignApiClient(
      baseUrl: Uri.parse('https://example.test'),
      tokenProvider: () async => 'test-auth',
      activeCompanyId: () => ActiveCompanySession.companyId,
      httpClient: client,
    );
    await expectLater(
      RemoteReminderReferenceSource(api: api).listForType(ReminderType.job),
      throwsA(isA<SignApiException>()),
    );
    client.close();
  });
}
