import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sign2digital_dashboard_header.dart';
import '../../../../core/widgets/sign2digital_entry_list_card.dart';
import '../../../../core/widgets/sign2digital_search_field.dart';
import '../../../clients/data/demo_client_repository.dart';
import '../../../clients/domain/client_profile.dart';
import '../../../clients/presentation/screens/client_details_screen.dart';
import '../../../clients/presentation/widgets/sign2digital_details_tabs.dart';
import '../../../deposits/data/demo_deposit_repository.dart';
import '../../../deposits/domain/deposit_record.dart';
import '../../../deposits/presentation/screens/deposit_details_screen.dart';
import '../../../documents/domain/document_record.dart';
import '../../../documents/presentation/screens/document_details_screen.dart';
import '../../../equipment/data/demo_equipment_repository.dart';
import '../../../equipment/domain/equipment_record.dart';
import '../../../equipment/presentation/screens/equipment_details_screen.dart';
import '../../../expenses/data/demo_expense_repository.dart';
import '../../../expenses/domain/expense_record.dart';
import '../../../expenses/presentation/screens/expense_details_screen.dart';
import '../../../invoices/data/demo_invoice_repository.dart';
import '../../../invoices/domain/invoice_record.dart';
import '../../../invoices/presentation/screens/invoice_details_screen.dart';
import '../../../jobs/domain/job_model.dart';
import '../../../jobs/presentation/screens/job_details_screen.dart';
import '../../data/global_search_source.dart';

/// Existing listing widgets adapted to search every connected UI repository.
/// Screen has no bottom bar, as in the Search Across the App Figma design.
class GlobalSearchScreen extends StatefulWidget {
  const GlobalSearchScreen({
    super.key, this.provider, this.onResultTap,
    this.onNotificationTap, this.onProfileTap,
    this.initialQuery = '', this.previewLimit = 10,
  });

