import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/core/services/active_company_session.dart';
import 'package:sign2digital/core/widgets/sign2digital_bottom_navigation_bar.dart';
import 'package:sign2digital/features/clients/presentation/screens/more_screen.dart';

void main() {
  setUp(ActiveCompanySession.clear);
  tearDown(ActiveCompanySession.clear);

  testWidgets('member gets only granted bottom tabs, updated on permission change',
      (tester) async {
    ActiveCompanySession.setVerified(15, role: 'member',
      permissions: ['clients.read', 'clients.write', 'jobs.read',
        'jobs.write', 'invoices.read']);
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: Sign2DigitalBottomNavigationBar(
        selectedIndex: 0, onSelected: (_) {}),
    )));
    await tester.pump();
    expect(find.byKey(const Key('dashboard-tab-0')), findsOneWidget);
    expect(find.byKey(const Key('dashboard-tab-1')), findsOneWidget);
    expect(find.byKey(const Key('dashboard-tab-2')), findsOneWidget);
    expect(find.byKey(const Key('dashboard-tab-3')), findsNothing);
    expect(find.byKey(const Key('dashboard-tab-4')), findsOneWidget);

    ActiveCompanySession.setVerified(15, role: 'member',
      permissions: ['clients.read']);
    await tester.pump();
    expect(find.byKey(const Key('dashboard-tab-1')), findsNothing);
    expect(find.byKey(const Key('dashboard-tab-2')), findsOneWidget);
    expect(find.byKey(const Key('dashboard-tab-3')), findsNothing);
    expect(ActiveCompanySession.canWrite('clients'), isFalse);
  });

  testWidgets('More keeps personal settings but hides ungranted company modules',
      (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    ActiveCompanySession.setVerified(15, role: 'member',
      permissions: ['clients.read', 'jobs.read', 'invoices.read']);
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: MoreScreen())));
    await tester.pump();
    expect(find.byKey(const Key('open-profile-settings')), findsOneWidget);
    expect(find.byKey(const Key('open-invoices')), findsOneWidget);
    expect(find.byKey(const Key('open-reports')), findsNothing);
    expect(find.byKey(const Key('open-ai-documents')), findsNothing);
    expect(find.byKey(const Key('open-subscription')), findsNothing);
    expect(ActiveCompanySession.canRead('invoices'), isTrue);
    expect(ActiveCompanySession.canWrite('invoices'), isFalse);
    expect(tester.takeException(), isNull);
  });
}
