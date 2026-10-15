import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/core/widgets/sign2digital_entry_list_card.dart';
import 'package:sign2digital/features/clients/presentation/screens/more_screen.dart';
import 'package:sign2digital/features/global_search/data/global_search_source.dart';
import 'package:sign2digital/features/global_search/presentation/screens/global_search_screen.dart';
import 'package:sign2digital/features/invoices/domain/invoice_record.dart';
import 'package:sign2digital/features/invoices/presentation/screens/invoice_details_screen.dart';
import 'package:sign2digital/features/jobs/data/mock_jobs.dart';
import 'package:sign2digital/features/jobs/presentation/screens/job_details_screen.dart';

class _SearchSource implements GlobalSearchProvider {
  _SearchSource(this.items);
  final List<GlobalSearchResult> items;
  @override
  Future<List<GlobalSearchResult>> loadAll() async => items;
}

class _DelayedSource implements GlobalSearchProvider {
  final calls = <Completer<List<GlobalSearchResult>>>[];
  @override
  Future<List<GlobalSearchResult>> loadAll() {
    final next = Completer<List<GlobalSearchResult>>();
    calls.add(next);
    return next.future;
  }
}

GlobalSearchResult _entry(int n, GlobalSearchCategory category,
    {String? title}) => GlobalSearchResult(
  category: category, id: 'test-$n',
  title: title ?? 'Record $n',
  subtitle: 'Ref-$n', details: 'Customer $n',
  record: Object(),
);

Future<void> _screen(WidgetTester tester, GlobalSearchProvider source, {
  int previewLimit = 10,
  ValueChanged<GlobalSearchResult>? onResultTap,
}) async {
  await tester.pumpWidget(MaterialApp(
    home: GlobalSearchScreen(
      provider: source, previewLimit: previewLimit,
      onResultTap: onResultTap),
  ));
  await tester.pumpAndSettle();
}

