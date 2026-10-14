import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sign2digital_bottom_navigation_bar.dart';
import '../../../../core/widgets/sign2digital_dashboard_header.dart';
import '../../../../core/widgets/sign2digital_entry_list_card.dart';
import '../../../../core/widgets/sign2digital_list_sort_control.dart';
import '../../../../core/widgets/sign2digital_search_field.dart';
import '../../../clients/presentation/widgets/sign2digital_details_tabs.dart';
import '../../data/demo_deposit_repository.dart';
import '../../domain/deposit_record.dart';

enum DepositSort {
  newest('Date (newest)'),
  oldest('Date (oldest)'),
  highest('Amount (highest)'),
  lowest('Amount (lowest)');

  const DepositSort(this.label);
  final String label;
}

class DepositsScreen extends StatefulWidget {
  const DepositsScreen({
    super.key, this.repository, this.onDepositTap, this.onCreateDeposit,
    this.onNavigationSelected, this.onNotificationTap, this.onProfileTap,
    this.selectedNavigationIndex = 4,
  });

  final DepositRepository? repository;
  final ValueChanged<DepositRecord>? onDepositTap;
  final VoidCallback? onCreateDeposit;
  final ValueChanged<int>? onNavigationSelected;
  final VoidCallback? onNotificationTap;
  final VoidCallback? onProfileTap;
  final int selectedNavigationIndex;

  @override
  State<DepositsScreen> createState() => _DepositsScreenState();
}

class _DepositsScreenState extends State<DepositsScreen> {
  final _search = TextEditingController();
  late final DepositRepository _repository;
  List<DepositRecord> _all = [];
  bool _loading = true;
  String? _error;
  int _tab = 0;
  DepositSort _sort = DepositSort.newest;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? const DemoDepositRepository();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) { return; }
    setState(() { _loading = true; _error = null; });
    try {
      final records = await _repository.listDeposits();
      if (!mounted) { return; }
      setState(() { _all = records; _loading = false; });
    } catch (_) {
      if (!mounted) { return; }
      setState(() {
        _error = 'Unable to load deposits';
        _loading = false;
      });
    }
  }

  List<DepositRecord> get _visible {
    final list = _all.where((item) =>
        (_tab == 0 || item.status == DepositStatus.values[_tab - 1]) &&
        item.matches(_search.text)).toList();
    list.sort((a, b) {
      int result = switch (_sort) {
        DepositSort.newest => b.date.compareTo(a.date),
        DepositSort.oldest => a.date.compareTo(b.date),
        DepositSort.highest => b.amount.compareTo(a.amount),
        DepositSort.lowest => a.amount.compareTo(b.amount),
      };
      return result == 0 ? a.id.compareTo(b.id) : result;
    });
    return list;
  }

  Future<void> _selectSort() async {
    final choice = await showModalBottomSheet<DepositSort>(
      context: context,
      builder: (sheet) => SafeArea(child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ListTile(title: Text('Sort By')),
          for (final sort in DepositSort.values)
            ListTile(
              key: Key('deposit-sort-${sort.name}'),
              title: Text(sort.label),
              trailing: _sort == sort
                  ? const Icon(Icons.check, color: AppColors.primary) : null,
              onTap: () => Navigator.of(sheet).pop(sort),
            ),
        ],
      )),
    );
    if (choice != null && mounted) {
      setState(() => _sort = choice);
    }
  }

  void _notice(String message) {
    if (!mounted) { return; }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)));
  }

  void _open(DepositRecord deposit) {
    FocusManager.instance.primaryFocus?.unfocus();
    if (widget.onDepositTap != null) {
      widget.onDepositTap!(deposit);
      return;
    }
    _notice('Deposit details are not connected yet.');
  }

  void _create() {
    if (widget.onCreateDeposit != null) {
      widget.onCreateDeposit!();
      return;
    }
    _notice('Deposit creation is not connected yet.');
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
    key: const Key('deposits-sort'),
    value: _sort.label,
    valueKey: const Key('deposits-sort-value'),
    onTap: _selectSort,
  );

  Widget _card(DepositRecord record) => Sign2DigitalEntryListCard(
    key: Key('deposit-card-${record.id}'),
    shadow: true,
    leading: const CircleAvatar(
      radius: 20,
      backgroundColor: Color(0xFFE3ECF0),
      child: Icon(Icons.account_balance_outlined,
        size: 24, color: AppColors.primary),
    ),
    title: record.title,
    titleKey: Key('deposit-title-${record.id}'),
    subtitle: 'Client: ${record.clientName}',
    dateText: _shortDate(record.date),
    trailingValue: record.formattedAmount,
    trailingKey: Key('deposit-amount-${record.id}'),
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
        Expanded(child: Center(child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Stack(children: [
            CustomScrollView(
              key: const Key('deposits-scroll'),
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
                            'All', 'Pending', 'Received', 'Refunded'],
                          horizontalPadding: 15,
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
                      key: Key('deposits-loading'))))
                else if (_error != null)
                  SliverFillRemaining(hasScrollBody: false,
                    child: Center(child: TextButton(
                      key: const Key('deposits-retry'), onPressed: _load,
                      child: Text('$_error. Tap to retry.'))))
                else if (visible.isEmpty)
                  SliverFillRemaining(hasScrollBody: false,
                    child: Center(child: Text(
                      _search.text.trim().isNotEmpty
                          ? 'No deposits match your search'
                          : 'No deposits in this category',
                      key: const Key('deposits-empty'),
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
                  key: const Key('deposits-create'),
                  heroTag: 'deposits-create',
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
