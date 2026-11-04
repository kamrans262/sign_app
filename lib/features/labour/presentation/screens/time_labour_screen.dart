import '../../../../core/widgets/sign2digital_selection_sheet.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sign2digital_bottom_navigation_bar.dart';
import '../../../../core/widgets/sign2digital_dashboard_header.dart';
import '../../../../core/widgets/sign2digital_entry_list_card.dart';
import '../../../../core/widgets/sign2digital_list_sort_control.dart';
import '../../../../core/widgets/sign2digital_search_field.dart';
import '../../../../core/widgets/sign2digital_selection_field.dart';
import '../../../clients/presentation/widgets/sign2digital_details_tabs.dart';
import '../../../jobs/domain/job_model.dart';
import '../../data/demo_labour_repository.dart';
import '../../data/remote_labour_repository.dart';
import '../widgets/m15_live_timer_panel.dart';
import '../widgets/m15_labour_summary.dart';
import '../../../auth/data/mobile_auth_repository.dart';
import '../../../../core/services/active_company_session.dart';
import '../../../../core/services/sign_api_client.dart';
import '../../domain/labour_entry.dart';
import 'add_labour_entry_screen.dart';
import 'labour_entry_details_screen.dart';

enum LabourSort {
  newest('Date (newest)'),
  oldest('Date (oldest)'),
  mostHours('Hours (highest)'),
  leastHours('Hours (lowest)');
  const LabourSort(this.label);
  final String label;
}

class TimeLabourScreen extends StatefulWidget {
  const TimeLabourScreen({
    super.key,
    this.repository,
    this.onEntryTap,
    this.onCreateEntry,
    this.onNavigationSelected,
    this.onNotificationTap,
    this.onProfileTap,
    this.selectedNavigationIndex = 4,
    this.jobId, this.initialJob,
  });

  final LabourRepository? repository;
  final ValueChanged<LabourEntry>? onEntryTap;
  final ValueChanged<LabourEntryKind>? onCreateEntry;
  final ValueChanged<int>? onNavigationSelected;
  final VoidCallback? onNotificationTap;
  final VoidCallback? onProfileTap;
  final int selectedNavigationIndex;
  final String? jobId;
  final JobModel? initialJob;

  @override
  State<TimeLabourScreen> createState() => _TimeLabourScreenState();
}

class _TimeLabourScreenState extends State<TimeLabourScreen> {
  final _search = TextEditingController();
  late final LabourRepository _repository;
  List<LabourEntry> _all = [];
  List<JobModel> _jobs = [];
  bool _loading = true;
  String? _error;
  int _tab = 0;
  LabourSort _sort = LabourSort.newest;
  String? _jobId;

