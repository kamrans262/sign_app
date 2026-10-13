import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/features/clients/domain/client_profile.dart';
import 'package:sign2digital/features/clients/presentation/widgets/sign2digital_client_card.dart';

void main() {
  final example = ClientProfile(
    id: 'demo-1',
    companyName: 'Dupont Construction SA',
    companyType: 'Construction company',
    email: 'contact@dupontconstruction.com',
    phone: '+41 21 123 45 67',
    jobCount: 12,
  );

  Future<void> pumpCard(WidgetTester tester, double width) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              child: Sign2DigitalClientCard(client: example),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('jobs badge aligns vertically with company name', (tester) async {
    await pumpCard(tester, 390);
    final title = find.text('Dupont Construction SA');
    final badge = find.text('12 jobs');
    expect(title, findsOneWidget);
    expect(badge, findsOneWidget);

    final titleCenter = tester.getCenter(title);
    final badgeCenter = tester.getCenter(badge);
    expect((titleCenter.dy - badgeCenter.dy).abs(), lessThan(4));
    expect(badgeCenter.dx, greaterThan(titleCenter.dx));
    expect(tester.takeException(), isNull);
  });

  for (final width in [390.0, 300.0, 220.0, 185.0]) {
    testWidgets('chevron remains vertically centered at width $width', (
      tester,
    ) async {
      await pumpCard(tester, width);
      final card = find.byType(Sign2DigitalClientCard);
      final chevron = find.byIcon(Icons.chevron_right);
      expect(chevron, findsOneWidget);
      expect(
        (tester.getCenter(chevron).dy - tester.getCenter(card).dy).abs(),
        lessThan(3),
      );
      expect(tester.takeException(), isNull);
    });
  }
}