void main() {
  test('Repository adapter indexes supported existing modules', () async {
    final source = ExistingGlobalSearchProvider();
    final records = await source.loadAll();
    expect(records, isNotEmpty);
    expect(records.any((e) => e.category == GlobalSearchCategory.jobs), isTrue);
    expect(records.any((e) => e.category == GlobalSearchCategory.clients), isTrue);
    expect(records.any((e) => e.category == GlobalSearchCategory.documents), isTrue);
    expect(records.any((e) => e.category == GlobalSearchCategory.invoices), isTrue);
    expect(records.any((e) => e.category == GlobalSearchCategory.expenses), isTrue);
    expect(records.any((e) => e.category == GlobalSearchCategory.deposits), isTrue);
    expect(records.any((e) => e.category == GlobalSearchCategory.equipment), isTrue);
    expect(records.any((e) => e.category == GlobalSearchCategory.reports), isTrue);
    expect(records.map((e) => e.key).toSet().length, records.length);
    expect(records.any((e) => e.title == 'Riverside Villa' &&
      e.category == GlobalSearchCategory.jobs), isFalse);
  });

  test('Case-insensitive terms and More group are model-driven', () {
    final entry = GlobalSearchResult(
      category: GlobalSearchCategory.equipment,
      id: 'eq-101', title: 'Mini Excavator',
      subtitle: 'Excavation', details: 'Kubota',
      searchTerms: const ['Swiss Gate'],
      record: Object(),
    );
    expect(entry.matches('EXCAVATOR'), isTrue);
    expect(entry.matches('swiss gate'), isTrue);
    expect(entry.matches('missing'), isFalse);
    expect(entry.inTab(GlobalSearchTab.more), isTrue);
    expect(entry.inTab(GlobalSearchTab.invoices), isFalse);
  });

  testWidgets('Cards and count reflect real records, searching updates immediately',
      (tester) async {
    final entries = [
      _entry(1, GlobalSearchCategory.jobs, title: 'Riverside Villa'),
      _entry(2, GlobalSearchCategory.clients, title: 'John Smith'),
      _entry(3, GlobalSearchCategory.invoices, title: 'INV-2026-99'),
    ];
    await _screen(tester, _SearchSource(entries));
    expect(find.byType(Sign2DigitalEntryListCard), findsNWidgets(3));
    expect(find.text('Results (3)'), findsOneWidget);
    expect(find.text('Search across the app'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('clients-search-input')), 'rIVerSide');
    await tester.pumpAndSettle();
    expect(find.text('Results (1)'), findsOneWidget);
    expect(find.byKey(const Key('global-search-result-jobs:test-1')),
      findsOneWidget);
    expect(find.byKey(const Key('global-search-result-clients:test-2')),
      findsNothing);
    await tester.enterText(
      find.byKey(const Key('clients-search-input')), 'unmatched');
    await tester.pumpAndSettle();
    expect(find.text('Results (0)'), findsOneWidget);
    expect(find.byKey(const Key('global-search-empty')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Tabs filter by category and More aggregates extra modules',
      (tester) async {
    final categories = [
      GlobalSearchCategory.jobs, GlobalSearchCategory.clients,
      GlobalSearchCategory.documents, GlobalSearchCategory.invoices,
      GlobalSearchCategory.expenses, GlobalSearchCategory.deposits,
      GlobalSearchCategory.equipment, GlobalSearchCategory.reports,
    ];
    final records = [
      for (var i = 0; i < categories.length; i++)
        _entry(i + 1, categories[i]),
    ];
    await _screen(tester, _SearchSource(records));
    await tester.tap(find.byKey(const Key('details-tab-1')));
    await tester.pumpAndSettle();
    expect(find.text('Results (1)'), findsOneWidget);
    await tester.tap(find.byKey(const Key('details-tab-2')));
    await tester.pumpAndSettle();
    expect(find.text('Results (1)'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('details-tab-5')));
    await tester.tap(find.byKey(const Key('details-tab-5')));
    await tester.pumpAndSettle();
    expect(find.text('Results (4)'), findsOneWidget);
    expect(find.byKey(const Key('global-search-result-expenses:test-5')),
      findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('See all expands limited results rather than inventing cards',
      (tester) async {
    await _screen(tester, _SearchSource([
      _entry(1, GlobalSearchCategory.jobs),
      _entry(2, GlobalSearchCategory.jobs),
      _entry(3, GlobalSearchCategory.jobs),
    ]), previewLimit: 2);
    expect(find.text('Results (3)'), findsOneWidget);
    expect(find.byType(Sign2DigitalEntryListCard), findsNWidgets(2));
    await tester.tap(find.byKey(const Key('global-search-see-all')));
    await tester.pumpAndSettle();
    expect(find.text('Show less'), findsOneWidget);
    expect(find.byType(Sign2DigitalEntryListCard), findsNWidgets(3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Older async responses never overwrite a newer result set',
      (tester) async {
    final source = _DelayedSource();
    await tester.pumpWidget(MaterialApp(
      home: GlobalSearchScreen(provider: source)));
    await tester.pump();
    expect(source.calls.length, 1);
    await tester.tap(find.byTooltip('Search action'));
    await tester.pump();
    expect(source.calls.length, 2);
    source.calls.last.complete([
      _entry(2, GlobalSearchCategory.documents, title: 'Current document')]);
    await tester.pumpAndSettle();
    expect(find.text('Results (1)'), findsOneWidget);
    source.calls.first.complete([
      _entry(1, GlobalSearchCategory.jobs, title: 'Stale job'),
      _entry(3, GlobalSearchCategory.clients, title: 'Stale client')]);
    await tester.pumpAndSettle();
    expect(find.text('Results (1)'), findsOneWidget);
    expect(find.text('Stale job'), findsNothing);
  });

  testWidgets('Tapping passes the same record and ID to navigation callback',
      (tester) async {
    GlobalSearchResult? selected;
    final record = MockJobsData.jobs.first;
    final entry = GlobalSearchResult(
      category: GlobalSearchCategory.jobs,
      id: record.id, title: record.title, subtitle: record.referenceNumber,
      details: record.clientName, record: record);
    await _screen(tester, _SearchSource([entry]),
      onResultTap: (result) => selected = result);
    await tester.tap(find.byKey(Key('global-search-result-${entry.key}')));
    await tester.pumpAndSettle();
    expect(identical(selected?.record, record), isTrue);
    expect(selected?.id, record.id);
  });

  testWidgets('Existing Job and Invoice details routes open correctly',
      (tester) async {
    final job = MockJobsData.jobs.first;
    final invoice = InvoiceRecord(
      id: 'invoice-test-1', number: 'INV-2026-101',
      project: 'Terrace Renovation', clientName: 'Jean Dupont',
      amount: 125.00, status: InvoiceStatus.pending,
      date: DateTime(2026, 8, 23),
    );
    final provider = _SearchSource([
      GlobalSearchResult(
        category: GlobalSearchCategory.jobs, id: job.id, title: job.title,
        subtitle: job.referenceNumber, details: job.clientName, record: job),
      GlobalSearchResult(
        category: GlobalSearchCategory.invoices, id: invoice.id,
        title: invoice.number, subtitle: invoice.project,
        details: invoice.clientName, record: invoice),
    ]);
    await _screen(tester, provider);
    await tester.tap(find.byKey(Key('global-search-result-jobs:${job.id}')));
    await tester.pumpAndSettle();
    expect(find.byType(JobDetailsScreen), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('global-search-result-invoices:${invoice.id}')));
    await tester.pumpAndSettle();
    expect(find.byType(InvoiceDetailsScreen), findsOneWidget);
  });

  testWidgets('More menu opens Global Search', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MoreScreen()));
    await tester.tap(find.byKey(const Key('open-global-search')));
    await tester.pumpAndSettle();
    expect(find.byType(GlobalSearchScreen), findsOneWidget);
    expect(find.text('Search across the app'), findsOneWidget);
  });

  for (final size in [
    const Size(320, 568), const Size(390, 844),
    const Size(768, 1024),
  ]) {
    testWidgets('Cards and tabs fit viewport $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _screen(tester, _SearchSource([
        _entry(1, GlobalSearchCategory.jobs,
          title: 'An extremely long construction project title for testing'),
        _entry(2, GlobalSearchCategory.invoices),
        _entry(3, GlobalSearchCategory.equipment),
      ]));
      expect(find.byKey(const Key('global-search-count')), findsOneWidget);
      expect(tester.takeException(), isNull, reason: '$size');
    });
  }
}
