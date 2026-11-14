import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/core/theme/app_theme.dart';
import 'package:sign2digital/core/widgets/sign2digital_styled_bottom_sheet.dart';
import 'package:sign2digital/features/support/data/support_assistant_repository.dart';
import 'package:sign2digital/features/support/presentation/widgets/support_assistant_sheet.dart';

class _FakeSupport implements SupportAssistantRepository {
  @override
  Future<AssistantAnswer> ask({
    required String message,
    required String screen,
    required List<AssistantTurn> history,
  }) async => const AssistantAnswer(answer: 'Support reply');

  @override
  Future<GettingStartedProgress> progress() async =>
      const GettingStartedProgress(eligible: true, completed: {});
}

void main() {
  testWidgets('support composer lifts above keyboard and returns smoothly',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: Builder(
        builder: (context) => TextButton(
          onPressed: () => showSign2DigitalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            showDragHandle: false,
            builder: (_) => SupportAssistantSheet(
              screen: 'home',
              repository: _FakeSupport(),
            ),
          ),
          child: const Text('Open support'),
        ),
      )),
    ));
    await tester.tap(find.text('Open support'));
    await tester.pumpAndSettle();

    const inputKey = Key('support-input');
    const contentKey = Key('support-sheet-content');
    final originalHeight = tester.getSize(find.byKey(contentKey)).height;
    expect(find.byKey(inputKey), findsOneWidget);
    expect(tester.getRect(find.byKey(inputKey)).bottom, lessThan(844));

    // Simulate Android/iOS IME. The input must remain above its top edge.
    tester.view.viewInsets = const FakeViewPadding(bottom: 310);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.getSize(find.byKey(contentKey)).height,
        lessThan(originalHeight));
    expect(tester.getRect(find.byKey(inputKey)).bottom,
        lessThanOrEqualTo(535));

    tester.view.resetViewInsets();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.getSize(find.byKey(contentKey)).height,
        closeTo(originalHeight, 1));
    expect(find.byKey(const Key('support-voice')), findsOneWidget);
    expect(find.byKey(const Key('support-send')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
