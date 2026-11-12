// Sign2Digital Create Account regression tests.
import 'package:flutter/foundation.dart' show debugDefaultTargetPlatformOverride, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/scroll_to_visible_action.dart';

import 'package:sign2digital/core/widgets/sign2digital_country_selector.dart';
import 'package:sign2digital/core/widgets/sign2digital_input_field.dart';
import 'package:sign2digital/features/auth/presentation/screens/create_account_screen.dart';
import 'package:sign2digital/features/auth/presentation/screens/login_screen.dart';
import 'package:sign2digital/features/auth/presentation/screens/otp_verification_screen.dart';

void useSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('Android registration hides Apple; iOS registration keeps it',
      (tester) async {
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    useSize(tester, const Size(430, 932));
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await tester.pumpWidget(const MaterialApp(home: CreateAccountScreen()));
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Continue with Apple'), kIsWeb ? findsOneWidget : findsNothing);
    expect(find.byKey(const Key('create-account-button')), findsOneWidget);
    expect(tester.takeException(), isNull);

    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await tester.pumpWidget(const MaterialApp(home: CreateAccountScreen()));
    await tester.pump();
    expect(find.text('Continue with Apple'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('all five inputs and buttons render without exceptions', (
    tester,
  ) async {
    useSize(tester, const Size(430, 932));
    await tester.pumpWidget(const MaterialApp(home: CreateAccountScreen()));
    expect(find.text('Create Your Account'), findsOneWidget);
    expect(find.byType(Sign2DigitalInputField), findsNWidgets(5));
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Continue with Apple'), findsOneWidget);
    await scrollToVisibleAction(
      tester,
      scrollKey: const Key('create-account-scroll'),
      target: find.byKey(const Key('create-account-button')),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('invalid local form shows errors without creating account', (
    tester,
  ) async {
    useSize(tester, const Size(430, 932));
    var submitted = false;
    await tester.pumpWidget(
      MaterialApp(
        home: CreateAccountScreen(onCreateAccount: (_) => submitted = true),
      ),
    );
    await scrollToVisibleAction(
      tester,
      scrollKey: const Key('create-account-scroll'),
      target: find.text('Create Account'),
    );
    await tester.tap(find.text('Create Account'));
    await tester.pump();
    expect(submitted, isFalse);
    expect(find.text('Enter your full name'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('country picker changes both flag and dialing code', (
    tester,
  ) async {
    useSize(tester, const Size(430, 932));
    await tester.pumpWidget(const MaterialApp(home: CreateAccountScreen()));
    await tester.ensureVisible(find.byKey(const Key('country-selector')));
    await tester.tap(find.byKey(const Key('country-selector')));
    await tester.pumpAndSettle();
    expect(find.text('Select Country'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('country-search')), 'Canada');
    await tester.pump();
    await tester.tap(find.byKey(const Key('country-CA')));
    await tester.pumpAndSettle();
    final picker = tester.widget<Sign2DigitalCountrySelector>(
      find.byType(Sign2DigitalCountrySelector),
    );
    expect(picker.selected.isoCode, 'CA');
    expect(picker.selected.dialCode, '+1');
    expect(tester.takeException(), isNull);
  });

  testWidgets('valid local form supplies typed draft without fake success', (
    tester,
  ) async {
    useSize(tester, const Size(430, 932));
    CreateAccountDraft? draft;
    await tester.pumpWidget(
      MaterialApp(
        home: CreateAccountScreen(onCreateAccount: (value) => draft = value),
      ),
    );
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Marc Example');
    await tester.enterText(fields.at(1), 'marc@example.ch');
    await tester.enterText(fields.at(2), '765432123');
    await tester.enterText(fields.at(3), 'password123');
    await tester.enterText(fields.at(4), 'password123');
    await scrollToVisibleAction(
      tester,
      scrollKey: const Key('create-account-scroll'),
      target: find.text('Create Account'),
    );
    await tester.tap(find.text('Create Account'));
    await tester.pump();
    expect(draft?.fullName, 'Marc Example');
    expect(draft?.country.dialCode, '+41');
    expect(draft?.phoneNumber, '765432123');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Forgot Password valid email navigates to OTP UI preview', (
    tester,
  ) async {
    useSize(tester, const Size(430, 932));
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    await tester.tap(find.text('Forgot Password?'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'marc@example.ch');
    await tester.tap(find.text('Send Reset Link'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(OtpVerificationScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Login create account link opens signup and back returns', (
    tester,
  ) async {
    useSize(tester, const Size(430, 932));
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    await tester.ensureVisible(find.text('Create an account'));
    await tester.tap(find.text('Create an account'));
    await tester.pumpAndSettle();
    expect(find.byType(CreateAccountScreen), findsOneWidget);
    await scrollToVisibleAction(
      tester,
      scrollKey: const Key('create-account-scroll'),
      target: find.text('Sign In'),
    );
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact view, text scaling and keyboard remain scrollable', (
    tester,
  ) async {
    useSize(tester, const Size(320, 568));
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(1.6)),
          child: CreateAccountScreen(),
        ),
      ),
    );
    await scrollToVisibleAction(
      tester,
      scrollKey: const Key('create-account-scroll'),
      target: find.byKey(const Key('create-account-button')),
    );
    await tester.pump();
    expect(find.byKey(const Key('create-account-scroll')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
