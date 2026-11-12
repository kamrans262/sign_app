import '../../../../core/navigation/sign2digital_navigation.dart';
import 'package:flutter/material.dart';
import '../../../../core/widgets/sign2digital_styled_bottom_sheet.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/sign_api_client.dart';
import '../../../../core/widgets/sign2digital_bottom_navigation_bar.dart';
import '../../../../core/widgets/sign2digital_dashboard_header.dart';
import '../../../../core/widgets/sign2digital_entry_list_card.dart';
import '../../../../core/widgets/sign2digital_list_sort_control.dart';
import '../../../../core/widgets/sign2digital_search_field.dart';
import '../../../clients/presentation/widgets/sign2digital_details_tabs.dart';
import '../../data/demo_deposit_repository.dart';
import '../../data/remote_deposit_repository.dart';
import '../../../auth/data/mobile_auth_repository.dart';
import '../../../../core/services/active_company_session.dart';
import '../../domain/deposit_record.dart';
import '../../../labour/data/demo_labour_repository.dart';
import '../../../jobs/domain/job_model.dart';
import 'add_deposit_screen.dart';
import 'deposit_details_screen.dart';

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
    this.jobId,
    this.initialJob,
  });

  final DepositRepository? repository;
  final ValueChanged<DepositRecord>? onDepositTap;
  final VoidCallback? onCreateDeposit;
  final ValueChanged<int>? onNavigationSelected;
  final VoidCallback? onNotificationTap;
  final VoidCallback? onProfileTap;
  final int selectedNavigationIndex;
  /// A Job Details route filters this screen to its persisted job ID.
  final String? jobId;
  final JobModel? initialJob;

  @override
  State<DepositsScreen> createState() => _DepositsScreenState();
}

class _DepositsScreenState extends State<DepositsScreen> {
  final _search = TextEditingController();
  late DepositRepository _repository;
  List<DepositRecord> _all = [];
  bool _loading = true;
  String? _error;
  int _tab = 0;
  DepositSort _sort = DepositSort.newest;
  int _loadSerial=0;
  DepositRecord? _retryDraft;
  bool _retryNeedsEditing = false;
  bool _savingDeposit = false;

