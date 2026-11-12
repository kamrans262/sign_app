import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/features/clients/presentation/widgets/sign2digital_status_badge.dart';
import 'package:sign2digital/features/jobs/domain/job_model.dart';
import 'package:sign2digital/features/jobs/presentation/widgets/sign2digital_job_status_badge.dart';

void main() {
  test('status badge formats display text, not stored status identifiers', () {
    expect(Sign2DigitalStatusBadge.displayLabel('pending'), 'Pending');
    expect(Sign2DigitalStatusBadge.displayLabel('in_progress'), 'In Progress');
    expect(Sign2DigitalStatusBadge.displayLabel('  payment_pending  '),
      'Payment Pending');
    expect(Sign2DigitalStatusBadge.displayLabel('partially paid'),
      'Partially Paid');
    expect(Sign2DigitalStatusBadge.displayLabel('PDF generated'),
      'PDF Generated');
    expect(Sign2DigitalStatusBadge.displayLabel(''), '');
  });

  testWidgets('shared badge text is readable and preserves the raw status',
      (tester) async {
    const status = 'payment_pending';
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: Center(
        child: Sign2DigitalStatusBadge(status: status),
      )),
    ));
    expect(find.text('Payment Pending'), findsOneWidget);
    final badge = tester.widget<Sign2DigitalStatusBadge>(
      find.byType(Sign2DigitalStatusBadge));
    expect(badge.status, status);
    final label = tester.widget<Text>(find.text('Payment Pending'));
    expect(label.style?.fontSize, 12);
    expect(label.style?.fontFamily, 'Inter');
    expect(label.maxLines, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('jobs use matching readable badges and corrected stage labels',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: Center(
        child: Sign2DigitalJobStatusBadge(stage: JobStage.inProgress),
      )),
    ));
    final label = tester.widget<Text>(find.text('In Progress'));
    expect(label.style?.fontSize, 12);
    expect(label.maxLines, 1);
    expect(tester.takeException(), isNull);
  });

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(768, 1024),
  ]) {
    testWidgets('status badges fit narrow device layout at $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Sign2DigitalStatusBadge(status: 'awaiting_signature'),
              SizedBox(height: 8),
              Sign2DigitalJobStatusBadge(stage: JobStage.overdue),
            ],
          ),
        )),
      ));
      expect(find.text('Awaiting Signature'), findsOneWidget);
      expect(find.text('Overdue'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: '$size');
    });
  }
}
