import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sign2digital_bottom_navigation_bar.dart';
import '../../../../core/widgets/sign2digital_dashboard_header.dart';
import '../../../../core/widgets/sign2digital_input_field.dart';
import '../../../../core/widgets/sign2digital_primary_button.dart';
import '../../../../core/widgets/sign2digital_search_field.dart';
import '../../../clients/presentation/widgets/sign2digital_details_tabs.dart';
import '../../../quotes/presentation/widgets/sign2digital_quote_summary_card.dart';
import '../../data/demo_report_repository.dart';
import '../../domain/document_record.dart';
import 'document_details_screen.dart';
import 'site_report_wizard_screen.dart';
import 'work_acceptance_screen.dart';

/// Report library using the same list layout and document models as Documents.
/// A caller may inject real records and its own navigation/creation callbacks.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({
    super.key,
    this.repository,
    this.onReportTap,
    this.onCreateReport,
    this.reportGenerator,
    this.onNavigationSelected,
    this.onNotificationTap,
    this.onProfileTap,
    this.selectedNavigationIndex = 2,
  });

  final DocumentRepository? repository;
  final ValueChanged<DocumentRecord>? onReportTap;
  final VoidCallback? onCreateReport;
  /// Optional real report generation. Absence keeps local draft behavior.
  final Future<DocumentRecord> Function(DocumentRecord draft)? reportGenerator;
  final ValueChanged<int>? onNavigationSelected;
  final VoidCallback? onNotificationTap;
  final VoidCallback? onProfileTap;
  final int selectedNavigationIndex;

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final TextEditingController _search = TextEditingController();
  late final DocumentRepository _repository;
  List<DocumentRecord> _reports = const [];
  ReportKind? _selectedKind;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? const DemoReportRepository();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final records = await _repository.listDocuments();
      if (!mounted) return;
      setState(() {
        _reports = records.where((record) =>
          record.category == DocumentCategory.reports).toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load reports';
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _selectTab(int index) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _selectedKind =
      index == 0 ? null : ReportKind.values[index - 1]);
  }

  void _navigation(int index) {
    FocusManager.instance.primaryFocus?.unfocus();
    if (widget.onNavigationSelected != null) {
      Navigator.of(context).pop();
      widget.onNavigationSelected!(index);
    } else {
      Navigator.of(context).maybePop();
    }
  }

  Future<void> _editLocalDraft(DocumentRecord? draft, ReportKind kind) async {
    final result = await showModalBottomSheet<DocumentRecord>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ReportDraftEditor(kind: kind, initial: draft),
    );
    if (!mounted || result == null) return;
    DemoReportDraftSession.save(result);
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Report draft saved in the Flutter demo session.'),
      ));
    }
  }

  Future<void> _openSiteWizard(DocumentRecord? existing) async {
    final report = await Navigator.of(context).push<DocumentRecord>(
      MaterialPageRoute<DocumentRecord>(
        builder: (_) => SiteReportWizardScreen(
          initial: existing,
          reportGenerator: widget.reportGenerator,
          selectedNavigationIndex: widget.selectedNavigationIndex,
          onNavigationSelected: _navigation,
        ),
      ),
    );
    if (!mounted || report == null) { return; }
    if (!report.demoOnly) {
      // The connected repository owns real generated reports and statuses.
      await _load();
      if (mounted) {
        await Navigator.of(context).push<void>(MaterialPageRoute<void>(
          builder: (_) => DocumentDetailsScreen(
            documentId: report.id, document: report,
          ),
        ));
      }
      return;
    }
    try {
      DemoReportDraftSession.save(report);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Site report saved as a local draft.'),
        ));
      }
    } on ArgumentError {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Unable to save the site report draft.'),
        ));
      }
    }
  }

  Future<void> _create() async {
    if (widget.onCreateReport != null) {
      widget.onCreateReport!();
      return;
    }
    if (_repository is! DemoReportRepository) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Connect the report creation service before creating reports.'),
      ));
      return;
    }
    final kind = await showModalBottomSheet<ReportKind>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const ListTile(title: Text('Choose report type')),
          ListTile(
            key: const Key('create-site-report'),
            leading: const Icon(Icons.description_outlined),
            title: const Text('Site Report'),
            onTap: () => Navigator.of(sheet).pop(ReportKind.siteReport),
          ),
          ListTile(
            key: const Key('create-work-acceptance'),
            leading: const Icon(Icons.fact_check_outlined),
            title: const Text('Work acceptance'),
            onTap: () => Navigator.of(sheet).pop(ReportKind.workAcceptance),
          ),
        ]),
      ),
    );
    if (kind == ReportKind.siteReport && mounted) {
      await _openSiteWizard(null);
    } else if (kind != null && mounted) {
      await _editLocalDraft(null, kind);
    }
  }

  Future<void> _openReport(DocumentRecord report) async {
    if (widget.onReportTap != null) {
      widget.onReportTap!(report);
      return;
    }
    final editable = _repository is DemoReportRepository
        ? DemoReportDraftSession.find(report.id)
        : null;
    if (editable != null) {
      if (editable.reportKind == ReportKind.siteReport &&
          editable.siteReportDetails != null) {
        await _openSiteWizard(editable);
      } else {
        await _editLocalDraft(editable, editable.reportKind!);
      }
      return;
    }
    await Navigator.of(context).push<void>(MaterialPageRoute<void>(
      builder: (_) => report.reportKind == ReportKind.workAcceptance
          ? WorkAcceptanceScreen(
              report: report,
              selectedNavigationIndex: widget.selectedNavigationIndex,
              onNavigationSelected: _navigation,
            )
          : DocumentDetailsScreen(
              documentId: report.id, document: report,
            ),
    ));
    if (mounted) await _load();
  }

  Widget _list() {
    final visible = _reports.where((record) =>
      (_selectedKind == null || record.reportKind == _selectedKind) &&
      record.matches(_search.text)).toList();

    return CustomScrollView(
      key: const Key('reports-scroll'),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          sliver: SliverToBoxAdapter(child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Sign2DigitalSearchField(
                controller: _search,
                hintText: 'Search documents',
                onChanged: (_) => setState(() {}),
                onTrailingTap: () =>
                  FocusManager.instance.primaryFocus?.unfocus(),
              ),
              const SizedBox(height: 20),
              Stack(children: [
                const Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: Divider(height: 1, thickness: 1,
                    color: AppColors.lightBorder),
                ),
                Sign2DigitalDetailsTabs(
                  labels: const ['All Report', 'Site Report', 'Work acceptance'],
                  selectedIndex: _selectedKind == null
                      ? 0 : _selectedKind!.index + 1,
                  onSelected: _selectTab,
                ),
              ]),
            ],
          )),
        ),
        if (_loading)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator(
              key: Key('reports-loading'))),
          )
        else if (_error != null)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: TextButton(
              key: const Key('reports-retry'),
              onPressed: _load,
              child: Text('$_error. Tap to retry.'),
            )),
          )
        else if (visible.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: Text(
              _search.text.trim().isNotEmpty
                ? 'No reports match your search'
                : _selectedKind == null
                  ? 'No reports yet'
                  : 'No reports in this category',
              key: const Key('reports-empty'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'Inter',
                fontSize: 14, color: AppColors.secondaryText),
            )),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 95),
            sliver: SliverList.builder(
              itemCount: visible.length,
              itemBuilder: (context, index) {
                final report = visible[index];
                return Padding(
                  key: ValueKey(report.id),
                  padding: EdgeInsets.only(
                    bottom: index == visible.length - 1 ? 0 : 20,
                  ),
                  child: Sign2DigitalQuoteSummaryCard(
                    key: Key('report-card-${report.id}'),
                    quoteNumber: report.number,
                    titleOverride: report.title,
                    projectName: report.project,
                    customerName: report.customer,
                    documentDate: report.timestamp,
                    status: report.status,
                    listStyle: true,
                    subtitleGap: 5,
                    onTap: () => _openReport(report),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.white,
    body: SafeArea(
      bottom: false,
      child: Column(children: [
        Sign2DigitalDashboardHeader(
          onNotificationTap: widget.onNotificationTap,
          onProfileTap: widget.onProfileTap,
        ),
        Expanded(child: Center(child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Stack(children: [
            _list(),
            Positioned(
              right: 20, bottom: 20,
              child: SizedBox(
                width: 50, height: 50,
                child: FloatingActionButton(
                  key: const Key('reports-create-button'),
                  heroTag: 'reports-create',
                  elevation: 3,
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.white,
                  onPressed: _create,
                  child: const Icon(Icons.add, size: 30),
                ),
              ),
            ),
          ]),
        ))),
      ]),
    ),
    bottomNavigationBar: Sign2DigitalBottomNavigationBar(
      selectedIndex: widget.selectedNavigationIndex,
      onSelected: _navigation,
    ),
  );
}

/// A functional UI-only draft form, not a fabricated server report.
class _ReportDraftEditor extends StatefulWidget {
  const _ReportDraftEditor({required this.kind, this.initial});
  final ReportKind kind;
  final DocumentRecord? initial;

  @override
  State<_ReportDraftEditor> createState() => _ReportDraftEditorState();
}

class _ReportDraftEditorState extends State<_ReportDraftEditor> {
  late final TextEditingController _title;
  late final TextEditingController _project;
  late final TextEditingController _customer;
  String? _error;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.initial?.title ?? '');
    _project = TextEditingController(text: widget.initial?.project ?? '');
    _customer = TextEditingController(text: widget.initial?.customer ?? '');
  }

  @override
  void dispose() {
    _title.dispose();
    _project.dispose();
    _customer.dispose();
    super.dispose();
  }

  void _save() {
    if (_title.text.trim().isEmpty ||
        _project.text.trim().isEmpty ||
        _customer.text.trim().isEmpty) {
      setState(() => _error = 'Title, job and customer are required.');
      return;
    }
    final id = widget.initial?.id ??
        'local-report-${DateTime.now().microsecondsSinceEpoch}';
    final draft = DocumentRecord(
      id: id,
      category: DocumentCategory.reports,
      reportKind: widget.kind,
      number: widget.initial?.number ?? id,
      title: _title.text.trim(),
      project: _project.text.trim(),
      customer: _customer.text.trim(),
      timestamp: widget.initial?.timestamp ?? DateTime.now(),
      status: 'Draft',
      demoOnly: true,
    );
    Navigator.of(context).pop(draft);
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 650),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.initial == null
                    ? 'Create ${widget.kind.label} Draft'
                    : 'Edit ${widget.kind.label} Draft',
                style: const TextStyle(
                  fontFamily: 'Inter', color: AppColors.dark,
                  fontSize: 18, fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              Sign2DigitalInputField(
                label: 'Report title', hintText: 'e.g. Site Report- Week 3',
                iconAsset: 'assets/icons/description.svg',
                controller: _title,
              ),
              const SizedBox(height: 12),
              Sign2DigitalInputField(
                label: 'Job', hintText: 'e.g. Kitchen renovation',
                iconAsset: 'assets/icons/jobs.svg',
                controller: _project,
              ),
              const SizedBox(height: 12),
              Sign2DigitalInputField(
                label: 'Customer', hintText: 'e.g. Jean dupont',
                iconAsset: 'assets/icons/user.svg',
                controller: _customer,
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, key: const Key('report-draft-validation'),
                  style: const TextStyle(color: Color(0xFFB42318))),
              ],
              const SizedBox(height: 20),
              Sign2DigitalPrimaryButton(
                key: const Key('report-save-draft'),
                label: 'Save Draft', onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