  void _companyChanged() {
    if(!mounted)return;
    // A pending draft must never be retried against a different company.
    _retryDraft=null;
    _retryNeedsEditing=false;
    if(widget.repository==null){
      _repository=(!MobileAuthRepository.shared.isSignedIn &&
          ActiveCompanySession.companyId==null)
          ?const DemoDepositRepository():RemoteDepositRepository.shared;
    }
    setState((){_all=[];_loading=true;_error=null;});
    _load();
  }

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ??
        (!MobileAuthRepository.shared.isSignedIn &&
         ActiveCompanySession.companyId==null
          ? const DemoDepositRepository() : RemoteDepositRepository.shared);
    ActiveCompanySession.selected.addListener(_companyChanged);
    _load();
  }

  @override
  void dispose() {
    ActiveCompanySession.selected.removeListener(_companyChanged);
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final serial=++_loadSerial;
    final company=ActiveCompanySession.companyId;
    if (!mounted) { return; }
    setState(() { _loading = true; _error = null; });
    try {
      final records = await _repository.listDeposits();
      if (!mounted || serial!=_loadSerial ||
          ActiveCompanySession.companyId!=company) { return; }
      setState(() { _all = records; _loading = false; });
    } catch (_) {
      if (!mounted || serial!=_loadSerial ||
          ActiveCompanySession.companyId!=company) { return; }
      setState(() {
        _error = 'Unable to load deposits';
        _loading = false;
      });
    }
  }

  List<DepositRecord> get _visible {
    final list = _all.where((item) =>
        (widget.jobId == null || item.jobId == widget.jobId) &&
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
    final choice = await showSign2DigitalBottomSheet<DepositSort>(
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
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.dark,
        duration: const Duration(seconds: 6),
        content: Text(message, style: const TextStyle(
          fontFamily: 'Inter', fontSize: 14, color: AppColors.white)),
      ));
  }

  Future<void> _open(DepositRecord deposit) async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (widget.onDepositTap != null) {
      widget.onDepositTap!(deposit);
      return;
    }
    DepositRecord selected=deposit;
    final remote=_repository;
    if (remote is RemoteDepositRepository) {
      try {
        selected=await remote.detail(deposit.id);
      } catch (_) {
        _notice('Unable to load verified deposit details.');
        return;
      }
    }
    if(!mounted)return;
    await Sign2DigitalNavigation.push<bool>(context,
      MaterialPageRoute<bool>(
        builder: (_) => DepositDetailsScreen(
          deposit: selected, repository: _repository),
      ),
    );
    if (mounted) { await _load(); }
  }

  Future<void> _create() async {
    if (_savingDeposit) return;
    if (widget.onCreateDeposit != null) {
      widget.onCreateDeposit!();
      return;
    }
    // On an ambiguous network failure preserve the identical draft/key.
    // Creating a new draft would risk two pending payment requests.
    DepositRecord? deposit=_retryDraft;
    if(deposit==null || _retryNeedsEditing) {
      var jobs=LabourDemoJobs.all;
      final remote=_repository;
      if(remote is RemoteDepositRepository) {
        try {
          jobs=await remote.jobs();
        }catch(_){
          _notice('Unable to load current jobs.');
          return;
        }
      }
      if (widget.jobId != null) {
        jobs = jobs.where((job) => job.id == widget.jobId).toList();
        if (jobs.isEmpty) { _notice('Job is no longer available.'); return; }
      }
      if(!mounted)return;
      deposit=await Sign2DigitalNavigation.push<DepositRecord>(context,
        MaterialPageRoute<DepositRecord>(
          builder: (_) => AddDepositScreen(
            jobs: jobs,
            initialDeposit: _retryNeedsEditing ? deposit : null,
            initialJob: widget.initialJob ?? (widget.jobId == null ? null : jobs.first),
            selectedNavigationIndex: widget.selectedNavigationIndex,
            onNavigationSelected: widget.onNavigationSelected,
          ),
        ),
      );
    }
    if (deposit == null || !mounted) return;
    final company = ActiveCompanySession.companyId;
    setState(() => _savingDeposit = true);
    try {
      await _repository.saveDeposit(deposit);
      if (!mounted || ActiveCompanySession.companyId != company) return;
      _retryDraft = null;
      _retryNeedsEditing = false;
      _search.clear();
      setState(() => _tab = 0);
      await _load();
      if (mounted) _notice('Deposit saved as Pending.');
    } on SignApiException catch (error) {
      if (!mounted || ActiveCompanySession.companyId != company) return;
      final code = error.statusCode;
      if (code == 400 || code == 422) {
        // Laravel rejected these values. No deposit was created; let the
        // user correct this same draft rather than replaying it unchanged.
        _retryDraft = deposit;
        _retryNeedsEditing = true;
        _notice('Deposit not accepted: ${error.message} '
            'Tap + to correct the entry.');
      } else if (code == 401 || code == 403 || code == 404 || code == 409) {
        // A definitive authorization, missing job or conflict response is
        // not a network timeout and must not be blindly retried.
        _retryDraft = null;
        _retryNeedsEditing = false;
        _notice('Deposit not saved: ${error.message}');
      } else {
        // A lost response may occur AFTER the deposit was committed.
        // Retain the exact request key and fields to avoid duplicates.
        _retryDraft = deposit;
        _retryNeedsEditing = false;
        await _load();
        if (mounted) _notice('Could not confirm the deposit save. '
            'Check the list, or tap + to retry the same draft safely.');
      }
    } catch (_) {
      if (!mounted || ActiveCompanySession.companyId != company) return;
      _retryDraft = deposit;
      _retryNeedsEditing = false;
      await _load();
      if (mounted) _notice('Could not confirm the deposit save. '
          'Check the list, or tap + to retry the same draft safely.');
    } finally {
      if (mounted) setState(() => _savingDeposit = false);
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
    return Theme(
      data: AppTheme.light,
      child: Scaffold(
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
                        hintText: 'Search deposits',
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
                  onPressed: _savingDeposit ? null : _create, elevation: 3,
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.white,
                  child: const Icon(Icons.add, size: 30)))),
          ]),
        ))),
      ])),
      bottomNavigationBar: Sign2DigitalBottomNavigationBar(
        selectedIndex: widget.selectedNavigationIndex,
        onSelected: _navigation),
    ));
  }
}
