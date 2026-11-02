import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/core/theme/app_theme.dart';
import 'package:sign2digital/features/auth/presentation/screens/reset_password_screen.dart';

void main() {
  testWidgets('reset password reuses approved input components and rejects invalid data', (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var submitted = false;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: ResetPasswordScreen(onResetPassword: (password) async {
        submitted = true;
      }),
    ));

    expect(find.text('Reset Password'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
    await tester.ensureVisible(find.text('Update Password'));
    await tester.tap(find.text('Update Password'));
    await tester.pump();
    expect(submitted, isFalse);
    expect(find.text('Use at least 8 characters'), findsOneWidget);
  });

  testWidgets('reset password invokes real callback only after matching secure fields', (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    String? submitted;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: ResetPasswordScreen(onResetPassword: (password) async {
        submitted = password;
      }),
    ));

    final inputs = find.byType(TextFormField);
    await tester.enterText(inputs.first, 'Verified@Password42');
    await tester.enterText(inputs.last, 'Verified@Password42');
    tester.testTextInput.hide();
    await tester.ensureVisible(find.text('Update Password'));
    await tester.tap(find.text('Update Password'));
    await tester.pump();
    expect(submitted, 'Verified@Password42');
    expect(tester.takeException(), isNull);
  });
}
