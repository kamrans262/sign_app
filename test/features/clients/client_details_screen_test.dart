import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/features/clients/data/demo_client_details.dart';
import 'package:sign2digital/features/clients/data/demo_client_repository.dart';
import 'package:sign2digital/features/clients/domain/client_draft.dart';
import 'package:sign2digital/features/clients/domain/client_profile.dart';
import 'package:sign2digital/features/clients/presentation/screens/client_details_screen.dart';

void main() {
  testWidgets(
    'Client Details follows the selected client and switches related tabs',
    (tester) async {
      tester.view.physicalSize = const Size(860, 1864);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = DemoClientRepository();
      final client = (await repository.listClients()).first;
      await tester.pumpWidget(
        MaterialApp(
          home: ClientDetailsScreen(client: client, repository: repository),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Client Details'), findsOneWidget);
      expect(find.text(client.companyName), findsOneWidget);
      expect(find.text('Jobs (4)'), findsOneWidget);
      expect(find.text('Villa Renovation'), findsNWidgets(4));

      await tester.ensureVisible(find.byKey(const Key('details-tab-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('details-tab-1')));
      await tester.pumpAndSettle();
      expect(find.text('Renovation Estimate'), findsOneWidget);
      expect(find.text('Villa Renovation'), findsNothing);
      expect(find.byKey(const Key('view-all-jobs-button')), findsNothing);

      await tester.ensureVisible(find.byKey(const Key('details-tab-2')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('details-tab-2')));
      await tester.pumpAndSettle();
      expect(find.text('Renovation Agreement.pdf'), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('details-tab-3')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('details-tab-3')));
      await tester.pumpAndSettle();
      expect(find.text('Invoice INV-2026-013'), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('details-tab-4')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('details-tab-4')));
      await tester.pumpAndSettle();
      expect(find.text('Prefers updates by email.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  test('local demo clients do not inherit unrelated company statistics', () {
    const client = ClientProfile(
      id: 'local-client-3',
      companyName: 'A New Company',
      companyType: 'Client',
      email: 'team@example.com',
      phone: '021 123 4567',
      jobCount: 0,
    );
    final details = DemoClientDetails.forClient(client);
    expect(details.totalQuotes, 0);
    expect(details.jobs, isEmpty);
    expect(details.quotes, isEmpty);
  });

  test(
    'editing a client updates the existing demo ID, not a duplicate',
    () async {
      final repository = DemoClientRepository();
      final client = (await repository.listClients()).first;
      final before = (await repository.listClients()).length;
      final edited = await repository.updateClient(
        client.id,
        const ClientDraft(
          fullName: 'Jean Dupont',
          companyName: 'Edited Studio',
          address: 'Geneva',
          countryIsoCode: 'CH',
          dialingCode: '+41',
          phoneNumber: '079 123 4567',
          email: 'jean@example.com',
          notes: 'Call on Monday',
        ),
      );
      expect(edited.id, client.id);
      expect(edited.companyName, 'Edited Studio');
      expect(edited.jobCount, client.jobCount);
      expect((await repository.listClients()).length, before);
    },
  );
}
