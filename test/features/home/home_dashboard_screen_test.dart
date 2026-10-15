import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sign2digital/features/clients/presentation/screens/clients_screen.dart';
import 'package:sign2digital/features/documents/data/demo_document_repository.dart';
import 'package:sign2digital/features/documents/domain/document_record.dart';
import 'package:sign2digital/features/expenses/data/demo_expense_repository.dart';
import 'package:sign2digital/features/home/presentation/screens/home_dashboard_screen.dart';
import 'package:sign2digital/features/invoices/data/demo_invoice_repository.dart';
import 'package:sign2digital/features/jobs/data/mock_jobs.dart';
import 'package:sign2digital/features/jobs/domain/job_model.dart';
import 'package:sign2digital/features/quotes/domain/quote_tracking_home_session.dart';
import 'package:sign2digital/features/quotes/presentation/screens/create_quote_screen.dart';
import 'package:sign2digital/features/reminders/data/demo_reminder_repository.dart';

void main() {
  setUp(QuoteTrackingHomeSession.clear);
  tearDown(QuoteTrackingHomeSession.clear);

  test('Overview counts are derived from the existing records', () async {
    final documents = await const DemoDocumentRepository().listDocuments();
    final invoices = await const DemoInvoiceRepository().listInvoices();
    final expenses = await const DemoExpenseRepository().listExpenses();
    final reminders = await const DemoReminderRepository().listReminders();
    final now = DateTime.now();

    expect(MockJobsData.count(JobCategory.active), 12);
    expect(HomeOverview.countPendingQuotes(documents), 0);
    expect(HomeOverview.countOutstanding(invoices), 3);
    expect(HomeOverview.countRecent(documents, now),
      documents.where((item) => !item.timestamp.isBefore(
        now.subtract(const Duration(days: 30))) &&
        !item.timestamp.isAfter(now)).length);
    expect(HomeOverview.countUpcoming(reminders, now),
      reminders.where((item) =>
        !item.completed && !item.remindAt.isBefore(now)).length);
    expect(HomeOverview.totalExpenses(expenses),
      expenses.where((item) => item.job.isNotEmpty)
        .fold<double>(0, (sum, item) => sum + item.amount));
  });

  for (final size in [
    const Size(320, 568),
    const Size(430, 932),
    const Size(800, 1180),
  ]) {
    testWidgets('Home dashboard at ${size.width}x${size.height}',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const MaterialApp(home: ClientsScreen(initialTab: 0)));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('home-dashboard-scroll')), findsOneWidget);
      expect(find.byKey(const Key('home-company-switcher')), findsOneWidget);
      expect(find.byKey(const Key('home-demo-disclaimer')), findsOneWidget);
      expect(find.byKey(const Key('dashboard-tab-0')), findsOneWidget);
      for (final id in [
        'jobs','quotes','invoices','documents','reminders','expenses',
      ]) {
        expect(find.byKey(Key('home-card-$id')), findsOneWidget);
      }
      for (final id in [
        'create-quote','new-job','add-client','create-document',
        'add-expense','add-time',
      ]) {
        expect(find.byKey(Key('home-action-$id')), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Company switcher uses existing shared selection sheet',
      (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(home: ClientsScreen(initialTab: 0)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('home-company-switcher')));
    await tester.pumpAndSettle();
    expect(find.text('Switch company'), findsOneWidget);
    await tester.tap(find.text('Alpine Studio').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home-company-name')), findsOneWidget);
    expect(find.text('Alpine Studio'), findsOneWidget);
    expect(find.byKey(const Key('home-demo-disclaimer')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Home metric and quick action use existing screens',
      (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: ClientsScreen(initialTab: 0)));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('home-card-quotes')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home-card-quotes')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('documents-scroll')), findsOneWidget);
    // 1 is the existing Quotes tab.
    expect(find.byKey(const Key('details-tab-1')), findsOneWidget);

    await tester.tap(find.byKey(const Key('dashboard-tab-0')));
    await tester.pumpAndSettle();
    final create = find.byKey(const Key('home-action-create-quote'));
    await tester.ensureVisible(create);
    await tester.pumpAndSettle();
    await tester.tap(create);
    await tester.pumpAndSettle();
    expect(find.byType(CreateQuoteScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
