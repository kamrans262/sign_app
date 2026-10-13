// Sign2Digital Login UI Package — splash is white with the original logo only.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/main.dart';
import 'package:sign2digital/features/splash/presentation/splash_screen.dart';

void main() {
  testWidgets('app launches with a plain-white, logo-only splash', (tester) async {
    await tester.pumpWidget(const Sign2DigitalApp());
    // Do not pumpAndSettle: the splash has a navigation timer by design.
    await tester.pump();
    expect(find.byType(SplashScreen), findsOneWidget);
    final scaffold = tester.widget<Scaffold>(
      find.descendant(
        of: find.byType(SplashScreen),
        matching: find.byType(Scaffold),
      ),
    );
    expect(scaffold.backgroundColor, const Color(0xFFFFFFFF));
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('Sign2Digital'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('splash calls supplied completion callback', (tester) async {
    var finished = false;
    await tester.pumpWidget(MaterialApp(
      home: SplashScreen(
        minimumDuration: const Duration(milliseconds: 100),
        onFinished: () => finished = true,
      ),
    ));
    await tester.pump(const Duration(milliseconds: 150));
    expect(finished, isTrue);
  });
}