  final GlobalSearchProvider? provider;
  final ValueChanged<GlobalSearchResult>? onResultTap;
  final VoidCallback? onNotificationTap, onProfileTap;
  final String initialQuery;
  final int previewLimit;

  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> {
  late final GlobalSearchProvider _provider;
  late final TextEditingController _search;
  List<GlobalSearchResult> _records = const [];
  GlobalSearchTab _tab = GlobalSearchTab.all;
  String? _error;
  bool _loading = true, _seeAll = false;
  int _loadSequence = 0;

  static const _tabs = [
    'All', 'Jobs', 'Clients', 'Documents', 'Invoices', 'More',
  ];

  @override
  void initState() {
    super.initState();
    _provider = widget.provider ?? ExistingGlobalSearchProvider();
    _search = TextEditingController(text: widget.initialQuery);
    _reload();
  }

  @override
  void dispose() {
    ++_loadSequence; // Invalidates any late future completion.
    _search.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final request = ++_loadSequence;
    if (mounted) {
      setState(() { _loading = true; _error = null; });
    }
    try {
      final all = await _provider.loadAll();
      if (!mounted || request != _loadSequence) return;
      setState(() {
        _records = all;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || request != _loadSequence) return;
      setState(() {
        _loading = false;
        _error = 'Unable to load search results';
      });
    }
  }

  List<GlobalSearchResult> get _matches => _records.where((entry) =>
    entry.inTab(_tab) && entry.matches(_search.text)).toList();

  void _onQueryChanged(String _) {
    setState(() => _seeAll = false);
  }

  void _selectTab(int index) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _tab = GlobalSearchTab.values[index];
      _seeAll = false;
    });
  }

  IconData _icon(GlobalSearchCategory category) => switch (category) {
    GlobalSearchCategory.jobs => Icons.account_balance_outlined,
    GlobalSearchCategory.clients => Icons.people_outline,
    GlobalSearchCategory.documents => Icons.description_outlined,
    GlobalSearchCategory.invoices => Icons.receipt_long_outlined,
    GlobalSearchCategory.expenses => Icons.payments_outlined,
    GlobalSearchCategory.deposits => Icons.account_balance_outlined,
    GlobalSearchCategory.equipment => Icons.construction_outlined,
    GlobalSearchCategory.reports => Icons.assessment_outlined,
    GlobalSearchCategory.reminders => Icons.notifications_active_outlined,
  };

  void _notice(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _open(GlobalSearchResult entry) async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (widget.onResultTap != null) {
      widget.onResultTap!(entry);
      return;
    }

    // IDs and typed records are taken directly from the same repository load.
    // Navigates to the existing details screens, not a generic mock preview.
    final repo = _provider is ExistingGlobalSearchProvider
        ? _provider as ExistingGlobalSearchProvider
        : null;
    final Widget? destination = switch (entry.record) {
      final JobModel job => JobDetailsScreen(job: job),
      final ClientProfile client => ClientDetailsScreen(
        client: client,
        repository: repo?.clients ?? DemoClientRepository()),
      final InvoiceRecord invoice => InvoiceDetailsScreen(
        invoice: invoice,
        repository: repo?.invoices ?? const DemoInvoiceRepository()),
      final DepositRecord deposit => DepositDetailsScreen(
        deposit: deposit,
        repository: repo?.deposits ?? const DemoDepositRepository()),
      final ExpenseRecord expense => ExpenseDetailsScreen(
        expense: expense,
        repository: repo?.expenses ?? const DemoExpenseRepository()),
      final EquipmentRecord equipment => EquipmentDetailsScreen(
        equipment: equipment,
        repository: repo?.equipment ?? const DemoEquipmentRepository()),
      final DocumentRecord document => DocumentDetailsScreen(
        documentId: document.id, document: document),
      _ => null,
    };
    if (destination == null) {
      _notice('This category has no connected details screen.');
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => destination),
    );
    if (mounted) await _reload();
  }

  Widget _card(GlobalSearchResult entry) => Sign2DigitalEntryListCard(
    key: Key('global-search-result-${entry.key}'),
    shadow: true,
    leading: CircleAvatar(
      radius: 20, backgroundColor: const Color(0xFFE3ECF0),
      child: Icon(_icon(entry.category), size: 24, color: AppColors.primary),
    ),
    title: entry.title,
    subtitle: entry.subtitle,
    dateText: entry.details,
    trailingValue: '',
    showTrailingValue: false,
    status: entry.category.label,
    onTap: () => _open(entry),
  );

  @override
  Widget build(BuildContext context) {
    final matching = _matches;
    final limit = widget.previewLimit > 0 ? widget.previewLimit : 10;
    final visible = _seeAll ? matching : matching.take(limit).toList();
    return Scaffold(
      backgroundColor: AppColors.white,
      resizeToAvoidBottomInset: true,
      body: SafeArea(child: Column(children: [
        Sign2DigitalDashboardHeader(
          onNotificationTap: widget.onNotificationTap,
          onProfileTap: widget.onProfileTap),
        Expanded(child: Center(child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: CustomScrollView(
            key: const Key('global-search-scroll'),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                sliver: SliverToBoxAdapter(child: Column(children: [
                  Sign2DigitalSearchField(
                    controller: _search,
                    hintText: 'Search across the app',
                    onChanged: _onQueryChanged,
                    onTrailingTap: () {
                      FocusManager.instance.primaryFocus?.unfocus();
                      _reload();
                    },
                  ),
                  const SizedBox(height: 20),
                  Stack(children: [
                    const Positioned(left: 0, right: 0, bottom: 0,
                      child: Divider(
                        height: 1, thickness: 1,
                        color: AppColors.lightBorder)),
                    Sign2DigitalDetailsTabs(
                      labels: _tabs,
                      selectedIndex: _tab.index,
                      horizontalPadding: 15,
                      onSelected: _selectTab),
                  ]),
                ])),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                sliver: SliverToBoxAdapter(child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(child: Text(
                      'Results (${_loading ? '…' : matching.length})',
                      key: const Key('global-search-count'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Inter', fontSize: 18,
                        fontWeight: FontWeight.w600, letterSpacing: -0.3,
                        color: AppColors.dark),
                    )),
                    const SizedBox(width: 8),
                    TextButton(
                      key: const Key('global-search-see-all'),
                      onPressed: _loading || _error != null
                          ? null : () => setState(() => _seeAll = !_seeAll),
                      child: Text(_seeAll ? 'Show less' : 'See all',
                        style: const TextStyle(fontFamily: 'Inter',
                          fontSize: 14, fontWeight: FontWeight.w500,
                          color: AppColors.primary)),
                    ),
                  ],
                )),
              ),
              if (_loading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()))
              else if (_error != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: TextButton(
                    key: const Key('global-search-retry'),
                    onPressed: _reload,
                    child: Text('$_error. Tap to retry.'))))
              else if (matching.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: Text(
                    _search.text.trim().isEmpty
                      ? 'No records available to search'
                      : 'No results found',
                    key: const Key('global-search-empty'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Inter', fontSize: 14,
                      color: AppColors.placeholder))))
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  sliver: SliverList.builder(
                    itemCount: visible.length,
                    itemBuilder: (context, index) =>
                      Padding(
                        padding: EdgeInsets.only(
                          bottom: index < visible.length - 1 ? 20 : 0),
                        child: _card(visible[index])),
                  ),
                ),
            ],
          ),
        ))),
      ])),
    );
  }
}
