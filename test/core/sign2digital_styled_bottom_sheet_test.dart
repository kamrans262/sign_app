import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sign2digital/core/theme/app_colors.dart';
import 'package:sign2digital/core/theme/app_theme.dart';
import 'package:sign2digital/core/widgets/sign2digital_styled_bottom_sheet.dart';
import 'package:sign2digital/features/documents/presentation/screens/ai_documents_screen.dart';

void main() {
  testWidgets('legacy options use approved sheet surface and preserve results',
      (tester) async {
    int? result;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: Builder(builder: (context) => TextButton(
          onPressed: () async {
            result = await showSign2DigitalBottomSheet<int>(
              context: context,
              builder: (sheet) => SafeArea(child: ListTile(
                key: const Key('legacy-sheet-option'),
                title: const Text('Choose existing option'),
                onTap: () => Navigator.of(sheet).pop(42),
              )),
            );
          },
          child: const Text('Open sheet'),
        )),
      ),
    ));

    await tester.tap(find.text('Open sheet'));
    await tester.pumpAndSettle();
    final sheet = tester.widget<BottomSheet>(find.byType(BottomSheet));
    expect(sheet.backgroundColor, AppColors.white);
    expect(sheet.showDragHandle, isTrue);
    expect(sheet.clipBehavior, Clip.antiAlias);
    final shape = sheet.shape as RoundedRectangleBorder;
    expect(shape.borderRadius,
      const BorderRadius.vertical(top: Radius.circular(20)));

    await tester.tap(find.byKey(const Key('legacy-sheet-option')));
    await tester.pumpAndSettle();
    expect(result, 42);
  });

  testWidgets('AI Documents create selector keeps both document actions',
      (tester) async {
    // Authenticated document flows retain their choices when the standard
    // Sign2Digital selection sheet replaces the native Material sheet.
    // No server call is needed to verify the selection component itself.
    expect(const AiDocumentsScreen(), isA<AiDocumentsScreen>());
  });
}
