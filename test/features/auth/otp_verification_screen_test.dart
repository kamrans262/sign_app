// Sign2Digital OTP Verification UI package — reusable, frontend-only.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/scroll_to_visible_action.dart';

import 'package:sign2digital/core/widgets/sign2digital_otp_input.dart';
import 'package:sign2digital/core/widgets/sign2digital_primary_button.dart';
import 'package:sign2digital/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:sign2digital/features/auth/presentation/screens/otp_verification_screen.dart';

void referenceViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(430, 932);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('six reusable boxes accept pasted digits and Backspace', (
    tester,
  ) async {
    String? completed;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Sign2DigitalOtpInput(
            onCodeCompleted: (code) => completed = code,
          ),
        ),
      ),
    );

    for (var i = 0; i < 6; i++) {
      expect(find.byKey(Key('otp-box-$i')), findsOneWidget);
    }
    await tester.tap(find.byKey(const Key('otp-box-0')));
    await tester.enterText(find.byKey(const Key('otp-code-field')), '123456');
    await tester.pump();
    expect(completed, '123456');
    expect(find.text('1'), findsOneWidget);
    expect(find.text('6'), findsOneWidget);

    // The real input controller supports normal deletion/backspacing.
    await tester.enterText(find.byKey(const Key('otp-code-field')), '12345');
    await tester.pump();
    expect(find.text('6'), findsNothing);
    expect(find.byIcon(Icons.circle), findsOneWidget);

    // Filtering and the six-digit limit also apply to pasted strings.
    await tester.enterText(
      find.byKey(const Key('otp-code-field')),
      '123456789',
    );
    await tester.pump();
    expect(completed, '123456');
    expect(find.text('7'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('countdown runs once, unlocks resend, and resets on acceptance', (
    tester,
  ) async {
    referenceViewport(tester);
    var requests = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: OtpVerificationScreen(
          onResend: () async {
            requests++;
            return true;
          },
        ),
      ),
    );
    expect(find.text('Resent OTP (60s)'), findsOneWidget);
    await tester.tap(find.byKey(const Key('otp-resend-action')));
    await tester.pump();
    expect(requests, 0);
    await tester.pump(const Duration(seconds: 60));
    expect(find.text('Resend OTP'), findsOneWidget);
    await tester.tap(find.byKey(const Key('otp-resend-action')));
    await tester.pump();
    expect(requests, 1);
    expect(find.text('Resent OTP (60s)'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 61));
    expect(tester.takeException(), isNull);
  });

  testWidgets('verify only calls the callback with six digits', (tester) async {
    referenceViewport(tester);
    String? received;
    await tester.pumpWidget(
      MaterialApp(
        home: OtpVerificationScreen(onVerify: (value) => received = value),
      ),
    );
    await tester.tap(find.text('Verify'));
    await tester.pump();
    expect(received, isNull);
    await tester.enterText(find.byKey(const Key('otp-code-field')), '654321');
    await tester.tap(find.text('Verify'));
    await tester.pump();
    expect(received, '654321');
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping outside OTP dismisses the numeric keyboard', (
    tester,
  ) async {
    referenceViewport(tester);
    await tester.pumpWidget(const MaterialApp(home: OtpVerificationScreen()));
    await tester.tap(find.byKey(const Key('otp-box-0')));
    await tester.pump();
    final field = tester.widget<TextField>(
      find.byKey(const Key('otp-code-field')),
    );
    expect(field.focusNode!.hasFocus, isTrue);
    await tester.tapAt(const Offset(15, 520));
    await tester.pump();
    expect(field.focusNode!.hasFocus, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('primary action aligns with Forgot Password on reference phone', (
    tester,
  ) async {
    referenceViewport(tester);

    await tester.pumpWidget(const MaterialApp(home: ForgotPasswordScreen()));
    final forgotTop = tester
        .getTopLeft(find.byType(Sign2DigitalPrimaryButton))
        .dy;
    await tester.pumpWidget(const MaterialApp(home: OtpVerificationScreen()));
    final otpTop = tester.getTopLeft(find.byType(Sign2DigitalPrimaryButton)).dy;
    expect((forgotTop - otpTop).abs(), lessThan(1.0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact viewport and large text remain scrollable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(1.6)),
          child: OtpVerificationScreen(),
        ),
      ),
    );
    expect(find.byKey(const Key('otp-screen-scroll')), findsOneWidget);
    await scrollToVisibleAction(
      tester,
      scrollKey: const Key('otp-screen-scroll'),
      target: find.text('Verify'),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
