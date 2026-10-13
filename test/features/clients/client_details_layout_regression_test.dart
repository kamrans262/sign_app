import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/features/clients/domain/client_details_model.dart';
import 'package:sign2digital/features/clients/presentation/widgets/sign2digital_client_related_item_card.dart';
import 'package:sign2digital/features/clients/presentation/widgets/sign2digital_statistics_card.dart';
import 'package:sign2digital/features/clients/presentation/widgets/sign2digital_status_badge.dart';

void main() {
  testWidgets('statistics number-to-label spacing is 5px', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 187,
              child: Sign2DigitalStatisticsCard(
                count: 12,
                label: 'Total invoices',
                fallbackIcon: Icons.receipt_long_outlined,
              ),
            ),
          ),
        ),
      ),
    );

    final count = tester.getRect(find.text('12'));
    final label = tester.getRect(find.text('Total invoices'));
    expect(label.top - count.bottom, closeTo(5, 0.1));
    // At the 430px reference layout, the two-column card is 187px wide.
    expect(label.height, lessThan(22));
    expect(tester.takeException(), isNull);
  });

  for (final width in [280.0, 390.0]) {
    testWidgets(
      'related status and chevron are vertically centered at $width px',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: width,
                  child: Sign2DigitalClientRelatedItemCard(
                    item: const ClientRelatedRecord(
                      id: 'demo-job',
                      title: 'Villa Renovation and Interior Works',
                      description: 'Interior renovation works',
                      meta: 'Updated Mar 12, 2026',
                      status: 'Active',
                    ),
                    onTap: () {},
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final cardY = tester
            .getRect(find.byType(Sign2DigitalClientRelatedItemCard))
            .center
            .dy;
        final badgeY = tester
            .getRect(find.byType(Sign2DigitalStatusBadge))
            .center
            .dy;
        final arrowY = tester
            .getRect(find.byIcon(Icons.chevron_right))
            .center
            .dy;

        expect(badgeY, closeTo(cardY, 1));
        expect(arrowY, closeTo(cardY, 1));
        expect(badgeY, closeTo(arrowY, 1));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
