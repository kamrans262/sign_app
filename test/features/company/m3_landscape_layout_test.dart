import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:sign2digital/core/services/sign_api_client.dart';
import 'package:sign2digital/features/clients/presentation/screens/clients_screen.dart';
import 'package:sign2digital/features/clients/presentation/screens/more_screen.dart';
import 'package:sign2digital/features/company/data/remote_company_repository.dart';
import 'package:sign2digital/features/company/presentation/screens/company_invitations_screen.dart';
import 'package:sign2digital/features/company/presentation/screens/company_team_screen.dart';
import 'package:sign2digital/features/company/presentation/screens/create_company_screen.dart';
import 'package:sign2digital/features/profile/presentation/screens/profile_sections_screen.dart';

void setViewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  const landscape = Size(1200, 700);

  testWidgets('company setup uses available landscape width without dropping fields',
      (tester) async {
    setViewport(tester, landscape);
    await tester.pumpWidget(const MaterialApp(home: CreateCompanyScreen()));
    expect(find.text('Create Your Company'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(9));
    // The previous form was always capped to 520px even on wide screens.
    expect(tester.getSize(find.byType(Form)).width, greaterThan(900));
    expect(tester.takeException(), isNull);
  });

  testWidgets('team management preserves same controls with full landscape content',
      (tester) async {
    setViewport(tester, landscape);
    final api = SignApiClient(
      baseUrl: Uri.parse('https://example.test'),
      tokenProvider: () async => 'test-token',
      httpClient: MockClient((request) async {
        final list = request.url.path.endsWith('/invitations')
            ? 'invitations' : 'members';
        return http.Response(jsonEncode({'data': {list: []}}), 200);
      }),
    );
    final repository = RemoteCompanyRepository(api: api);
    await tester.pumpWidget(MaterialApp(home: CompanyTeamScreen(
      companyId: '15', companyName: 'Alpine Workshop', role: 'owner',
      repository: repository,
    )));
    await tester.pumpAndSettle();
    expect(find.text('Invite Team Member'), findsOneWidget);
    expect(find.byKey(const Key('company-send-invite')), findsOneWidget);
    expect(tester.getSize(find.byKey(const Key('company-team-scroll'))).width,
      greaterThan(900));
    expect(tester.takeException(), isNull);
  });

  testWidgets('company invitation form uses landscape width', (tester) async {
    setViewport(tester, landscape);
    await tester.pumpWidget(
      const MaterialApp(home: CompanyInvitationsScreen()));
    expect(find.byKey(const Key('company-invitation-code')), findsOneWidget);
    expect(tester.getSize(find.byType(ListView)).width, greaterThan(900));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Home and More retain navigation with expanded landscape layout',
      (tester) async {
    setViewport(tester, landscape);
    await tester.pumpWidget(
      const MaterialApp(home: ClientsScreen(initialTab: 0)));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home-dashboard-scroll')), findsOneWidget);
    expect(tester.getSize(find.byKey(const Key('home-dashboard-scroll'))).width,
      greaterThan(900));
    expect(find.byKey(const Key('home-company-switcher')), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: MoreScreen())));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byKey(const Key('more-menu-scroll'))).width,
      greaterThan(900));
    expect(find.byKey(const Key('open-profile-settings')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Business Information keeps existing screen and landscape width',
      (tester) async {
    setViewport(tester, landscape);
    await tester.pumpWidget(
      const MaterialApp(home: ProfileBusinessInformationScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Business Information'), findsWidgets);
    expect(tester.getSize(find.byType(ListView).first).width, greaterThan(900));
    expect(tester.takeException(), isNull);
  });
}
