import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sign2digital/features/clients/presentation/screens/clients_screen.dart';
import 'package:sign2digital/features/jobs/presentation/screens/job_details_screen.dart';
import 'package:sign2digital/features/quotes/domain/quote_tracking_home_session.dart';
import 'package:sign2digital/features/quotes/presentation/screens/create_quote_screen.dart';

Finder _homeScrollable() => find.descendant(
  of: find.byKey(const Key('home-dashboard-scroll')),
  matching: find.byType(Scrollable),
).first;

void main() {
  setUp(QuoteTrackingHomeSession.clear);
  tearDown(QuoteTrackingHomeSession.clear);

  testWidgets('Home is a useful dashboard with working section shortcuts',
      (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: ClientsScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('dashboard-tab-0')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home-dashboard-scroll')), findsOneWidget);
    expect(find.byKey(const Key('home-preview-notice')), findsOneWidget);
    expect(find.text('Your workspace at a glance'), findsOneWidget);
    expect(find.text('Active jobs'), findsOneWidget);
    expect(find.byKey(const Key('home-stat-clients')), findsOneWidget);
    expect(find.byKey(const Key('home-stat-documents')), findsOneWidget);
    expect(find.text('No quote to track yet'), findsNothing);

    await tester.tap(find.byKey(const Key('home-stat-jobs')));
    await tester.pumpAndSettle();
    expect(find.text('Active (12)'), findsOneWidget);

    await tester.tap(find.byKey(const Key('dashboard-tab-0')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('home-go-documents')),
      160,
      scrollable: _homeScrollable(),
    );
    await tester.ensureVisible(find.byKey(const Key('home-go-documents')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home-go-documents')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('documents-scroll')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Create Quote and recent job cards open existing screens',
      (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: ClientsScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('dashboard-tab-0')));
    await tester.pumpAndSettle();

    final createQuote = find.byKey(const Key('home-create-quote'));
    await tester.ensureVisible(createQuote);
    await tester.pumpAndSettle();
    await tester.tap(createQuote);
    await tester.pumpAndSettle();
    expect(find.byType(CreateQuoteScreen), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('home-view-all-jobs')),
      160,
      scrollable: _homeScrollable(),
    );
    await tester.ensureVisible(find.byKey(const Key('home-view-all-jobs')));
    await tester.pumpAndSettle();
    // Recent demo cards use the same Job Details route as the Jobs tab.
    final job = find.byKey(const ValueKey('job-image-demo-active-1'));
    await tester.scrollUntilVisible(
      job, 130, maxScrolls: 25, scrollable: _homeScrollable());
    await tester.ensureVisible(job);
    await tester.pumpAndSettle();
    await tester.tap(job);
    await tester.pumpAndSettle();
    expect(find.byType(JobDetailsScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final size in [
    const Size(320, 568),
    const Size(430, 932),
    const Size(800, 1180),
  ]) {
    testWidgets('Home is responsive at ${size.width}x${size.height}',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(home: ClientsScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('dashboard-tab-0')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('home-dashboard-scroll')), findsOneWidget);
      expect(find.byKey(const Key('home-preview-notice')), findsOneWidget);
      expect(find.byKey(const Key('dashboard-tab-0')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
