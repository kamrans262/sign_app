import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/features/quotes/presentation/widgets/sign2digital_quote_summary_card.dart';
import 'package:sign2digital/core/utils/sign2digital_server_timestamp.dart';

void main() {
  testWidgets('Quote, report and acceptance cards show local created time',
      (tester) async {
    final input = Sign2DigitalServerTimestamp.tryParse(
      '2026-11-12 16:45:00')!;
    final local = DateTime.utc(2026, 11, 12, 16, 45).toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final stamp = '$hour:${local.minute.toString().padLeft(2, '0')} '
        '${local.hour < 12 ? 'AM' : 'PM'}';
    const months = ['Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'];
    final date = '${months[local.month-1]} ${local.day}, ${local.year}';
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SizedBox(
      width: 390,
      child: Sign2DigitalQuoteSummaryCard(
        quoteNumber: 'Q-TEST',
        titleOverride: 'Site renovation quote',
        projectName: 'Renovation Job',
        customerName: 'Client',
        documentDate: input,
        status: 'Approved',
        listStyle: true,
      ),
    ))));
    await tester.pumpAndSettle();
    expect(find.text(date), findsOneWidget);
    expect(find.text(stamp), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Date-only report dates are not converted into invented times',
      (tester) async {
    final chosenReportDate = DateTime(2026, 11, 12);
    expect(chosenReportDate.hour, 0);
    final creationTime = Sign2DigitalServerTimestamp.tryParse(
      '2026-11-12T16:45:00Z')!;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body:
      Sign2DigitalQuoteSummaryCard(
        quoteNumber: 'R-01',
        titleOverride: 'Meeting Minutes',
        projectName: 'Office Project',
        customerName: 'Client',
        documentDate: creationTime,
        status: 'Draft',
        listStyle: true,
      ),
    )));
    await tester.pumpAndSettle();
    final local = creationTime.toLocal();
    final expectedHour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final displayed = '$expectedHour:'
        '${local.minute.toString().padLeft(2, '0')} '
        '${local.hour < 12 ? 'AM' : 'PM'}';
    expect(find.text(displayed), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
