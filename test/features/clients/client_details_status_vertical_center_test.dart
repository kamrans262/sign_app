import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/features/clients/domain/client_details_model.dart';
import 'package:sign2digital/features/clients/presentation/widgets/sign2digital_client_related_item_card.dart';
import 'package:sign2digital/features/clients/presentation/widgets/sign2digital_status_badge.dart';

void main() {
  for (final width in [310.0, 390.0]) {
    testWidgets('related status and arrow centered at $width', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: width,
                child: Sign2DigitalClientRelatedItemCard(
                  item: const ClientRelatedRecord(
                    id: 'example',
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
      final arrowY = tester.getRect(find.byIcon(Icons.chevron_right)).center.dy;
      expect(badgeY, closeTo(cardY, 1));
      expect(arrowY, closeTo(cardY, 1));
      expect(tester.takeException(), isNull);
    });
  }
}
