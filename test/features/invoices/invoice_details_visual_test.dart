import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/features/invoices/domain/invoice_record.dart';
import 'package:sign2digital/features/invoices/data/demo_invoice_repository.dart';
import 'package:sign2digital/features/invoices/presentation/screens/invoice_details_screen.dart';

InvoiceRecord referenceInvoice() => InvoiceRecord(
  id: 'visual-check-1',
  number: 'INV-2026-0098',
  project: 'Riverside Villa',
  clientName: 'Jean Dupont',
  amount: 108.10,
  date: DateTime(2026, 8, 23),
  dueDate: DateTime(2026, 9, 5),
  status: InvoiceStatus.pending,
  vatBasisPoints: 810,
  items: const [
    InvoiceLineItem(description: 'Electric installation',
      quantity: 1, unitPriceMinor: 10000),
  ],
);

void main() {
  // Captures the *real Flutter widget tree* at three screen dimensions.
  // The golden images are generated once for visual Figma comparison; they
  // do not assert a pixel-perfect match to the iOS status bar or safe area.
  for (final size in <Size>[
    const Size(320, 568),
    const Size(390, 844),
    const Size(768, 1024),
  ]) {
    testWidgets('Invoice Details visual viewport at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        home: InvoiceDetailsScreen(
          invoice: referenceInvoice(),
          repository: const DemoInvoiceRepository(),
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull,
        reason: 'Flutter render overflow at $size');
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/invoice_details_${size.width.toInt()}x${size.height.toInt()}_top.png'),
      );
      final scroller = find.descendant(
        of: find.byKey(const Key('invoice-details-scroll')),
        matching: find.byType(Scrollable),
      ).first;
      await tester.drag(scroller, const Offset(0, -720));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull,
        reason: 'Flutter render overflow while scrolling at $size');
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/invoice_details_${size.width.toInt()}x${size.height.toInt()}_scrolled.png'),
      );
    });
  }
}
