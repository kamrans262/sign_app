import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/scroll_to_visible_action.dart';

import 'package:sign2digital/features/auth/data/demo_account_repository.dart';
import 'package:sign2digital/features/auth/presentation/screens/create_account_screen.dart';
import 'package:sign2digital/features/company/data/demo_company_repository.dart';
import 'package:sign2digital/features/company/presentation/screens/create_company_screen.dart';

void setPhoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(430, 932);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('valid signup stores demo profile and opens company form', (
    tester,
  ) async {
    setPhoneSize(tester);
    final repository = DemoAccountRepository();
    await tester.pumpWidget(
      MaterialApp(home: CreateAccountScreen(accountRepository: repository)),
    );
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Marc Example');
    await tester.enterText(fields.at(1), 'marc@example.ch');
    await tester.enterText(fields.at(2), '791234567');
    await tester.enterText(fields.at(3), 'password123');
    await tester.enterText(fields.at(4), 'password123');
    await scrollToVisibleAction(
      tester,
      scrollKey: const Key('create-account-scroll'),
      target: find.byKey(const Key('create-account-button')),
    );
    await tester.tap(find.byKey(Key('create-account-button')));
    await tester.pumpAndSettle();
    expect(find.byType(CreateCompanyScreen), findsOneWidget);
    expect((await repository.currentAccount())?.email, 'marc@example.ch');
    expect(tester.takeException(), isNull);
  });

  testWidgets('company save writes to in-memory demo repository', (
    tester,
  ) async {
    setPhoneSize(tester);
    final repository = DemoCompanyRepository(seed: []);
    await tester.pumpWidget(
      MaterialApp(home: CreateCompanyScreen(companyRepository: repository)),
    );
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Alpine Studio');
    await tester.enterText(fields.at(3), 'office@example.ch');
    await scrollToVisibleAction(
      tester,
      scrollKey: const Key('create-company-scroll'),
      target: find.byKey(const Key('save-company-button')),
    );
    await tester.tap(find.byKey(Key('save-company-button')));
    await tester.pump();
    expect(
      (await repository.byId('demo-current-company'))?.companyName,
      'Alpine Studio',
    );
    expect(tester.takeException(), isNull);
  });
}
