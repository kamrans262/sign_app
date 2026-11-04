import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sign2digital_bottom_navigation_bar.dart';
import '../../../../core/widgets/sign2digital_dashboard_header.dart';
import '../../../../core/widgets/sign2digital_entry_list_card.dart';
import '../../../../core/widgets/sign2digital_list_sort_control.dart';
import '../../../../core/widgets/sign2digital_search_field.dart';
import '../../../clients/presentation/widgets/sign2digital_details_tabs.dart';
import '../../data/demo_expense_repository.dart';
import '../../data/remote_expense_repository.dart';
import '../../../../core/services/active_company_session.dart';
import '../../domain/expense_record.dart';
import 'add_expense_screen.dart';
import 'expense_details_screen.dart';
import '../widgets/sign2digital_expense_category_icon.dart';

enum ExpenseSort {
  newest('Date (newest)'),
  oldest('Date (oldest)'),
  highest('Amount (highest)'),
  lowest('Amount (lowest)');

  const ExpenseSort(this.label);
  final String label;
}

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({
    super.key, this.repository, this.onExpenseTap, this.onCreateExpense,
    this.onNavigationSelected, this.onNotificationTap, this.onProfileTap,
    this.selectedNavigationIndex = 4,
  });

  final ExpenseRepository? repository;
  final ValueChanged<ExpenseRecord>? onExpenseTap;
  final VoidCallback? onCreateExpense;
  final ValueChanged<int>? onNavigationSelected;
  final VoidCallback? onNotificationTap;
  final VoidCallback? onProfileTap;
  final int selectedNavigationIndex;

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final _search = TextEditingController();
  late final ExpenseRepository _repository;
  List<ExpenseRecord> _all = [];
  bool _loading = true;
  String? _error;
  int _tab = 0;
  ExpenseSort _sort = ExpenseSort.newest;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? (ActiveCompanySession.companyId == null
        ? const DemoExpenseRepository() : RemoteExpenseRepository.shared);
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final records = await _repository.listExpenses();
      if (!mounted) return;
      setState(() { _all = records; _loading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load expenses';
        _loading = false;
      });
    }
  }

  List<ExpenseRecord> get _visible {
    final list = _all.where((item) =>
        (_tab == 0 || item.status == ExpenseStatus.values[_tab - 1]) &&
        item.matches(_search.text)).toList();
    list.sort((a, b) {
      int result = switch (_sort) {
        ExpenseSort.newest => b.date.compareTo(a.date),
        ExpenseSort.oldest => a.date.compareTo(b.date),
        ExpenseSort.highest => b.amount.compareTo(a.amount),
        ExpenseSort.lowest => a.amount.compareTo(b.amount),
      };
      return result == 0 ? a.id.compareTo(b.id) : result;
    });
    return list;
  }

  Future<void> _selectSort() async {
    final choice = await showModalBottomSheet<ExpenseSort>(
      context: context,
      builder: (sheet) => SafeArea(child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ListTile(title: Text('Sort By')),
          for (final sort in ExpenseSort.values)
            ListTile(
              key: Key('expense-sort-${sort.name}'),
              title: Text(sort.label),
              trailing: _sort == sort
                  ? const Icon(Icons.check, color: AppColors.primary) : null,
              onTap: () => Navigator.of(sheet).pop(sort),
            ),
        ],
      )),
    );
    if (choice != null && mounted) setState(() => _sort = choice);
  }

  Future<void> _open(ExpenseRecord expense) async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (widget.onExpenseTap != null) {
      widget.onExpenseTap!(expense);
      return;
    }
    await Navigator.of(context).push<void>(MaterialPageRoute<void>(
      builder: (_) => ExpenseDetailsScreen(
        expense: expense, repository: _repository,
        loadExpense: _repository is RemoteExpenseRepository
            ? (_repository as RemoteExpenseRepository).getExpense : null,
        onRequestReimbursement: _repository is RemoteExpenseRepository
            ? (_repository as RemoteExpenseRepository).requestReimbursement : null,
        selectedNavigationIndex: widget.selectedNavigationIndex,
        onNavigationSelected: widget.onNavigationSelected,
      )));
    if (mounted) await _load();
  }

  Future<void> _create() async {
    if (widget.onCreateExpense != null) {
      widget.onCreateExpense!();
      return;
    }
    final draft = await Navigator.of(context).push<ExpenseRecord>(
      MaterialPageRoute<ExpenseRecord>(
        builder: (_) => AddExpenseScreen(
          selectedNavigationIndex: widget.selectedNavigationIndex,
          onNavigationSelected: widget.onNavigationSelected,
        ),
      ),
    );
    if (draft == null || !mounted) return;
    try {
      await _repository.saveDraft(draft);
      if (!mounted) return;
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(_repository is RemoteExpenseRepository
              ? 'Expense saved for review.' : 'Expense saved locally for review.')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Unable to save the expense draft.')));
      }
    }
  }

  void _navigation(int index) {
    if (widget.onNavigationSelected == null) {
      Navigator.of(context).maybePop();
      return;
    }
    Navigator.of(context).pop();
    widget.onNavigationSelected!(index);
  }

  Widget _sortControl() => Sign2DigitalListSortControl(
    key: const Key('expenses-sort'),
    value: _sort.label,
    valueKey: const Key('expenses-sort-value'),
    onTap: _selectSort,
  );

  Widget _card(ExpenseRecord record) => Sign2DigitalEntryListCard(
    key: Key('expense-card-${record.id}'),
    leading: Sign2DigitalExpenseCategoryIcon(category: record.category),
    title: record.title,
    titleKey: Key('expense-title-${record.id}'),
    subtitle: [record.job, record.report]
      .where((part) => part.isNotEmpty).join(', '),
    dateText: _shortDate(record.date),
    trailingValue: record.formattedAmount,
    trailingKey: Key('expense-amount-${record.id}'),
    status: record.status.label,
    onTap: () => _open(record),
  );

  static String _shortDate(DateTime date) {
    const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug',
      'Sep','Oct','Nov','Dec'];
    return '${m[date.month - 1]} ${date.day}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(bottom: false, child: Column(children: [
        Sign2DigitalDashboardHeader(
          onNotificationTap: widget.onNotificationTap,
          onProfileTap: widget.onProfileTap,
        ),
        Expanded(child: Stack(children: [
            CustomScrollView(
              key: const Key('expenses-scroll'),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                  sliver: SliverToBoxAdapter(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Sign2DigitalSearchField(
                        controller: _search,
                        hintText: 'Search expenses',
                        onChanged: (_) => setState(() {}),
                        onTrailingTap: () =>
                          FocusManager.instance.primaryFocus?.unfocus()),
                      const SizedBox(height: 20),
                      Stack(children: [
                        const Positioned(
                          left: 0, right: 0, bottom: 0,
                          child: Divider(height: 1, thickness: 1,
                            color: AppColors.lightBorder)),
                        Sign2DigitalDetailsTabs(
                          labels: const [
                            'All', 'To Review', 'Approved', 'Reimbursed'],
                          selectedIndex: _tab,
                          onSelected: (index) => setState(() => _tab = index),
                        ),
                      ]),
                      const SizedBox(height: 20),
                      _sortControl(),
                    ],
                  )),
                ),
                if (_loading)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: CircularProgressIndicator(
                      key: Key('expenses-loading'))))
                else if (_error != null)
                  SliverFillRemaining(hasScrollBody: false,
                    child: Center(child: TextButton(
                      key: const Key('expenses-retry'), onPressed: _load,
                      child: Text('$_error. Tap to retry.'))))
                else if (visible.isEmpty)
                  SliverFillRemaining(hasScrollBody: false,
                    child: Center(child: Text(
                      _search.text.trim().isNotEmpty
                          ? 'No expenses match your search'
                          : 'No expenses in this category',
                      key: const Key('expenses-empty'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontFamily: 'Inter',
                        fontSize: 14, color: AppColors.secondaryText))))
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 95),
                    sliver: SliverList.builder(
                      itemCount: visible.length,
                      itemBuilder: (context, index) => Padding(
                        padding: EdgeInsets.only(
                          bottom: index == visible.length - 1 ? 0 : 20),
                        child: _card(visible[index]),
                      ),
                    ),
                  ),
              ],
            ),
            Positioned(right: 20, bottom: 20,
              child: SizedBox(width: 50, height: 50,
                child: FloatingActionButton(
                  key: const Key('expenses-create'),
                  heroTag: 'expenses-create',
                  onPressed: _create, elevation: 3,
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.white,
                  child: const Icon(Icons.add, size: 30)))),
          ]),
        ),
      ])),
      bottomNavigationBar: Sign2DigitalBottomNavigationBar(
        selectedIndex: widget.selectedNavigationIndex,
        onSelected: _navigation),
    );
  }
}
