import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/features/quotes/presentation/widgets/sign2digital_quote_summary_card.dart';

void main() {
  for (final status in ['Signed', 'Completed', 'Draft']) {
    for (final width in [320.0, 375.0, 430.0, 768.0]) {
      testWidgets('Documents/Reports $status badge right-aligns with arrow at $width', (tester) async {
        tester.view.physicalSize = Size(width, 850);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(MaterialApp(home: Scaffold(
          body: Center(child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Sign2DigitalQuoteSummaryCard(
              quoteNumber: 'Q-12800',
              titleOverride: 'A longer site report or document title',
              projectName: 'Kitchen renovation',
              customerName: 'Jean Dupont',
              documentDate: DateTime(2026, 8, 23, 22),
              status: status,
              listStyle: true,
            ),
          )),
        )));
        await tester.pumpAndSettle();
        final badge = find.byKey(const Key('document-list-badge'));
        final arrow = find.byIcon(Icons.chevron_right_rounded);
        final card = find.byType(Sign2DigitalQuoteSummaryCard);
        expect(badge, findsOneWidget);
        expect(arrow, findsOneWidget);
        expect(find.text(status), findsOneWidget);
        expect(
          (tester.getTopRight(badge).dx - tester.getTopRight(arrow).dx).abs(),
          lessThan(1),
        );
        expect(
          (tester.getCenter(arrow).dy - tester.getCenter(card).dy).abs(),
          lessThan(3),
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
}
