import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sign2digital_bottom_navigation_bar.dart';
import '../../../../core/widgets/sign2digital_dashboard_header.dart';
import '../../../../core/widgets/sign2digital_outlined_container.dart';
import '../../../../core/widgets/sign2digital_search_field.dart';
import '../../../clients/presentation/widgets/sign2digital_details_tabs.dart';
import '../../../clients/presentation/widgets/sign2digital_status_badge.dart';
import '../../data/demo_expense_repository.dart';
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
    _repository = widget.repository ?? const DemoExpenseRepository();
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
          content: Text('Expense saved locally for review.')));
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

  Widget _sortControl() => Align(
    alignment: Alignment.centerLeft,
    child: InkWell(
      key: const Key('expenses-sort'),
      onTap: _selectSort,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Text('Sort By: ', style: TextStyle(
            fontFamily: 'Inter', fontSize: 16, letterSpacing: -0.3,
            fontWeight: FontWeight.w500, color: AppColors.dark)),
          Flexible(child: Text(_sort.label,
            key: const Key('expenses-sort-value'),
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Inter', fontSize: 16, letterSpacing: -0.3,
              fontWeight: FontWeight.w500, color: AppColors.primary))),
          const SizedBox(width: 8),
          const Icon(Icons.keyboard_arrow_down_rounded,
            size: 24, color: AppColors.secondaryText),
        ]),
      ),
    ),
  );

  Widget _card(ExpenseRecord record) => Material(
    key: Key('expense-card-${record.id}'),
    color: Colors.transparent,
    child: InkWell(
      onTap: () => _open(record),
      borderRadius: BorderRadius.circular(10),
      child: Sign2DigitalOutlinedContainer(
        padding: const EdgeInsets.all(15),
        child: LayoutBuilder(builder: (context, box) {
          final compact = box.maxWidth < 290;
          return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Sign2DigitalExpenseCategoryIcon(category: record.category),
            SizedBox(width: compact ? 9 : 15),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(record.title,
                  key: Key('expense-title-${record.id}'),
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 16,
                    fontWeight: FontWeight.w600, letterSpacing: -0.3,
                    color: AppColors.dark)),
                const SizedBox(height: 5),
                Text([record.job, record.report]
                    .where((part) => part.isNotEmpty).join(', '),
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 13,
                    color: AppColors.placeholder, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text(_shortDate(record.date),
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 13,
                    color: AppColors.placeholder, fontWeight: FontWeight.w500)),
              ],
            )),
            SizedBox(width: compact ? 4 : 10),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(record.formattedAmount,
                key: Key('expense-amount-${record.id}'),
                maxLines: 1, style: const TextStyle(
                  fontFamily: 'Inter', fontSize: 14, height: 1,
                  fontWeight: FontWeight.w500, letterSpacing: -0.3,
                  color: AppColors.dark)),
              const SizedBox(height: 5),
              Sign2DigitalStatusBadge(status: record.status.label),
            ]),
            const SizedBox(width: 5),
            const Icon(Icons.chevron_right_rounded,
              size: 24, color: AppColors.secondaryText),
          ]);
        }),
      ),
    ),
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
        Expanded(child: Center(child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Stack(children: [
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
                        hintText: 'Search documents',
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
        ))),
      ])),
      bottomNavigationBar: Sign2DigitalBottomNavigationBar(
        selectedIndex: widget.selectedNavigationIndex,
        onSelected: _navigation),
    );
  }
}
