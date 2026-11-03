import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:sign2digital/core/services/active_company_session.dart';
import 'package:sign2digital/core/services/sign_api_client.dart';
import 'package:sign2digital/core/widgets/sign2digital_input_field.dart';
import 'package:sign2digital/features/auth/presentation/screens/company_entry_gate.dart';
import 'package:sign2digital/features/clients/presentation/screens/clients_screen.dart';
import 'package:sign2digital/features/company/data/remote_company_repository.dart';
import 'package:sign2digital/features/company/presentation/screens/create_company_screen.dart';

import '../../support/scroll_to_visible_action.dart';

Map<String, dynamic> _company(int id) => {
  'id': id,
  'name': 'Alpine Construction AG',
  'country_iso_code': 'CH',
  'role': 'owner',
};

RemoteCompanyRepository _repository(
    Future<http.Response> Function(http.Request) responder) {
  return RemoteCompanyRepository(
    api: SignApiClient(
      baseUrl: Uri.parse('https://example.test'),
      tokenProvider: () async => 'verified-otp-bearer',
      httpClient: MockClient(responder),
    ),
  );
}

Future<void> _openGate(WidgetTester tester,
    RemoteCompanyRepository repository) async {
  tester.view.physicalSize = const Size(430, 932);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(
    home: CompanyEntryGate(repository: repository),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  setUp(ActiveCompanySession.clear);
  tearDown(ActiveCompanySession.clear);

  testWidgets('account without a company stays in required setup, not Home',
      (tester) async {
    var requests = 0;
    final repo = _repository((request) async {
      requests++;
      expect(request.url.path, '/api/v1/companies');
      expect(request.method, 'GET');
      expect(request.headers['Authorization'], 'Bearer verified-otp-bearer');
      return http.Response(
        jsonEncode({'data': {'companies': [], 'active_company_id': null}}),
        200,
      );
    });
    await _openGate(tester, repo);

    expect(find.byType(CreateCompanyScreen), findsOneWidget);
    expect(find.byType(ClientsScreen), findsNothing);
    expect(ActiveCompanySession.companyId, isNull);
    expect(requests, 1);

    await scrollToVisibleAction(
      tester,
      scrollKey: const Key('create-company-scroll'),
      target: find.byKey(const Key('skip-company-optional')),
    );
    await tester.tap(find.byKey(const Key('skip-company-optional')));
    await tester.pump();
    expect(find.text('Enter a company name to continue.'), findsOneWidget);
    expect(find.byType(ClientsScreen), findsNothing);
    expect(requests, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('creating a real company unlocks Home only after server confirms',
      (tester) async {
    var lists = 0;
    var creates = 0;
    final repo = _repository((request) async {
      if (request.url.path == '/api/v1/companies' &&
          request.method == 'GET') {
        lists++;
        final payload = lists == 1
            ? {'data': {'companies': [], 'active_company_id': null}}
            : {'data': {
                'companies': [_company(81)],
                'active_company_id': 81,
              }};
        return http.Response(jsonEncode(payload), 200);
      }
      if (request.url.path == '/api/v1/companies' &&
          request.method == 'POST') {
        creates++;
        expect((jsonDecode(request.body) as Map)['name'],
            'Alpine Construction AG');
        return http.Response(jsonEncode({
          'data': {
            'company': _company(81),
            'active_company_id': 81,
          },
        }), 201);
      }
      return http.Response('{"message":"Not found"}', 404);
    });

    await _openGate(tester, repo);
    expect(find.byType(CreateCompanyScreen), findsOneWidget);
    expect(find.byType(ClientsScreen), findsNothing);

    final name = find.descendant(
      of: find.byType(CreateCompanyScreen),
      matching: find.byType(TextFormField),
    ).first;
    await tester.enterText(name, 'Alpine Construction AG');
    await scrollToVisibleAction(
      tester,
      scrollKey: const Key('create-company-scroll'),
      target: find.byKey(const Key('save-company-button')),
    );
    await tester.tap(find.byKey(const Key('save-company-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(creates, 1);
    expect(lists, 2);
    expect(ActiveCompanySession.companyId, 81);
    expect(find.byType(ClientsScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('existing verified company may enter Home', (tester) async {
    final repo = _repository((request) async =>
      http.Response(jsonEncode({
        'data': {
          'companies': [_company(92)],
          'active_company_id': 92,
        },
      }), 200),
    );
    await _openGate(tester, repo);
    expect(ActiveCompanySession.companyId, 92);
    expect(find.byType(ClientsScreen), findsOneWidget);
    expect(find.byType(CreateCompanyScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('company membership is chosen through server switch when active is missing',
      (tester) async {
    var switched = false;
    final repo = _repository((request) async {
      if (request.url.path == '/api/v1/companies/7/switch') {
        switched = true;
        return http.Response(jsonEncode({
          'data': {'active_company_id': 7, 'company': _company(7)},
        }), 200);
      }
      return http.Response(jsonEncode({
        'data': {'active_company_id': null, 'companies': [_company(7)]},
      }), 200);
    });
    await _openGate(tester, repo);
    expect(switched, true);
    expect(ActiveCompanySession.companyId, 7);
    expect(find.byType(ClientsScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed company lookup blocks Home and permits retry',
      (tester) async {
    var attempts = 0;
    final repo = _repository((request) async {
      attempts++;
      if (attempts == 1) {
        return http.Response('{"message":"Offline"}', 503);
      }
      return http.Response(
        jsonEncode({'data': {'companies': [], 'active_company_id': null}}),
        200,
      );
    });
    await _openGate(tester, repo);
    expect(find.byType(ClientsScreen), findsNothing);
    expect(find.byType(CreateCompanyScreen), findsNothing);
    expect(find.byKey(const Key('retry-company-verification')), findsOneWidget);
    await tester.tap(find.byKey(const Key('retry-company-verification')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(attempts, 2);
    expect(find.byType(CreateCompanyScreen), findsOneWidget);
    expect(find.byType(ClientsScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('each existing company field has its own appropriate hint',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: CreateCompanyScreen()));
    final hints = {
      'Company Name': 'e.g. Alpine Construction AG',
      'Address': 'e.g. Bahnhofstrasse 10, 8001 Zürich',
      'Phone': 'e.g. 79 123 45 67',
      'E-mail': 'e.g. info@alpine.ch',
      'Swiss Company ID (IDE)': 'e.g. CHE-123.456.789',
      'VAT Number': 'e.g. CHE-123.456.789 MWST',
      'IBAN': 'e.g. CH93 0076 2011 6238 5295 7',
      'QR IBAN (optional)': 'e.g. your bank-issued Swiss QR-IBAN',
      'Document Numbering': 'e.g. INV-2026-001',
    };
    final fields = tester.widgetList<Sign2DigitalInputField>(
      find.byType(Sign2DigitalInputField),
    );
    final mapped = {for (final field in fields) field.label: field.hintText};
    expect(mapped, hints);
    expect(tester.takeException(), isNull);
  });
}
