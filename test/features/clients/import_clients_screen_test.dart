import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/features/clients/data/mock_import_contacts.dart';
import 'package:sign2digital/features/clients/models/import_contact_model.dart';
import 'package:sign2digital/features/clients/presentation/screens/import_clients_screen.dart';

void main() {
  test('demo records have six distinct IDs and five selections', () {
    final contacts = buildDemoImportContacts();
    expect(contacts.length, 6);
    expect(contacts.map((item) => item.id).toSet().length, 6);
    expect(contacts.where((item) => item.isSelected).length, 5);
    expect(contacts[1].isSelected, isFalse);
  });

  testWidgets('toggling one contact preserves other selections', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    List<ImportContactModel>? reviewed;
    await tester.pumpWidget(
      MaterialApp(
        home: ImportClientsScreen(
          onReviewSelected: (value) => reviewed = value,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final second = find.byKey(
      const ValueKey('import-contact-demo-import-contact-2'),
    );
    await tester.ensureVisible(second);
    await tester.tap(second);
    await tester.pump();
    expect(find.text('Import Clients'), findsOneWidget);

    await tester.tap(find.text('Review Selected'));
    await tester.pump();
    expect(reviewed, isNotNull);
    expect(reviewed!.length, 6);
    expect(reviewed!.map((item) => item.id).toSet().length, 6);
    expect(tester.takeException(), isNull);
  });

  testWidgets('zero selections disable review', (tester) async {
    final one = ImportContactModel(
      id: 'one',
      fullName: 'Demo Contact',
      phoneNumber: '044 000 00 00',
      email: 'demo@example.com',
    );
    await tester.pumpWidget(
      MaterialApp(home: ImportClientsScreen(contacts: [one])),
    );
    await tester.pumpAndSettle();
    final button = tester.widget<FilledButton>(
      find.descendant(
        of: find.byKey(const Key('review-selected-button')),
        matching: find.byType(FilledButton),
      ),
    );
    expect(button.onPressed, isNull);
    expect(tester.takeException(), isNull);
  });

  for (final size in [
    const Size(320, 568),
    const Size(430, 932),
    const Size(800, 1180),
  ]) {
    testWidgets('responsive contacts at ${size.width} x ${size.height}', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(MaterialApp(home: ImportClientsScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Review Selected'), findsOneWidget);
      expect(find.byKey(const Key('dashboard-tab-2')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
