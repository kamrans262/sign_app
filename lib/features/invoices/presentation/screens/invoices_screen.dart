import 'package:flutter/material.dart';
import '../../../../core/widgets/sign2digital_styled_bottom_sheet.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sign2digital_bottom_navigation_bar.dart';
import '../../../../core/widgets/sign2digital_dashboard_header.dart';
import '../../../../core/widgets/sign2digital_entry_list_card.dart';
import '../../../../core/widgets/sign2digital_list_sort_control.dart';
import '../../../../core/widgets/sign2digital_search_field.dart';
import '../../../clients/presentation/widgets/sign2digital_details_tabs.dart';
import '../../data/demo_invoice_repository.dart';
import '../../data/remote_invoice_repository.dart';
import '../../../auth/data/mobile_auth_repository.dart';
import '../../../../core/services/active_company_session.dart';
import '../../domain/invoice_record.dart';
import 'add_invoice_screen.dart';
import '../../../jobs/domain/job_model.dart';
import 'invoice_details_screen.dart';

enum InvoiceSort {
  newest('Date (newest)'),
  oldest('Date (oldest)'),
  highest('Amount (highest)'),
  lowest('Amount (lowest)');

  const InvoiceSort(this.label);
  final String label;
}

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({
    super.key, this.repository, this.onInvoiceTap, this.onCreateInvoice,
    this.onNavigationSelected, this.onNotificationTap, this.onProfileTap,
    this.selectedNavigationIndex = 4,
    this.jobId,
  });

  final InvoiceRepository? repository;
  final ValueChanged<InvoiceRecord>? onInvoiceTap;
  final VoidCallback? onCreateInvoice;
  final ValueChanged<int>? onNavigationSelected;
  final VoidCallback? onNotificationTap;
  final VoidCallback? onProfileTap;
  final int selectedNavigationIndex;
  /// A Job Details route filters this screen to its persisted job ID.
  final String? jobId;

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  final _search = TextEditingController();
  late InvoiceRepository _repository;
  List<InvoiceRecord> _all = [];
  bool _loading = true;
  String? _error;
  int _tab = 0;
  InvoiceSort _sort = InvoiceSort.newest;
  int _loadSerial=0;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ??
        (!MobileAuthRepository.shared.isSignedIn &&
            ActiveCompanySession.companyId==null
            ? const DemoInvoiceRepository() : RemoteInvoiceRepository.shared);
    ActiveCompanySession.selected.addListener(_companyChanged);
    _load();
  }

  @override
  void dispose() {
    ActiveCompanySession.selected.removeListener(_companyChanged);
    _search.dispose();
    super.dispose();
  }

  void _companyChanged() {
    if(!mounted)return;
    if(widget.repository==null){
      _repository=(!MobileAuthRepository.shared.isSignedIn &&
          ActiveCompanySession.companyId==null)
          ?const DemoInvoiceRepository():RemoteInvoiceRepository.shared;
    }
    setState((){
      _all=[];
      _loading=true;
      _error=null;
    });
    _load();
  }

  Future<void> _load() async {
    final serial=++_loadSerial;
    final company=ActiveCompanySession.companyId;
    if (!mounted) { return; }
    setState(() { _loading = true; _error = null; });
    try {
      final records = await _repository.listInvoices();
      if (!mounted||serial!=_loadSerial||
          ActiveCompanySession.companyId!=company) { return; }
      setState(() { _all = records; _loading = false; });
    } catch (_) {
      if (!mounted||serial!=_loadSerial||
          ActiveCompanySession.companyId!=company) { return; }
      setState(() {
        _error = 'Unable to load invoices';
        _loading = false;
      });
    }
  }

  List<InvoiceRecord> get _visible {
    final list = _all.where((item) =>
        (widget.jobId == null || item.jobId == widget.jobId) &&
        (_tab == 0 || item.status == InvoiceStatus.values[_tab - 1] ||
          // Pending includes partially settled invoices; keep six approved tabs.
          (_tab == 3 && item.status == InvoiceStatus.partiallyPaid)) &&
        item.matches(_search.text)).toList();
    list.sort((a, b) {
      int result = switch (_sort) {
        InvoiceSort.newest => b.date.compareTo(a.date),
        InvoiceSort.oldest => a.date.compareTo(b.date),
        InvoiceSort.highest => b.amount.compareTo(a.amount),
        InvoiceSort.lowest => a.amount.compareTo(b.amount),
      };
      return result == 0 ? a.id.compareTo(b.id) : result;
    });
    return list;
  }

  Future<void> _selectSort() async {
    final choice = await showSign2DigitalBottomSheet<InvoiceSort>(
      context: context,
      builder: (sheet) => SafeArea(child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ListTile(title: Text('Sort By')),
          for (final sort in InvoiceSort.values)
            ListTile(
              key: Key('invoice-sort-${sort.name}'),
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

  Future<void> _open(InvoiceRecord invoice) async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (widget.onInvoiceTap != null) {
      widget.onInvoiceTap!(invoice);
      return;
    }
    var selected=invoice;
    if(_repository is RemoteInvoiceRepository){
      try{
        selected=await (_repository as RemoteInvoiceRepository)
            .invoiceDetail(invoice.id);
      }catch(_){
        _notice('Unable to load verified invoice details.');
        return;
      }
    }
    if(!mounted)return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => InvoiceDetailsScreen(
          invoice: selected,
          repository: _repository,
          selectedNavigationIndex: widget.selectedNavigationIndex,
          onNavigationSelected: widget.onNavigationSelected,
        ),
      ),
    );
    if (mounted) { await _load(); }
  }

  Future<void> _create() async {
    if (widget.onCreateInvoice != null) {
      widget.onCreateInvoice!();
      return;
    }
    final company=ActiveCompanySession.companyId;
    List<JobModel>? jobs;
    if(_repository is RemoteInvoiceRepository){
      try{
        jobs=await (_repository as RemoteInvoiceRepository).jobs();
      }catch(_){
        _notice('Unable to load current jobs.');
        return;
      }
    }
    if (widget.jobId != null && jobs != null) {
      jobs = jobs.where((job) => job.id == widget.jobId).toList();
      if (jobs.isEmpty) { _notice('Job is no longer available.'); return; }
    }
    if(!mounted||company!=ActiveCompanySession.companyId)return;
    final draft = await Navigator.of(context).push<InvoiceRecord>(
      MaterialPageRoute<InvoiceRecord>(
        builder: (_) => AddInvoiceScreen(
          jobs:jobs,
          repository: _repository,
          selectedNavigationIndex: widget.selectedNavigationIndex,
          onNavigationSelected: widget.onNavigationSelected,
        ),
      ),
    );
    if (draft == null || !mounted) { return; }
    // The create route awaited repository.saveDraft before returning.
    // Do not save twice (or falsely report a duplicate as an error).
    await _load();
    if (mounted) { _notice('Invoice draft saved.'); }
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
    key: const Key('invoices-sort'),
    value: _sort.label,
    valueKey: const Key('invoices-sort-value'),
    onTap: _selectSort,
  );

  Widget _card(InvoiceRecord record) => LayoutBuilder(
    builder: (context, constraints) {
      // Keep the full Figma layout on standard phones; compact narrowly.
      final compact = constraints.maxWidth < 300;
      return Sign2DigitalEntryListCard(
    key: Key('invoice-card-${record.id}'),
    shadow: true,
    leading: CircleAvatar(
      radius: compact ? 16 : 20,
      backgroundColor: const Color(0xFFE3ECF0),
      child: SvgPicture.asset('assets/icons/description.svg',
        width: compact ? 20 : 24, height: compact ? 20 : 24,
        colorFilter: const ColorFilter.mode(
          AppColors.primary, BlendMode.srcIn)),
    ),
    title: record.number,
    titleKey: Key('invoice-title-${record.id}'),
    subtitle: '${record.project}\n${record.clientName}',
    dateText: _shortDate(record.date),
    trailingValue: record.formattedAmount,
    trailingKey: Key('invoice-amount-${record.id}'),
    status: compact && record.status == InvoiceStatus.pending
        ? 'Pending' : record.status.label,
    onTap: () => _open(record),
      );
    },
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
              key: const Key('invoices-scroll'),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                  sliver: SliverToBoxAdapter(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Sign2DigitalSearchField(
                        controller: _search,
                        hintText: 'Search Invoices',
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
                            'All', 'Draft', 'Sent', 'Pending', 'Paid', 'Overdue',
                            'Partially Paid'],
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
                      key: Key('invoices-loading'))))
                else if (_error != null)
                  SliverFillRemaining(hasScrollBody: false,
                    child: Center(child: TextButton(
                      key: const Key('invoices-retry'), onPressed: _load,
                      child: Text('$_error. Tap to retry.'))))
                else if (visible.isEmpty)
                  SliverFillRemaining(hasScrollBody: false,
                    child: Center(child: Text(
                      _search.text.trim().isNotEmpty
                          ? 'No invoices match your search'
                          : 'No invoices in this category',
                      key: const Key('invoices-empty'),
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
                  key: const Key('invoices-create'),
                  heroTag: 'invoices-create',
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
