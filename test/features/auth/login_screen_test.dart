// Sign2Digital Login UI Package — UI-only widget and responsive regression tests.
import 'package:flutter/foundation.dart' show debugDefaultTargetPlatformOverride, defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/core/theme/app_colors.dart';
import 'package:sign2digital/core/theme/app_theme.dart';
import 'package:sign2digital/core/widgets/sign2digital_checkbox.dart';
import 'package:sign2digital/features/auth/presentation/screens/login_screen.dart';

Widget _screen({
  void Function(String, String, bool)? onSubmit,
  VoidCallback? onGoogle,
}) {
  return MaterialApp(
    theme: AppTheme.light,
    home: LoginScreen(onSubmit: onSubmit, onGoogle: onGoogle),
  );
}

void main() {
  testWidgets('Android hides Apple sign-in; iOS retains it', (tester) async {
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await tester.pumpWidget(_screen());
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Continue with Apple'), kIsWeb ? findsOneWidget : findsNothing);
    expect(find.text('Log In'), findsOneWidget);
    expect(tester.takeException(), isNull);

    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await tester.pumpWidget(_screen());
    await tester.pump();
    expect(find.text('Continue with Apple'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders the exact core login text and editable inputs',
      (tester) async {
    await tester.pumpWidget(_screen());

    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.text('Sign in to your account'), findsOneWidget);
    expect(find.text('E-mail'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Continue with Apple'),
        kIsWeb || defaultTargetPlatform != TargetPlatform.android
            ? findsOneWidget : findsNothing);
    expect(find.text('Log In'), findsOneWidget);
    expect(find.text('Create an account'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));

    // TextFormField has no obscureText getter: inspect its EditableText child.
    final passwordInput = find.descendant(
      of: find.byType(TextFormField).at(1),
      matching: find.byType(EditableText),
    );
    expect(tester.widget<EditableText>(passwordInput).obscureText, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses brand primary color and a checked checkbox',
      (tester) async {
    await tester.pumpWidget(_screen());
    expect(AppColors.primary, const Color(0xFF166282));

    final checkbox = find.byType(Sign2DigitalCheckbox);
    expect(tester.widget<Sign2DigitalCheckbox>(checkbox).value, isTrue);
    await tester.tap(find.text('Keep me signed in'));
    await tester.pumpAndSettle();
    expect(tester.widget<Sign2DigitalCheckbox>(checkbox).value, isFalse);
    await tester.tap(find.text('Keep me signed in'));
    await tester.pumpAndSettle();
    expect(tester.widget<Sign2DigitalCheckbox>(checkbox).value, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('validates fields and passes data without fake authentication',
      (tester) async {
    String? capturedEmail;
    String? capturedPassword;
    bool? capturedRemember;
    await tester.pumpWidget(_screen(
      onSubmit: (email, password, remember) {
        capturedEmail = email;
        capturedPassword = password;
        capturedRemember = remember;
      },
    ));

    final login = find.text('Log In');
    await tester.ensureVisible(login);
    await tester.tap(login);
    await tester.pump();
    expect(find.text('Enter your email address'), findsOneWidget);
    expect(find.text('Enter your password'), findsOneWidget);
    expect(capturedEmail, isNull);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.first, '  marc@company.ch  ');
    await tester.enterText(fields.last, 'safe-example-password');
    tester.testTextInput.hide();
    await tester.ensureVisible(login);
    await tester.tap(login);
    await tester.pump();

    expect(capturedEmail, 'marc@company.ch');
    expect(capturedPassword, 'safe-example-password');
    expect(capturedRemember, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('social button does not imply a successful sign in',
      (tester) async {
    await tester.pumpWidget(_screen());
    final social = find.text('Continue with Google');
    await tester.ensureVisible(social);
    await tester.tap(social);
    await tester.pump();
    expect(find.text('Google sign in will be available in a future phase.'),
        findsOneWidget);
  });

  for (final size in <Size>[
    const Size(320, 568), // compact phone
    const Size(375, 667), // regular phone
    const Size(430, 932), // Figma reference viewport
    const Size(850, 390), // landscape phone
    const Size(800, 1180), // tablet
  ]) {
    testWidgets('no layout exceptions on ${size.width}x${size.height}',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();
      expect(find.text('Welcome Back'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.ensureVisible(find.text('Create an account'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('large text and simulated keyboard still allow scrolling',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Builder(builder: (context) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: const TextScaler.linear(1.5),
            viewInsets: const EdgeInsets.only(bottom: 260),
          ),
          child: const LoginScreen(),
        );
      }),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Keep me signed in'), findsOneWidget);
    expect(find.text('Forgot Password?'), findsOneWidget);
    await tester.ensureVisible(find.text('Forgot Password?'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Create an account'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
