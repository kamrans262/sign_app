import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/dashboard_colors.dart';
import '../../../../core/widgets/sign2digital_selection_sheet.dart';
import '../../../company/data/company_repository.dart';
import '../../../company/data/demo_company_repository.dart';
import '../../../company/data/remote_company_repository.dart';
import '../../../auth/data/mobile_auth_repository.dart';
import '../../../../core/services/active_company_session.dart';
import '../../../../core/services/sign_api_client.dart';
import '../../../company/domain/company_profile.dart';
import '../../../documents/data/demo_document_repository.dart';
import '../../../documents/domain/document_record.dart';
import '../../../expenses/data/demo_expense_repository.dart';
import '../../../expenses/domain/expense_record.dart';
import '../../../invoices/data/demo_invoice_repository.dart';
import '../../../invoices/domain/invoice_record.dart';
import '../../../jobs/data/mock_jobs.dart';
import '../../../jobs/domain/job_model.dart';
import '../../../quotes/domain/quote_review_models.dart';
import '../../../quotes/presentation/widgets/sign2digital_quote_shadow_panel.dart';
import '../../../reminders/data/demo_reminder_repository.dart';
import '../../../reminders/domain/reminder_record.dart';

/// Dashboard actions are handled by the existing authenticated shell.
enum HomeAction {
  jobs, quotes, invoices, documents, reminders, expenses,
  createQuote, newJob, addClient, createDocument, addExpense, addTime,
  signatureTracking,
}

/// Genuine repository results, not hardcoded visual dashboard metrics.
/// Most current repositories hold explicitly labelled sample/session data.
class HomeOverview {
  const HomeOverview({
    required this.activeJobs,
    this.pendingQuotes,
    this.outstandingInvoices,
    this.recentDocuments,
    this.upcomingReminders,
    this.jobExpensesChf,
  });

  final int activeJobs;
  final int? pendingQuotes;
  final int? outstandingInvoices;
  final int? recentDocuments;
  final int? upcomingReminders;
  final double? jobExpensesChf;

  static int countPendingQuotes(List<DocumentRecord> documents) =>
      documents.where((item) =>
          item.category == DocumentCategory.quotes &&
          !const ['signed', 'approved', 'accepted', 'declined', 'rejected',
            'cancelled'].contains(item.status.toLowerCase())).length;

  static int countOutstanding(List<InvoiceRecord> invoices) =>
      invoices.where((item) => const [
        InvoiceStatus.sent, InvoiceStatus.pending, InvoiceStatus.overdue,
      ].contains(item.status)).length;

  static int countRecent(List<DocumentRecord> documents, DateTime now) {
    final cutoff = now.subtract(const Duration(days: 30));
    return documents.where((item) =>
      !item.timestamp.isBefore(cutoff) && !item.timestamp.isAfter(now)).length;
  }

  static int countUpcoming(List<ReminderRecord> reminders, DateTime now) =>
      reminders.where((item) =>
        !item.completed && !item.remindAt.isBefore(now)).length;

  static double totalExpenses(List<ExpenseRecord> expenses) =>
      expenses.where((item) => item.job.trim().isNotEmpty)
          .fold<double>(0, (sum, item) => sum + item.amount);
}

/// The Home tab's content. The shell owns the global logo/notification/profile
/// header and the fixed navigation; this widget adds the company switcher.
class HomeDashboardScreen extends StatefulWidget {
  const HomeDashboardScreen({
    super.key,
    required this.onAction,
    this.selectedQuote,
    this.companyRepository,
    this.documentRepository = const DemoDocumentRepository(),
    this.invoiceRepository = const DemoInvoiceRepository(),
    this.reminderRepository = const DemoReminderRepository(),
    this.expenseRepository = const DemoExpenseRepository(),
    this.refreshRevision = 0,
    this.additionalActiveJobs = 0,
    this.onCompanySelected,
  });

  final ValueChanged<HomeAction> onAction;
  final QuoteReviewDraft? selectedQuote;
  final CompanyRepository? companyRepository;
  final DocumentRepository documentRepository;
  final InvoiceRepository invoiceRepository;
  final ReminderRepository reminderRepository;
  final ExpenseRepository expenseRepository;
  final int refreshRevision;
  final int additionalActiveJobs;
  /// Reports the actual selected demo company to the authenticated shell.
  final ValueChanged<String?>? onCompanySelected;

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  // Home-only section titles match the existing Subscription section style.
  // This must not change label/value typography inside cards.
  static const TextStyle _sectionHeadingStyle = TextStyle(
    fontFamily: 'Inter',
    fontSize: 20,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    color: AppColors.dark,
  );

  HomeOverview? _overview;
  List<CompanyProfile> _companies = const [];
  String? _companyId;
  bool _loading = true;
  int _reloadVersion = 0;

