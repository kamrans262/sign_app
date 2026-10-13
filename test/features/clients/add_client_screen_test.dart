import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/features/clients/data/demo_client_repository.dart';
import 'package:sign2digital/features/clients/domain/client_draft.dart';
import 'package:sign2digital/features/clients/presentation/screens/add_client_screen.dart';

void main() {
  testWidgets(
    'Add Client validates name, accepts multiline notes and creates a typed draft',
    (tester) async {
      tester.view.physicalSize = Size(430, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      ClientDraft? saved;
      await tester.pumpWidget(
        MaterialApp(
          home: AddClientScreen(onSaveClient: (draft) => saved = draft),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Add Client'), findsOneWidget);

      final save = find.byKey(Key('save-client-button'));
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(saved, isNull);
      expect(find.text('Enter the client’s full name'), findsOneWidget);

      final name = find.byType(TextFormField).at(0);
      await tester.ensureVisible(name);
      await tester.enterText(name, 'Marc Dupont');
      final company = find.byType(TextFormField).at(1);
      await tester.ensureVisible(company);
      await tester.enterText(company, 'Dupont SA');
      final notes = find.byKey(Key('client-notes-input'));
      await tester.ensureVisible(notes);
      await tester.enterText(
        notes,
        'Prefers morning appointments\nCalls first',
      );
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(saved?.fullName, 'Marc Dupont');
      expect(saved?.companyName, 'Dupont SA');
      expect(saved?.dialingCode, '+41');
      expect(saved?.notes.contains('morning'), isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'demo repository adds and lists typed client drafts in memory',
    () async {
      final repository = DemoClientRepository();
      final initial = await repository.listClients();
      final created = await repository.createClient(
        ClientDraft(
          fullName: 'Marc Dupont',
          companyName: 'Dupont SA',
          address: 'Geneva',
          countryIsoCode: 'CH',
          dialingCode: '+41',
          phoneNumber: '21 123 45 67',
          email: 'marc@example.ch',
          notes: 'New lead',
        ),
      );
      final updated = await repository.listClients();
      expect(updated.length, initial.length + 1);
      expect(updated.first.id, created.id);
      expect(updated.first.matches('Marc'), isTrue);
      expect(updated.first.jobCount, 0);
    },
  );

  for (final size in [Size(320, 568), Size(430, 932), Size(800, 1180)]) {
    testWidgets('Add Client supports ${size.width}x${size.height}', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(home: AddClientScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Add Client'), findsOneWidget);
      final save = find.byKey(Key('save-client-button'));
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
