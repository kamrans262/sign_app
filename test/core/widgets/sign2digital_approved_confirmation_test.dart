import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/core/widgets/sign2digital_approved_confirmation.dart';
import 'package:sign2digital/core/widgets/sign2digital_modal_surface.dart';
import 'package:sign2digital/core/widgets/sign2digital_primary_button.dart';
import 'package:sign2digital/core/widgets/sign2digital_outlined_button.dart';

void main() {
  Future<void> open(WidgetTester tester, {
    required ValueChanged<bool?> callback,
    bool withInput = false,
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(builder: (context) => TextButton(
          onPressed: () async {
            final result = await showDialog<bool>(
              context: context,
              builder: (dialog) => Sign2DigitalApprovedConfirmation(
                title: const Text('Delete document?'),
                content: withInput
                    ? const Column(mainAxisSize: MainAxisSize.min, children: [
                        Text('Confirm account access before deleting.'),
                        TextField(key: Key('confirmation-input')),
                      ])
                    : const Text('This action cannot be undone.'),
                actions: [
                  TextButton(
                    key: const Key('approved-cancel'),
                    onPressed: () => Navigator.pop(dialog, false),
                    child: const Text('Keep Editing')),
                  TextButton(
                    key: const Key('approved-confirm'),
                    onPressed: () => Navigator.pop(dialog, true),
                    child: const Text('Confirm Deletion')),
                ],
              ),
            );
            callback(result);
          },
          child: const Text('Open confirmation'),
        )),
      ),
    ));
    await tester.tap(find.text('Open confirmation'));
    await tester.pumpAndSettle();
  }

  testWidgets('uses approved modal, icon and two brand action buttons',
      (tester) async {
    bool? result;
    await open(tester, callback: (value) => result = value);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(Sign2DigitalModalSurface), findsOneWidget);
    expect(find.byType(CircleAvatar), findsOneWidget);
    expect(find.byType(Sign2DigitalPrimaryButton), findsOneWidget);
    expect(find.byType(Sign2DigitalOutlinedButton), findsOneWidget);
    expect(find.byKey(const Key('approved-cancel')), findsOneWidget);
    expect(find.byKey(const Key('approved-confirm')), findsOneWidget);
    await tester.tap(find.byKey(const Key('approved-cancel')));
    await tester.pumpAndSettle();
    expect(result, isFalse);
  });

  testWidgets('keeps original confirm callback and button key',
      (tester) async {
    bool? result;
    await open(tester, callback: (value) => result = value);
    await tester.tap(find.byKey(const Key('approved-confirm')));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('preserves editable confirmation fields on narrow iPhones',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    bool? result;
    await open(tester, callback: (value) => result = value,
      withInput: true);
    await tester.enterText(
      find.byKey(const Key('confirmation-input')), 'DELETE');
    expect(find.text('DELETE'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('approved-confirm')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('approved-confirm')));
    await tester.pumpAndSettle();
    expect(result, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('disabled original action remains disabled',
      (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: Builder(builder: (context) => TextButton(
        child: const Text('Open'),
        onPressed: () => showDialog<void>(
          context: context,
          builder: (_) => Sign2DigitalApprovedConfirmation(
            title: const Text('Confirm plan change'),
            content: const Text('Payment is verified server-side.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              const TextButton(
                onPressed: null,
                child: Text('Confirm Change'),
              ),
            ],
          ),
        ),
      )),
    )));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final primary = tester.widget<Sign2DigitalPrimaryButton>(
      find.byType(Sign2DigitalPrimaryButton));
    expect(primary.enabled, isFalse);
    expect(tester.takeException(), isNull);
  });
}