  CompanyRepository get _companyRepo => widget.companyRepository ??
      (MobileAuthRepository.shared.isSignedIn
          ? RemoteCompanyRepository.shared : DemoCompanyRepository.shared);

  CompanyProfile? get _company {
    for (final company in _companies) {
      if (company.id == _companyId) return company;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didUpdateWidget(covariant HomeDashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshRevision != widget.refreshRevision ||
        oldWidget.documentRepository != widget.documentRepository ||
        oldWidget.invoiceRepository != widget.invoiceRepository ||
        oldWidget.reminderRepository != widget.reminderRepository ||
        oldWidget.expenseRepository != widget.expenseRepository ||
        oldWidget.companyRepository != widget.companyRepository) {
      _reload();
    }
  }

  Future<void> _reload() async {
    final version = ++_reloadVersion;
    if (mounted) setState(() => _loading = true);
    // A temporary network failure must never discard the last verified
    // company list or silently select an unrelated tenant.
    List<CompanyProfile> companies = _companies;
    bool loadedCompanies = false;
    int? quotes, invoices, documents, reminders;
    double? expenses;
    try {
      companies = await _companyRepo.list();
      loadedCompanies = true;
    } catch (_) {
      if (mounted && MobileAuthRepository.shared.isSignedIn &&
          widget.companyRepository == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Unable to refresh companies. Check your connection and retry.'),
        ));
      }
    }
    try {
      final records = await widget.documentRepository.listDocuments();
      quotes = HomeOverview.countPendingQuotes(records);
      documents = HomeOverview.countRecent(records, DateTime.now());
    } catch (_) {}
    try {
      invoices = HomeOverview.countOutstanding(
        await widget.invoiceRepository.listInvoices());
    } catch (_) {}
    try {
      reminders = HomeOverview.countUpcoming(
        await widget.reminderRepository.listReminders(), DateTime.now());
    } catch (_) {}
    try {
      expenses = HomeOverview.totalExpenses(
        await widget.expenseRepository.listExpenses());
    } catch (_) {}
    if (MobileAuthRepository.shared.isSignedIn &&
        widget.companyRepository == null && loadedCompanies &&
        companies.isNotEmpty && ActiveCompanySession.companyId == null) {
      try {
        await RemoteCompanyRepository.shared.switchTo(companies.first.id);
      } catch (_) {
        // Company-scoped APIs still require server-approved context.
      }
    }
    if (!mounted || version != _reloadVersion) return;
    setState(() {
      _companies = companies;
      if (MobileAuthRepository.shared.isSignedIn &&
          widget.companyRepository == null) {
        final active = ActiveCompanySession.companyId?.toString();
        // Do not display a "selected" tenant without a successful server
        // switch. A server-side revocation makes the old selection invalid.
        _companyId = companies.any((item) => item.id == active)
            ? active : null;
      } else if (!companies.any((item) => item.id == _companyId)) {
        _companyId = null;
        for (final item in companies) {
          if (item.id == 'demo-current-company') {
            _companyId = item.id;
            break;
          }
        }
        _companyId ??= companies.isEmpty ? null : companies.first.id;
      }
      _overview = HomeOverview(
        activeJobs: MockJobsData.count(JobCategory.active),
        pendingQuotes: quotes,
        outstandingInvoices: invoices,
        recentDocuments: documents,
        upcomingReminders: reminders,
        jobExpensesChf: expenses,
      );
      _loading = false;
    });
    if (loadedCompanies) widget.onCompanySelected?.call(_companyId);
  }

  Future<void> _switchCompany() async {
    final companies = _companies;
    if (companies.isEmpty) return;
    final names = [
      for (final company in companies)
        companies.where((item) => item.companyName == company.companyName).length > 1
            ? '${company.companyName} (#${company.id})'
            : company.companyName,
    ];
    final selectedIndex = companies.indexWhere((item) => item.id == _companyId);
    final selected = await Sign2DigitalSelectionSheet.show(
      context,
      title: 'Switch company',
      options: names,
      selected: selectedIndex < 0 ? null : names[selectedIndex],
      icon: Icons.business_outlined,
    );
    if (selected == null || !mounted) return;
    final index = names.indexOf(selected);
    if (index < 0) return;
    final next = companies[index].id;
    if (next == _companyId) return;
    if (MobileAuthRepository.shared.isSignedIn &&
        widget.companyRepository == null) {
      try {
        await RemoteCompanyRepository.shared.switchTo(next);
      } catch (error) {
        if (!mounted) return;
        final message = error is SignApiException
            ? error.message : 'Unable to switch companies.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
        return;
      }
    }
    if (!mounted) return;
    // An earlier in-flight refresh must not undo this verified switch.
    ++_reloadVersion;
    setState(() {
      _companyId = next;
      _loading = false;
    });
    widget.onCompanySelected?.call(next);
  }

  String _count(int? value) =>
      _loading ? '…' : (value?.toString() ?? '—');

  String _expensesText(double? value) =>
      _loading ? '…' :
      value == null ? '—' : 'CHF ${value.toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    final value = _overview;
    final company = _company;
    final cards = [
      _HomeMetric('Active Jobs',
          value == null ? '…' : '${value.activeJobs + widget.additionalActiveJobs}',
          'Open jobs',
          Icons.work_outline_rounded, HomeAction.jobs, 'jobs'),
      _HomeMetric('Pending Quotes',
          _count(value?.pendingQuotes), 'Awaiting action',
          Icons.request_quote_outlined, HomeAction.quotes, 'quotes'),
      _HomeMetric('Outstanding Invoices',
          _count(value?.outstandingInvoices), 'Awaiting payment',
          Icons.receipt_long_outlined, HomeAction.invoices, 'invoices'),
      _HomeMetric('Recent Documents',
          _count(value?.recentDocuments), 'Last 30 days',
          Icons.description_outlined, HomeAction.documents, 'documents'),
      _HomeMetric('Upcoming Reminders',
          _count(value?.upcomingReminders), 'Not completed',
          Icons.notifications_active_outlined, HomeAction.reminders,
          'reminders'),
      _HomeMetric('Job Expenses',
          _expensesText(value?.jobExpensesChf), 'Recorded expenses',
          Icons.account_balance_wallet_outlined, HomeAction.expenses,
          'expenses'),
    ];
    final actions = [
      _HomeShortcut('Create Quote', Icons.note_add_outlined,
          HomeAction.createQuote, 'create-quote'),
      _HomeShortcut('New Job', Icons.add_business_outlined,
          HomeAction.newJob, 'new-job'),
      _HomeShortcut('Add Client', Icons.person_add_alt_1_outlined,
          HomeAction.addClient, 'add-client'),
      _HomeShortcut('Create Document', Icons.post_add_outlined,
          HomeAction.createDocument, 'create-document'),
      _HomeShortcut('Add Expense', Icons.receipt_outlined,
          HomeAction.addExpense, 'add-expense'),
      _HomeShortcut('Add Time', Icons.schedule_outlined,
          HomeAction.addTime, 'add-time'),
    ];

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth:
            MediaQuery.orientationOf(context) == Orientation.landscape
                ? double.infinity : 720),
        child: RefreshIndicator(
          onRefresh: _reload,
          child: ListView(
            key: const Key('home-dashboard-scroll'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 25),
            children: [
              _HomePanel(
                clip: true,
                child: Material(
                  color: AppColors.white,
                  child: InkWell(
                    key: const Key('home-company-switcher'),
                    onTap: _switchCompany,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 15),
                      child: Row(children: [
                        CircleAvatar(
                          radius: 23,
                          backgroundColor: DashboardColors.paleBlue,
                          child: Text(
                            company == null ? 'CO' :
                              company.companyName.trim().split(
                                RegExp(r'\s+')).where((part) =>
                                part.isNotEmpty).take(2).map((part) =>
                                part[0].toUpperCase()).join(),
                            style: const TextStyle(
                              fontFamily: 'Inter', fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('CURRENT COMPANY',
                              style: TextStyle(
                                fontFamily: 'Inter', fontSize: 10,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                                color: AppColors.placeholder)),
                            const SizedBox(height: 5),
                            Text(
                              company?.companyName ?? 'No company selected',
                              key: const Key('home-company-name'),
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.fieldLabel,
                            ),
                          ],
                        )),
                        const SizedBox(width: 8),
                        const Icon(Icons.keyboard_arrow_down_rounded,
                          color: AppColors.primary, size: 24),
                      ]),
                    ),
                  ),
                ),
              ),
              // Company container → Overview heading: 20px.
              const SizedBox(height: 20),
              Row(children: [
                const Expanded(
                  child: Text('Overview', style: _sectionHeadingStyle),
                ),
                IconButton(
                  key: const Key('home-refresh'),
                  tooltip: 'Refresh dashboard',
                  onPressed: _reload,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 24, height: 24),
                  icon: const Icon(Icons.refresh_rounded,
                    color: AppColors.primary, size: 22),
                ),
              ]),
              // Heading → overview cards: 10px.
              const SizedBox(height: 10),
              LayoutBuilder(builder: (context, constraints) {
                final columns = constraints.maxWidth >= 600 ? 3 : 2;
                const space = 15.0;
                final width = (constraints.maxWidth -
                    space * (columns - 1)) / columns;
                return Wrap(
                  spacing: space, runSpacing: 15,
                  children: [
                    for (final item in cards)
                      SizedBox(
                        width: width,
                        child: _MetricCard(
                          key: Key('home-card-${item.id}'),
                          item: item,
                          onTap: () => widget.onAction(item.action),
                        ),
                      ),
                  ],
                );
              }),
              // Overview cards → next section: 20px.
              const SizedBox(height: 20),
              const Text('Quick Actions', style: _sectionHeadingStyle),
              // Heading → quick-action cards: 10px.
              const SizedBox(height: 10),
              LayoutBuilder(builder: (context, constraints) {
                final columns = constraints.maxWidth >= 600 ? 3 : 2;
                const space = 15.0;
                final width = (constraints.maxWidth -
                    space * (columns - 1)) / columns;
                return Wrap(
                  spacing: space, runSpacing: 15,
                  children: [
                    for (final item in actions)
                      SizedBox(
                        width: width,
                        child: _QuickActionCard(
                          key: Key('home-action-${item.id}'),
                          item: item,
                          onTap: () => widget.onAction(item.action),
                        ),
                      ),
                  ],
                );
              }),
              if (widget.selectedQuote != null) ...[
                // Continue the same rhythm for any following sections.
                const SizedBox(height: 20),
                const Text('Signature Tracking',
                  style: _sectionHeadingStyle),
                const SizedBox(height: 10),
                _HomePanel(
                  padding: const EdgeInsets.all(15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.selectedQuote!.quoteNumber.isNotEmpty
                        ? widget.selectedQuote!.quoteNumber
                        : 'Selected quote', style: AppTextStyles.fieldLabel),
                      const SizedBox(height: 10),
                      const Text(
                        'Track the quote selected in this session.',
                        style: AppTextStyles.subtitle),
                      const SizedBox(height: 10),
                      TextButton.icon(
                        key: const Key('home-open-signature-tracking'),
                        onPressed: () => widget.onAction(
                          HomeAction.signatureTracking),
                        icon: const Icon(Icons.arrow_forward_rounded),
                        label: const Text('View tracking'),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Home-only softened version of the existing light-border shadow panel.
/// The shared component keeps its original blur on other screens.
class _HomePanel extends StatelessWidget {
  const _HomePanel({
    required this.child,
    this.padding = EdgeInsets.zero,
    this.clip = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool clip;

  @override
  Widget build(BuildContext context) => Container(
    clipBehavior: clip ? Clip.antiAlias : Clip.none,
    decoration: Sign2DigitalQuoteShadowPanel.decoration.copyWith(
      boxShadow: const [
        BoxShadow(
          color: Color(0x1A000000),
          offset: Offset(0, 4),
          blurRadius: 10,
        ),
      ],
    ),
    padding: padding,
    child: child,
  );
}

class _HomeMetric {
  const _HomeMetric(this.title, this.value, this.hint,
      this.icon, this.action, this.id);
  final String title, value, hint, id;
  final IconData icon;
  final HomeAction action;
}

class _HomeShortcut {
  const _HomeShortcut(this.title, this.icon, this.action, this.id);
  final String title, id;
  final IconData icon;
  final HomeAction action;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({super.key, required this.item, required this.onTap});
  final _HomeMetric item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => _HomePanel(
    clip: true,
    child: Material(
      color: AppColors.white,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: DashboardColors.paleBlue,
                    borderRadius: BorderRadius.circular(10)),
                  child: Icon(item.icon, color: AppColors.primary, size: 22),
                ),
                const Spacer(),
                const Icon(Icons.arrow_outward_rounded,
                  color: AppColors.placeholder, size: 18),
              ]),
              const SizedBox(height: 16),
              Text(item.value, maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Inter', fontSize: 21,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3, color: AppColors.dark)),
              const SizedBox(height: 8),
              Text(item.title, maxLines: 2,
                style: const TextStyle(
                  fontFamily: 'Inter', fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.dark)),
              const SizedBox(height: 5),
              Text(item.hint, maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Inter', fontSize: 11,
                  color: AppColors.placeholder)),
            ],
          ),
        ),
      ),
    ),
  );
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({super.key, required this.item, required this.onTap});
  final _HomeShortcut item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => _HomePanel(
    clip: true,
    child: Material(
      color: AppColors.white,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 18),
          child: Row(children: [
            Container(
              height: 34, width: 34,
              decoration: BoxDecoration(
                color: DashboardColors.paleBlue,
                borderRadius: BorderRadius.circular(9)),
              child: Icon(item.icon, size: 20, color: AppColors.primary),
            ),
            const SizedBox(width: 9),
            Expanded(child: Text(item.title,
              maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontFamily: 'Inter', fontSize: 12,
                fontWeight: FontWeight.w600, color: AppColors.dark))),
          ]),
        ),
      ),
    ),
  );
}
