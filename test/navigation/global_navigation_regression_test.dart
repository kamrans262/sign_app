import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/core/navigation/sign2digital_navigation.dart';
import 'package:sign2digital/features/clients/presentation/screens/clients_screen.dart';
import 'package:sign2digital/features/clients/presentation/screens/more_screen.dart';
import 'package:sign2digital/features/invoices/presentation/screens/add_invoice_screen.dart';
import 'package:sign2digital/features/invoices/data/demo_invoice_repository.dart';
import 'package:sign2digital/features/invoices/presentation/screens/invoices_screen.dart';

Future<void> _frame(WidgetTester tester) async {
  // The dashboard contains continuously running asynchronous widgets.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 420));
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(430, 932);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

class _PushedPage extends StatelessWidget {
  const _PushedPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('One route')),
    body: const Center(child: Text('Destination is open')),
  );
}

class _PushObserver extends NavigatorObserver {
  int pushCount = 0;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushCount++;
    super.didPush(route, previousRoute);
  }
}

void main() {
  testWidgets('rapid double-tap creates only one route, reopen works after Back',
      (tester) async {
    _phone(tester);
    final observer = _PushObserver();
    await tester.pumpWidget(MaterialApp(navigatorObservers: [observer], home: Scaffold(
      body: Builder(builder: (context) => ElevatedButton(
        key: const Key('open-destination'),
        onPressed: () {
          Sign2DigitalNavigation.push<void>(
            context,
            MaterialPageRoute<void>(builder: (_) {
              return const _PushedPage();
            }),
          );
        },
        child: const Text('Open'),
      )),
    )));
    final open = tester.widget<ElevatedButton>(
      find.byKey(const Key('open-destination')));
    // Invoke the same action twice in the same frame. The second widget
    // becomes obscured after the push, so a second screen tap is not
    // a reliable way to reproduce rapid repeated callbacks.
    open.onPressed!();
    open.onPressed!();
    await _frame(tester);
    expect(find.byType(_PushedPage), findsOneWidget);
    expect(observer.pushCount, 2); // Initial route + one detail route.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(_PushedPage), findsNothing);
    await tester.tap(find.byKey(const Key('open-destination')));
    await _frame(tester);
    expect(find.byType(_PushedPage), findsOneWidget);
    expect(observer.pushCount, 3); // Legitimate reopening after Back.
    expect(tester.takeException(), isNull);
  });

  testWidgets('async API-gated duplicate navigation is held until return',
      (tester) async {
    _phone(tester);
    final gate = Completer<void>();
    var started = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: Builder(builder: (context) => ElevatedButton(
        key: const Key('async-open'),
        onPressed: () {
          Sign2DigitalNavigation.runOnce<void>(
            context, 'load-client:51', () async {
              started++;
              await gate.future;
              if (!context.mounted) return;
              await Navigator.of(context).push<void>(
                MaterialPageRoute<void>(builder: (_) => const _PushedPage()),
              );
            },
          );
        },
        child: const Text('Open client'),
      )),
    )));
    await tester.tap(find.byKey(const Key('async-open')));
    await tester.tap(find.byKey(const Key('async-open')));
    expect(started, 1);
    gate.complete();
    await _frame(tester);
    expect(find.byType(_PushedPage), findsOneWidget);
    await tester.pageBack();
    await _frame(tester);
    await tester.tap(find.byKey(const Key('async-open')));
    await _frame(tester);
    expect(started, 2);
    expect(find.byType(_PushedPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('More to Invoices to Add Invoice Back then More always works',
      (tester) async {
    _phone(tester);
    await tester.pumpWidget(MaterialApp(
      home: ClientsScreen(
        initialTab: 4,
        invoiceRepository: DemoInvoiceRepository(),
      ),
    ));
    await _frame(tester);
    expect(find.byType(MoreScreen), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('open-invoices')));
    await tester.tap(find.byKey(const Key('open-invoices')));
    await _frame(tester);
    expect(find.byType(InvoicesScreen), findsOneWidget);
    await tester.tap(find.byKey(const Key('invoices-create')));
    await _frame(tester);
    expect(find.byType(AddInvoiceScreen), findsOneWidget);

    // Android system Back works even when the approved header has no
    // standard Material/Cupertino AppBar back icon.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(InvoicesScreen), findsOneWidget);
    expect(find.byType(AddInvoiceScreen), findsNothing);

    // The highlighted More tab must not be inert on a child route.
    await tester.tap(
      find.byKey(const Key('dashboard-tab-4')).hitTestable().last);
    // The live dashboard schedules ongoing frames; bounded pumps validate
    // route completion without waiting for unrelated perpetual animations.
    await _frame(tester);
    expect(find.byType(MoreScreen), findsOneWidget);
    expect(find.byType(InvoicesScreen), findsNothing);
    expect(find.byType(AddInvoiceScreen), findsNothing);

    // Opening the same module again after returning is a legitimate action.
    await tester.ensureVisible(find.byKey(const Key('open-invoices')));
    await tester.tap(find.byKey(const Key('open-invoices')));
    await _frame(tester);
    expect(find.byType(InvoicesScreen), findsOneWidget);
    await tester.tap(find.byKey(const Key('invoices-create')));
    await _frame(tester);
    expect(find.byType(AddInvoiceScreen), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('dashboard-tab-4')).hitTestable().last);
    // The live dashboard schedules ongoing frames; bounded pumps validate
    // route completion without waiting for unrelated perpetual animations.
    await _frame(tester);
    expect(find.byType(MoreScreen), findsOneWidget);
    expect(find.byType(InvoicesScreen), findsNothing);

    await tester.tap(find.byKey(const Key('dashboard-tab-1')).last);
    await _frame(tester);
    expect(find.byKey(const Key('jobs-scroll')), findsOneWidget);
    await tester.tap(find.byKey(const Key('dashboard-tab-2')).last);
    await _frame(tester);
    expect(find.byKey(const Key('clients-scroll')), findsOneWidget);
    await tester.tap(find.byKey(const Key('dashboard-tab-3')).last);
    await _frame(tester);
    expect(find.byKey(const Key('documents-scroll')), findsOneWidget);
    await tester.tap(find.byKey(const Key('dashboard-tab-0')).last);
    await _frame(tester);
    expect(find.byKey(const Key('home-dashboard-scroll')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