  LabourEntryKind get _kind =>
      _tab == 0 ? LabourEntryKind.labour : LabourEntryKind.timeSheet;
  JobModel? get _selectedJob {
    for (final job in _jobs) {
      if (job.id == _jobId) return job;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? (
      !MobileAuthRepository.shared.isSignedIn &&
      ActiveCompanySession.companyId == null
          ? const DemoLabourRepository() : RemoteLabourRepository.shared);
    _jobId = widget.jobId ?? (_repository is RemoteLabourRepository
        ? null : LabourDemoJobs.riverside.id);
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final records = await _repository.list();
      final jobs = await _repository.jobs();
      if (!mounted) return;
      setState(() {
        _all = records;
        _jobs = jobs;
        if (jobs.every((job) => job.id != _jobId)) _jobId = null;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Unable to load time entries.';
        });
      }
    }
  }

  List<LabourEntry> get _visible {
    final result = _all.where((item) =>
      item.kind == _kind &&
      (_jobId == null || item.jobId == _jobId) &&
      item.matches(_search.text)).toList();
    result.sort((a,b) {
      final n = switch (_sort) {
        LabourSort.newest => b.date.compareTo(a.date),
        LabourSort.oldest => a.date.compareTo(b.date),
        LabourSort.mostHours => b.hours.compareTo(a.hours),
        LabourSort.leastHours => a.hours.compareTo(b.hours),
      };
      return n == 0 ? a.id.compareTo(b.id) : n;
    });
    return result;
  }

  Future<void> _chooseJob() async {
    final search = TextEditingController();
    try {
      final selected = await Sign2DigitalSelectionSheet.showCustom<String>(
        title: 'Filter by Job',
        icon: Icons.work_outline_rounded,
        subtitle: 'Search or select the job to display',
        context: context, isScrollControlled: true,
        builder: (sheet) => StatefulBuilder(
          builder: (sheet, update) => SafeArea(child: SizedBox(
            height: MediaQuery.sizeOf(sheet).height * 0.65,
            child: Column(children: [
              Padding(padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  key: const Key('labour-job-filter-search'),
                  controller: search,
                  onChanged: (_) => update(() {}),
                  decoration: const InputDecoration(
                    hintText: 'Search jobs'),
                )),
              Expanded(child: ListView(children: [
                ListTile(key: const Key('labour-job-all'),
                  title: const Text('All Jobs'),
                  selected: _jobId == null,
                  onTap: () => Navigator.of(sheet).pop('')),
                for (final job in _jobs.where((item) =>
                    item.matches(search.text)))
                  ListTile(
                    key: Key('labour-job-option-${job.id}'),
                    selected: _jobId == job.id,
                    trailing: _jobId == job.id
                        ? const Icon(Icons.check_circle_rounded,
                            color: AppColors.primary) : null,
                    title: Text(job.title),
                    subtitle: Text(job.referenceNumber),
                    onTap: () => Navigator.of(sheet).pop(job.id),
                  ),
              ])),
            ]),
          )),
        ),
      );
      if (selected != null && mounted) {
        setState(() => _jobId = selected.isEmpty ? null : selected);
      }
    } finally { search.dispose(); }
  }

  Future<void> _chooseSort() async {
    final picked = await showModalBottomSheet<LabourSort>(
      context: context,
      builder: (sheet) => SafeArea(child: Column(
        mainAxisSize: MainAxisSize.min, children: [
          const ListTile(title: Text('Sort By')),
          for (final option in LabourSort.values)
            ListTile(
              key: Key('labour-sort-${option.name}'),
              title: Text(option.label),
              trailing: _sort == option
                  ? const Icon(Icons.check, color: AppColors.primary) : null,
              onTap: () => Navigator.of(sheet).pop(option),
            ),
        ],
      )),
    );
    if (picked != null && mounted) setState(() => _sort = picked);
  }

  Future<void> _open(LabourEntry record) async {
    if (widget.onEntryTap != null) {
      widget.onEntryTap!(record);
      return;
    }
    final deleted = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => LabourEntryDetailsScreen(
          entry: record,
          repository: _repository,
        ),
      ),
    );
    if (!mounted) { return; }
    // Re-read after a detail route, so the listing reflects edits/deletion.
    await _load();
    if (deleted == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Labour entry deleted.'),
      ));
    }
  }

  Future<void> _create() async {
    if (widget.onCreateEntry != null) {
      widget.onCreateEntry!(_kind);
      return;
    }
    final entry = await Navigator.of(context).push<LabourEntry>(
      MaterialPageRoute<LabourEntry>(
        builder: (_) => AddLabourEntryScreen(
          kind: _kind,
          jobs: _jobs,
          initialJob: _selectedJob,
          selectedNavigationIndex: widget.selectedNavigationIndex,
        ),
      ),
    );
    if (entry == null || !mounted) return;
    try {
      await _repository.save(entry);
      if (!mounted) return;
      setState(() { _jobId = entry.jobId; });
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_repository is RemoteLabourRepository
            ? 'Time entry saved as Pending for review.'
            : 'Time entry saved locally as Pending.')));
      }
    } on SignApiException catch (error) {
      if (mounted) {
        await _load();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not save the time entry.')));
      }
    }
  }

  void _navigation(int index) {
    if (index == widget.selectedNavigationIndex) return;
    if (widget.onNavigationSelected == null) {
      Navigator.of(context).maybePop();
      return;
    }
    Navigator.of(context).pop();
    widget.onNavigationSelected!(index);
  }

  static String _date(DateTime day) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[day.month - 1]} ${day.day}, ${day.year}';
  }

  Widget _card(LabourEntry entry) => Sign2DigitalEntryListCard(
    key: Key('labour-card-${entry.id}'),
    shadow: true,
    leading: CircleAvatar(
      radius: 20,
      backgroundColor: const Color(0xFFE3ECF0),
      child: Text(entry.initials, style: const TextStyle(
        fontFamily: 'Inter', fontSize: 14,
        fontWeight: FontWeight.w600, color: AppColors.white)),
    ),
    title: entry.workerName,
    titleKey: Key('labour-title-${entry.id}'),
    subtitle: entry.role,
    dateText: _date(entry.date),
    trailingValue: entry.formattedHours,
    trailingKey: Key('labour-hours-${entry.id}'),
    status: entry.statusLabel,
    onTap: () => _open(entry),
  );

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
              key: const Key('labour-scroll'),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 15),
                  sliver: SliverToBoxAdapter(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Sign2DigitalSearchField(
                        controller: _search,
                        hintText: 'Search time entries',
                        onChanged: (_) => setState(() {}),
                        onTrailingTap: () => FocusManager.instance.primaryFocus?.unfocus(),
                      ),
                      const SizedBox(height: 20),
                      Stack(children: [
                        const Positioned(
                          left: 0, right: 0, bottom: 0,
                          child: Divider(height: 1, thickness: 1,
                            color: AppColors.lightBorder)),
                        Sign2DigitalDetailsTabs(
                          labels: const ['Labour', 'Time Sheet'],
                          selectedIndex: _tab,
                          onSelected: (index) => setState(() => _tab = index),
                        ),
                      ]),
                      const SizedBox(height: 20),
                      Sign2DigitalSelectionField(
                        key: const Key('labour-job-filter'),
                        label: 'Job',
                        iconAsset: 'assets/icons/description.svg',
                        hintText: 'All Jobs',
                        value: _selectedJob?.title,
                        onTap: _chooseJob,
                        trailing: const Icon(Icons.keyboard_arrow_down_rounded,
                          color: AppColors.secondaryText),
                      ),
                      if (_repository is RemoteLabourRepository) ...[
                        const SizedBox(height: 15),
                        M15LiveTimerPanel(
                          repository:_repository,
                          job:_selectedJob,
                          onUpdated:_load,
                        ),
                        if (_jobId != null) ...[
                          const SizedBox(height:15),
                          M15LabourSummary(jobId:_jobId!,refreshKey:_all.length),
                        ],
                      ],
                      const SizedBox(height: 15),
                      Sign2DigitalListSortControl(
                        key: const Key('labour-sort'),
                        value: _sort.label,
                        valueKey: const Key('labour-sort-value'),
                        onTap: _chooseSort,
                      ),
                    ],
                  )),
                ),
                if (_loading)
                  const SliverFillRemaining(hasScrollBody: false,
                    child: Center(child: CircularProgressIndicator(
                      key: Key('labour-loading'))))
                else if (_error != null)
                  SliverFillRemaining(hasScrollBody: false,
                    child: Center(child: TextButton(
                      key: const Key('labour-retry'), onPressed: _load,
                      child: Text('$_error Tap to retry.'))))
                else if (visible.isEmpty)
                  SliverFillRemaining(hasScrollBody: false,
                    child: Center(child: Text(
                      _search.text.trim().isNotEmpty
                        ? 'No matching entries'
                        : 'No entries for this selection',
                      key: const Key('labour-empty'),
                      style: const TextStyle(fontFamily: 'Inter',
                        fontSize: 14, color: AppColors.secondaryText))))
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                    sliver: SliverList.builder(
                      itemCount: visible.length,
                      itemBuilder: (context, index) => Padding(
                        padding: EdgeInsets.only(bottom:
                            index == visible.length - 1 ? 0 : 20),
                        child: _card(visible[index]),
                      ),
                    ),
                  ),
              ],
            ),
            Positioned(right: 20, bottom: 20,
              child: SizedBox(width: 50, height: 50,
                child: FloatingActionButton(
                  key: const Key('labour-create'),
                  heroTag: 'labour-create',
                  onPressed: _create,
                  elevation: 3, backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.white,
                  child: const Icon(Icons.add, size: 30)))),
          ]),
        ),
      ])),
      bottomNavigationBar: Sign2DigitalBottomNavigationBar(
        selectedIndex: widget.selectedNavigationIndex,
        onSelected: _navigation,
      ),
    );
  }
}
