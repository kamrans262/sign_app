import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:sign2digital/core/services/sign_api_client.dart';
import 'package:sign2digital/core/widgets/sign2digital_input_field.dart';
import 'package:sign2digital/features/company/data/remote_company_repository.dart';
import 'package:sign2digital/features/company/presentation/screens/company_roles_screen.dart';
import 'package:sign2digital/features/company/presentation/screens/company_team_screen.dart';

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(430, 932);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

RemoteCompanyRepository _repo(
    Future<http.Response> Function(http.Request) responder) =>
    RemoteCompanyRepository(api: SignApiClient(
      baseUrl: Uri.parse('https://example.test'),
      tokenProvider: () async => 'verified-owner',
      httpClient: MockClient(responder),
    ));

void main() {
  test('custom role API uses owner endpoints and preserves exact grant keys', () async {
    final calls = <String>[];
    final repository = _repo((request) async {
      calls.add('${request.method} ${request.url.path}');
      if (request.method == 'GET') {
        return http.Response(jsonEncode({'data': {'roles': [
          {'id': 4, 'name': 'Supervisor',
            'permissions': ['jobs.read'], 'assigned_members': 0},
        ]}}), 200);
      }
      if (request.method == 'POST' || request.method == 'PUT') {
        final data = jsonDecode(request.body) as Map<String, dynamic>;
        expect(data['name'], 'Supervisor');
        expect(data['permissions'], ['jobs.read', 'jobs.write']);
        return http.Response(jsonEncode({'data': {'role': {
          'id': 4, 'name': 'Supervisor', 'permissions': data['permissions'],
          'assigned_members': 1,
        }}}), request.method == 'POST' ? 201 : 200);
      }
      return http.Response('{"message":"Role deleted."}', 200);
    });
    final roles = await repository.roles('25');
    expect(roles.single.name, 'Supervisor');
    expect(roles.single.permissions, ['jobs.read']);
    final created = await repository.createRole('25',
      'Supervisor', ['jobs.read', 'jobs.write']);
    expect(created.assignedMembers, 1);
    await repository.updateRole('25', 4,
      'Supervisor', ['jobs.read', 'jobs.write']);
    await repository.deleteRole('25', 4);
    expect(calls, [
      'GET /api/v1/companies/25/roles',
      'POST /api/v1/companies/25/roles',
      'PUT /api/v1/companies/25/roles/4',
      'DELETE /api/v1/companies/25/roles/4',
    ]);
  });

  testWidgets('owner creates a reusable role in approved role manager',
      (tester) async {
    _phone(tester);
    final roles = <Map<String, dynamic>>[];
    var created = false;
    final repository = _repo((request) async {
      if (request.method == 'GET' && request.url.path.endsWith('/roles')) {
        return http.Response(jsonEncode({'data': {'roles': roles}}), 200);
      }
      if (request.method == 'POST' && request.url.path.endsWith('/roles')) {
        final payload = jsonDecode(request.body) as Map<String, dynamic>;
        expect(payload['name'], 'Site Supervisor');
        expect(payload['permissions'], ['jobs.read', 'jobs.write']);
        created = true;
        roles.add({'id': 5, 'name': 'Site Supervisor',
          'permissions': payload['permissions'], 'assigned_members': 0});
        return http.Response(jsonEncode({'data': {'role': roles.last}}), 201);
      }
      return http.Response('{"message":"Not found"}', 404);
    });
    await tester.pumpWidget(MaterialApp(home: CompanyRolesScreen(
      companyId: '25', repository: repository)));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('company-create-role')), findsOneWidget);
    await tester.tap(find.byKey(const Key('company-create-role')));
    await tester.pumpAndSettle();

    final field = find.descendant(
      of: find.byKey(const Key('custom-role-name')),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(field, 'Site Supervisor');
    await tester.ensureVisible(find.byKey(
      const Key('custom-role-permission-jobs.write')));
    await tester.tap(find.byKey(
      const Key('custom-role-permission-jobs.write')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('custom-role-save')));
    await tester.pumpAndSettle();

    expect(created, true);
    expect(find.text('Site Supervisor'), findsOneWidget);
    expect(find.byKey(const Key('manage-role-5')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('owner invites teammate using a custom role, not a copied permission override',
      (tester) async {
    _phone(tester);
    var invited = false;
    final repository = _repo((request) async {
      if (request.method == 'GET' && request.url.path.endsWith('/roles')) {
        return http.Response(jsonEncode({'data': {'roles': [
          {'id': 8, 'name': 'Estimator',
            'permissions': ['quotes.read', 'jobs.read'], 'assigned_members': 0},
        ]}}), 200);
      }
      if (request.method == 'GET' && request.url.path.endsWith('/members')) {
        return http.Response('{"data":{"members":[]}}', 200);
      }
      if (request.method == 'GET' && request.url.path.endsWith('/invitations')) {
        return http.Response('{"data":{"invitations":[]}}', 200);
      }
      if (request.method == 'POST' && request.url.path.endsWith('/invitations')) {
        final data = jsonDecode(request.body) as Map<String, dynamic>;
        expect(data['email'], 'estimator@example.test');
        expect(data['role'], 'member');
        expect(data['company_role_id'], 8);
        expect(data.containsKey('permissions'), false);
        invited = true;
        return http.Response('{"data":{"invitation":{"id":20}}}', 201);
      }
      return http.Response('{"message":"Not found"}', 404);
    });
    await tester.pumpWidget(MaterialApp(home: CompanyTeamScreen(
      companyId: '25', companyName: 'Alpine Company',
      role: 'owner', repository: repository)));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('company-manage-roles')), findsOneWidget);
    await tester.tap(find.byKey(const Key('company-role-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Estimator').last);
    await tester.pumpAndSettle();
    expect(find.text('Inherited from role (2)'), findsOneWidget);
    final email = find.descendant(
      of: find.byKey(const Key('company-invite-email')),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(email, 'estimator@example.test');
    await tester.ensureVisible(find.byKey(const Key('company-send-invite')));
    await tester.tap(find.byKey(const Key('company-send-invite')));
    await tester.pumpAndSettle();
    expect(invited, true);
    expect(tester.takeException(), isNull);
  });
}
