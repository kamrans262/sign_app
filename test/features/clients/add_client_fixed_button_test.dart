import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/features/clients/presentation/screens/add_client_screen.dart';

void main() {
  for (final size in [Size(320, 568), Size(430, 932), Size(800, 1180)]) {
    testWidgets('Save Client remains visible without scrolling at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(MaterialApp(home: AddClientScreen()));
      await tester.pumpAndSettle();
      final button = find.byKey(Key('save-client-button'));
      expect(button, findsOneWidget);
      final rect = tester.getRect(button);
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(rect.bottom, lessThanOrEqualTo(size.height));
      expect(tester.takeException(), isNull);
    });
  }
}
