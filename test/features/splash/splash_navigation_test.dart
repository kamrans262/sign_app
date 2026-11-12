// Sign2Digital Navigation Fix — regression test for reported stuck splash.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/main.dart';
import 'package:sign2digital/features/auth/presentation/screens/login_screen.dart';
import 'package:sign2digital/features/splash/presentation/splash_screen.dart';

void main() {
  testWidgets('native mobile startup has no second Flutter splash or timer',
      (tester) async {
    // main() has already restored the session behind the OS native splash.
    // The very first Flutter page must be Login, not another logo screen.
    await tester.pumpWidget(const Sign2DigitalApp(initiallySignedIn: false));
    await tester.pump();
    expect(find.byType(SplashScreen), findsNothing);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Welcome Back'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('startup displays only the logo on white', (tester) async {
    await tester.pumpWidget(const Sign2DigitalApp());
    await tester.pump();

    expect(find.byType(SplashScreen), findsOneWidget);
    final splashScaffold = tester.widget<Scaffold>(
      find.descendant(
        of: find.byType(SplashScreen),
        matching: find.byType(Scaffold),
      ),
    );
    expect(splashScaffold.backgroundColor, const Color(0xFFFFFFFF));
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('Welcome Back'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('app automatically shows Login after two seconds',
      (tester) async {
    await tester.pumpWidget(Sign2DigitalApp(
      restoreSession: () async => false,
    ));
    await tester.pump(const Duration(milliseconds: 1900));
    expect(find.byType(SplashScreen), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.byType(SplashScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
