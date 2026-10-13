// Sign2Digital Forgot Password Refinement — UI/keyboard regression checks.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/core/theme/app_theme.dart';
import 'package:sign2digital/features/auth/presentation/screens/forgot_password_screen.dart';

void main() {
  testWidgets('forgot password uses editable shared email field and UI-only action',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: ForgotPasswordScreen(),
    ));
    expect(find.text('Forgot Password?'), findsOneWidget);
    expect(find.text('E-mail'), findsOneWidget);
    expect(find.text('Send Reset Link'), findsOneWidget);
    expect(find.byType(TextFormField), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping outside email field clears keyboard focus',
      (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: const ForgotPasswordScreen(),
    ));
    await tester.tap(find.byType(TextFormField));
    await tester.pump();
    final editableFinder = find.byType(EditableText);
    expect(tester.widget<EditableText>(editableFinder).focusNode.hasFocus, isTrue);
    await tester.tapAt(const Offset(15, 430));
    await tester.pump();
    expect(tester.widget<EditableText>(editableFinder).focusNode.hasFocus, isFalse);
    expect(tester.takeException(), isNull);
  });
}
