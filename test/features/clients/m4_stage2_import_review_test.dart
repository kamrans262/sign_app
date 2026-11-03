import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sign2digital/core/services/active_company_session.dart';
import 'package:sign2digital/core/services/sign_api_client.dart';
import 'package:sign2digital/features/clients/data/device_phone_contact_source.dart';
import 'package:sign2digital/features/clients/data/remote_client_repository.dart';
import 'package:sign2digital/features/clients/models/import_contact_model.dart';
import 'package:sign2digital/features/clients/presentation/screens/import_clients_screen.dart';

class _FakePhoneContactSource implements PhoneContactSource {
  const _FakePhoneContactSource({this.denied = false});

  final bool denied;

  @override
  Future<List<ImportContactModel>> load() async {
    if (denied) throw StateError('Phone contacts permission was denied.');
    return const [
      ImportContactModel(
        id: 'device-1',
        fullName: 'Alice Test',
        phoneNumber: '+49 170 123 45',
        email: 'alice@example.test',
      ),
      ImportContactModel(
        id: 'device-2',
        fullName: 'Bob Test',
        phoneNumber: '+41 44 555 33',
        email: 'bob@example.test',
      ),
    ];
  }
}

Future<void> _open(
  WidgetTester tester, {
  required PhoneContactSource source,
  required RemoteClientRepository repository,
}) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (_) => ImportClientsScreen(
                contactSource: source,
                clientRepository: repository,
              ),
            ),
          ),
          child: const Text('Open import'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('Open import'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => ActiveCompanySession.set(12));
  tearDown(ActiveCompanySession.clear);

  testWidgets('phone import requires selection, review and second confirmation',
      (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var uploadCount = 0;
    final api = SignApiClient(
      baseUrl: Uri.parse('https://example.test'),
      tokenProvider: () async => 'test-token',
      activeCompanyId: () => ActiveCompanySession.companyId,
      httpClient: MockClient((request) async {
        uploadCount++;
        expect(request.url.path, '/api/v1/clients/import');
        expect(request.headers['X-Company-Id'], '12');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final submitted = body['clients'] as List<dynamic>;
        expect(submitted, hasLength(1));
        final only = submitted.single as Map<String, dynamic>;
        expect(only['full_name'], 'Alice Test');
        expect(only['phone_number'], '+49 170 123 45');
        expect(only['email'], 'alice@example.test');
        // An address-book contact does not prove it is Swiss.
        expect(only['country_iso_code'], '');
        expect(body.containsKey('company_id'), false);
        return http.Response(jsonEncode({
          'data': {
            'clients': [
              {'id': 501, 'company_id': 12},
            ],
            'imported_count': 1,
          },
        }), 201);
      }),
    );

    await _open(tester,
      source: const _FakePhoneContactSource(),
      repository: RemoteClientRepository(api: api));

    expect(find.text('Choose Phone Contacts'), findsOneWidget);
    expect(find.text('Alice Test'), findsNothing);
    expect(uploadCount, 0);

    await tester.tap(find.byKey(const Key('load-phone-contacts')));
    await tester.pumpAndSettle();
    expect(find.text('Alice Test'), findsOneWidget);
    expect(find.text('Bob Test'), findsOneWidget);
    expect(uploadCount, 0);

    await tester.tap(find.byKey(const ValueKey('import-contact-device-1')));
    await tester.pump();
    await tester.tap(find.text('Review Selected'));
    await tester.pumpAndSettle();
    expect(find.text('Selected contacts (1)'), findsOneWidget);
    expect(find.text('Alice Test'), findsWidgets);
    expect(uploadCount, 0);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(uploadCount, 0);

    await tester.tap(find.text('Review Selected'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-import-clients')));
    await tester.pumpAndSettle();
    expect(uploadCount, 1);
    expect(find.text('Open import'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('contacts denial never sends any data and preserves manual option',
      (tester) async {
    var uploadCount = 0;
    final api = SignApiClient(
      baseUrl: Uri.parse('https://example.test'),
      tokenProvider: () async => 'test-token',
      activeCompanyId: () => ActiveCompanySession.companyId,
      httpClient: MockClient((request) async {
        uploadCount++;
        return http.Response('{}', 200);
      }),
    );
    await _open(tester,
      source: const _FakePhoneContactSource(denied: true),
      repository: RemoteClientRepository(api: api));
    await tester.tap(find.byKey(const Key('load-phone-contacts')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Unable to access contacts'), findsOneWidget);
    expect(find.text('Review Selected'), findsOneWidget);
    expect(uploadCount, 0);
    expect(tester.takeException(), isNull);
  });
}
