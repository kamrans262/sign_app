import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/core/widgets/sign2digital_info_banner.dart';
import 'package:sign2digital/features/quotes/data/quote_ui_demo_data.dart';
import 'package:sign2digital/features/quotes/presentation/screens/in_person_signature_screen.dart';

void main() {
  Widget demo() => MaterialApp(
    home: InPersonSignatureScreen(
      quote: QuoteUiDemoData.quote(),
      projectName: QuoteUiDemoData.projectName,
    ),
  );

  testWidgets('shows reference structure with bottom spacing and 10px info padding',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(demo());
    expect(find.text('In-Person Signature'), findsOneWidget);
    expect(find.text('Quote # Q-2900'), findsOneWidget);
    expect(find.text('Kitchen Renovation'), findsOneWidget);
    expect(find.text('Customer Signature'), findsOneWidget);
    expect(find.text('Your Signature'), findsOneWidget);
    expect(
      tester.widget<Sign2DigitalInfoBanner>(
        find.byType(Sign2DigitalInfoBanner),
      ).verticalPadding,
      10,
    );
    await tester.ensureVisible(find.text('Confirm Signature'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('requires both local drawings and never claims actual signing',
      (tester) async {
    await tester.pumpWidget(demo());
    final button = find.text('Confirm Signature');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
    expect(
      find.text('Please draw both the customer and your signatures.'),
      findsOneWidget,
    );

    final canvas = find.byKey(const Key('in-person-draw-canvas'));
    await tester.ensureVisible(canvas);
    await tester.timedDrag(
      canvas, const Offset(100, 35), const Duration(milliseconds: 180),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('in-person-tab-1')));
    await tester.pump();
    await tester.timedDrag(
      canvas, const Offset(100, 35), const Duration(milliseconds: 180),
    );
    await tester.pump();
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('Document Signed!'), findsOneWidget);
    expect(
      find.text('UI DEMO ONLY — no document has actually been signed.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
