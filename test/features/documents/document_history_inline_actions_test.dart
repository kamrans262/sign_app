import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/features/documents/domain/document_record.dart';
import 'package:sign2digital/features/documents/presentation/widgets/sign2digital_document_history.dart';

void main() {
  final baseDate = DateTime(2026, 11, 4, 15, 30);
  final record = DocumentRecord(
    id: 'document-1',
    category: DocumentCategory.quotes,
    number: 'Q-100',
    title: 'Quote Q-100',
    project: 'Sample job',
    customer: 'Test customer',
    timestamp: baseDate,
    status: 'signed',
    history: [
      DocumentHistoryEvent(
        id: 'created',
        documentId: 'document-1',
        type: DocumentHistoryType.created,
        occurredAt: baseDate.subtract(const Duration(days: 2)),
      ),
      DocumentHistoryEvent(
        id: 'sent',
        documentId: 'document-1',
        type: DocumentHistoryType.sent,
        occurredAt: baseDate.subtract(const Duration(days: 1)),
      ),
      DocumentHistoryEvent(
        id: 'signed',
        documentId: 'document-1',
        type: DocumentHistoryType.signed,
        occurredAt: baseDate,
      ),
    ],
  );

  testWidgets('History links sit at the right of date/time, not as buttons',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final width in [320.0, 430.0, 720.0]) {
      final openedTabs = <int>[];
      tester.view.physicalSize = Size(width, 720);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SingleChildScrollView(
              child: Sign2DigitalDocumentHistory(
                document: record,
                canPreview: true,
                onOpenDocument: openedTabs.add,
              ),
            ),
          ),
        ),
      ));
      await tester.pump();

      final signed = find.byKey(
        const Key('document-history-event-signed'));
      final signatures = find.byKey(
        const Key('document-view-signatures'));
      expect(signatures, findsOneWidget);
      expect(tester.widget<InkWell>(signatures).onTap, isNotNull);
      final signatureStyle = tester.widget<Text>(
          find.text('View Signatures')).style;
      expect(signatureStyle?.fontSize, 12);
      expect(signatureStyle?.decoration, TextDecoration.underline);
      expect(tester.getSize(signatures).height, lessThan(48));
      expect((tester.getTopRight(signatures).dx -
          tester.getTopRight(signed).dx).abs(), lessThan(2));

      final sent = find.byKey(const Key('document-history-event-sent'));
      await tester.tap(sent);
      await tester.pump();
      final viewDocument = find.byKey(
          const Key('document-history-action-sent'));
      expect(tester.widget<Text>(find.text('View Document')).style?.decoration,
          TextDecoration.underline);
      expect((tester.getTopRight(viewDocument).dx -
          tester.getTopRight(sent).dx).abs(), lessThan(2));
      await tester.tap(viewDocument);
      await tester.pump();
      expect(openedTabs.last, 1);

      final created = find.byKey(
          const Key('document-history-event-created'));
      await tester.tap(created);
      await tester.pump();
      final viewDetails = find.byKey(
          const Key('document-history-action-created'));
      expect(tester.widget<Text>(find.text('View Details')).style?.fontSize,
          12);
      expect(tester.widget<Text>(find.text('View Details')).style?.decoration,
          TextDecoration.underline);
      expect((tester.getTopRight(viewDetails).dx -
          tester.getTopRight(created).dx).abs(), lessThan(2));
      await tester.tap(viewDetails);
      await tester.pump();
      expect(openedTabs.last, 0);
      expect(tester.takeException(), isNull,
          reason: 'History layout at width $width');
    }
  });
}
