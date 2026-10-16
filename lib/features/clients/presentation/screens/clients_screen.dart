import 'package:flutter/material.dart';

import '../../../jobs/presentation/screens/jobs_screen.dart';
import '../../../jobs/presentation/screens/job_details_screen.dart';
import '../../../jobs/domain/job_model.dart';
import '../../../jobs/domain/create_job_draft.dart';
import '../../../jobs/data/demo_created_job_repository.dart';
import '../../../jobs/presentation/screens/create_job_screen.dart';
import '../../../home/presentation/screens/home_dashboard_screen.dart';
import '../../../documents/domain/document_record.dart';
import '../../../documents/presentation/screens/generate_ai_document_screen.dart';
import '../../../quotes/presentation/screens/create_quote_screen.dart';
import '../../../invoices/presentation/screens/invoices_screen.dart';
import '../../../expenses/presentation/screens/expenses_screen.dart';
import '../../../expenses/presentation/screens/add_expense_screen.dart';
import '../../../expenses/data/demo_expense_repository.dart';
import '../../../expenses/domain/expense_record.dart';
import '../../../labour/presentation/screens/add_labour_entry_screen.dart';
import '../../../labour/data/demo_labour_repository.dart';
import '../../../labour/domain/labour_entry.dart';
import '../../../reminders/presentation/screens/reminders_screen.dart';
import '../../../documents/presentation/screens/documents_screen.dart';
import '../../../quotes/domain/quote_tracking_home_session.dart';
import '../../../quotes/presentation/screens/signature_request_screen.dart';
import '../../../profile/presentation/screens/profile_settings_screen.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/sign2digital_bottom_navigation_bar.dart';
import '../../../../core/widgets/sign2digital_dashboard_header.dart';
import '../../../../core/widgets/sign2digital_search_field.dart';
import '../../data/client_repository.dart';
import '../../data/demo_client_repository.dart';
import '../../domain/client_profile.dart';
import '../../domain/client_draft.dart';
import 'add_client_screen.dart';
import 'client_details_screen.dart';
import 'import_clients_screen.dart';
import 'more_screen.dart';
import '../widgets/sign2digital_client_card.dart';

/// A temporary UI-only destination after demo Login.
/// Replace this landing route with Home after the Home UI has been completed.
class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key, this.repository, this.initialTab = 2});

  final ClientRepository? repository;
  /// The real login route starts on Home (0). Existing clients-only embed
  /// points keep their original initial tab (2) for backwards compatibility.
  final int initialTab;

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  late int _selectedIndex;
  DocumentCategory? _documentsCategory;
  int _homeRevision = 0;
  int _clientsRevision = 0;
  late final ClientRepository _repository;
  final DemoCreatedJobRepository _createdJobs = DemoCreatedJobRepository();

  JobModel _recordCreatedJob(CreateJobDraft draft) {
    final job = _createdJobs.create(draft);
    setState(() => _homeRevision++);
    return job;
  }

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialTab;
    _repository = widget.repository ?? DemoClientRepository();
  }

  void _showNotReady(String action) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$action is not connected yet. This is a UI preview.'),
      ),
    );
  }

  void _selectDashboardTab(int index, {DocumentCategory? category}) {
    if (!mounted) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _selectedIndex = index;
      if (index == 3) _documentsCategory = category;
      if (index == 0) _homeRevision++;
    });
  }

  void _notifyHome(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openHomeRoute(Widget screen) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => screen));
    if (mounted) setState(() => _homeRevision++);
  }

  Future<void> _createJobFromHome() async {
    final draft = await Navigator.of(context).push<CreateJobDraft>(
      MaterialPageRoute<CreateJobDraft>(
        builder: (_) => CreateJobScreen(clientRepository: _repository),
      ),
    );
    if (!mounted || draft == null) return;
    try {
      final job = _recordCreatedJob(draft);
      await _openJobDetails(job);
    } catch (_) {
      _notifyHome('Unable to create the local job.');
    }
  }

  Future<void> _createClientFromHome() async {
    final draft = await Navigator.of(context).push<ClientDraft>(
      MaterialPageRoute<ClientDraft>(
        builder: (_) => const AddClientScreen(),
      ),
    );
    if (draft == null || !mounted) return;
    try {
      await _repository.createClient(draft);
      if (mounted) setState(() => _clientsRevision++);
      _notifyHome('Client added to the local demo list.');
    } catch (_) {
      _notifyHome('Unable to save the client.');
    }
    if (mounted) setState(() => _homeRevision++);
  }

  Future<void> _createExpenseFromHome() async {
    final draft = await Navigator.of(context).push<ExpenseRecord>(
      MaterialPageRoute<ExpenseRecord>(
        builder: (_) => const AddExpenseScreen(
          selectedNavigationIndex: 0),
      ),
    );
    if (draft == null || !mounted) return;
    try {
      await const DemoExpenseRepository().saveDraft(draft);
      _notifyHome('Expense saved locally for review.');
    } catch (_) {
      _notifyHome('Unable to save the expense draft.');
    }
    if (mounted) setState(() => _homeRevision++);
  }

  Future<void> _createTimeFromHome() async {
    final entry = await Navigator.of(context).push<LabourEntry>(
      MaterialPageRoute<LabourEntry>(
        builder: (_) => AddLabourEntryScreen(
          kind: LabourEntryKind.timeSheet,
          jobs: LabourDemoJobs.all,
          selectedNavigationIndex: 0,
        ),
      ),
    );
    if (entry == null || !mounted) return;
    try {
      await const DemoLabourRepository().save(entry);
      _notifyHome('Time entry saved locally as Pending.');
    } catch (_) {
      _notifyHome('Unable to save the time entry.');
    }
    if (mounted) setState(() => _homeRevision++);
  }

  Future<void> _openSelectedQuoteTracking() async {
    final quote = QuoteTrackingHomeSession.currentQuote;
    if (quote == null) return;
    await _openHomeRoute(SignatureRequestScreen(
      quote: quote,
      selectedTab: 0,
      onNavigationSelected: (index) {
        Navigator.of(context).pop();
        _selectDashboardTab(index);
      },
    ));
  }

  void _onHomeAction(HomeAction action) {
    switch (action) {
      case HomeAction.jobs:
        _selectDashboardTab(1);
      case HomeAction.quotes:
        _selectDashboardTab(3, category: DocumentCategory.quotes);
      case HomeAction.documents:
        _selectDashboardTab(3);
      case HomeAction.invoices:
        _openHomeRoute(InvoicesScreen(
          selectedNavigationIndex: 0,
          onNavigationSelected: _selectDashboardTab,
          onNotificationTap: () => _showNotReady('Notifications'),
        ));
      case HomeAction.reminders:
        _openHomeRoute(RemindersScreen(
          selectedNavigationIndex: 0,
          onNavigationSelected: _selectDashboardTab,
          onNotificationTap: () => _showNotReady('Notifications'),
        ));
      case HomeAction.expenses:
        _openHomeRoute(ExpensesScreen(
          selectedNavigationIndex: 0,
          onNavigationSelected: _selectDashboardTab,
          onNotificationTap: () => _showNotReady('Notifications'),
        ));
      case HomeAction.createQuote:
        _openHomeRoute(const CreateQuoteScreen());
      case HomeAction.newJob:
        _createJobFromHome();
      case HomeAction.addClient:
        _createClientFromHome();
      case HomeAction.createDocument:
        _openHomeRoute(const GenerateAiDocumentScreen());
      case HomeAction.addExpense:
        _createExpenseFromHome();
      case HomeAction.addTime:
        _createTimeFromHome();
      case HomeAction.signatureTracking:
        _openSelectedQuoteTracking();
    }
  }

  Future<void> _openJobDetails(JobModel job) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => JobDetailsScreen(
          job: job,
          onTabSelected: (index) {
            // Nested routes may include Client Details below Job Details.
            // Return to the existing dashboard before switching its tab.
            final dashboardRoute = ModalRoute.of(context);
            if (dashboardRoute != null) {
              Navigator.of(context).popUntil(
                (route) => identical(route, dashboardRoute),
              );
            } else {
              Navigator.of(context).pop();
            }
            _selectDashboardTab(index);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentQuote = QuoteTrackingHomeSession.currentQuote;
    return Scaffold(
      backgroundColor: AppColors.white,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Sign2DigitalDashboardHeader(
              onNotificationTap: () => _showNotReady('Notifications'),
              onProfileTap: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => ProfileSettingsScreen(
                    onNotificationTap: () => _showNotReady('Notifications'),
                    onNavigationSelected: (index) {
                      if (mounted) setState(() => _selectedIndex = index);
                    },
                  ),
                ),
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: _selectedIndex,
                children: [
                  HomeDashboardScreen(
                    selectedQuote: currentQuote,
                    refreshRevision: _homeRevision,
                    additionalActiveJobs: _createdJobs.jobs.length,
                    onAction: _onHomeAction,
                  ),
                  JobsScreen(
                    createdJobs: _createdJobs.jobs,
                    onCreateJob: _createJobFromHome,
                    onNotReady: _showNotReady,
                    onJobTap: _openJobDetails,
                  ),
                  _ClientsContent(
                    key: ValueKey('clients-content-$_clientsRevision'),
                    repository: _repository,
                    createdJobsForClient: _createdJobs.forClient,
                    onJobCreated: _recordCreatedJob,
                    onOpenJob: _openJobDetails,
                    showNotReady: _showNotReady,
                    onTabSelected: (index) =>
                        setState(() => _selectedIndex = index),
                  ),
                  DocumentsScreen(initialCategory: _documentsCategory),
                  MoreScreen(
                    onTabSelected: (index) {
                      if (mounted) setState(() => _selectedIndex = index);
                    },
                    onNotReady: _showNotReady,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Sign2DigitalBottomNavigationBar(
        selectedIndex: _selectedIndex,
        onSelected: _selectDashboardTab,
      ),
    );
  }
}

class _ClientsContent extends StatefulWidget {
  const _ClientsContent({
    super.key,
    required this.repository,
    required this.showNotReady,
    required this.onTabSelected,
    required this.createdJobsForClient,
    required this.onJobCreated,
    required this.onOpenJob,
  });

  final ClientRepository repository;
  final ValueChanged<String> showNotReady;
  final ValueChanged<int> onTabSelected;
  final List<JobModel> Function(String clientId) createdJobsForClient;
  final JobModel Function(CreateJobDraft draft) onJobCreated;
  final Future<void> Function(JobModel) onOpenJob;

  @override
  State<_ClientsContent> createState() => _ClientsContentState();
}

class _ClientsContentState extends State<_ClientsContent> {
  final _search = TextEditingController();
  List<ClientProfile> _clients = [];
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  Future<void> _loadClients() async {
    try {
      final clients = await widget.repository.listClients();
      if (!mounted) return;
      setState(() {
        _clients = clients;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Unable to load clients';
      });
    }
  }

  Future<void> _openImportClients() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final tabIndex = await Navigator.of(
      context,
    ).push<int>(MaterialPageRoute<int>(builder: (_) => ImportClientsScreen()));
    if (tabIndex != null && mounted) {
      widget.onTabSelected(tabIndex);
    }
  }

  Future<void> _openAddClient() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final draft = await Navigator.of(context).push<ClientDraft>(
      MaterialPageRoute<ClientDraft>(builder: (_) => AddClientScreen()),
    );
    if (draft == null || !mounted) return;
    try {
      await widget.repository.createClient(draft);
      if (!mounted) return;
      _search.clear();
      await _loadClients();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Client added to the local demo list')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to add the client to the demo list')),
      );
    }
  }

  Future<void> _openClientDetails(ClientProfile client) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ClientDetailsScreen(
          client: client,
          repository: widget.repository,
          createdJobsForClient: widget.createdJobsForClient,
          onJobCreated: widget.onJobCreated,
          onOpenJob: widget.onOpenJob,
          onViewAllJobs: (_) {
            Navigator.of(context).pop();
            widget.onTabSelected(1);
          },
        ),
      ),
    );
    if (!mounted) {
      return;
    }
    // Reload after editing without discarding the current search query.
    await _loadClients();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final matches = _clients
        .where((item) => item.matches(_search.text))
        .toList();
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: CustomScrollView(
          key: const Key('clients-scroll'),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Sign2DigitalSearchField(
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                      onTrailingTap: () {
                        FocusManager.instance.primaryFocus?.unfocus();
                      },
                    ),
                    const SizedBox(height: 20),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final narrow = constraints.maxWidth < 330;
                        final importButton = _ClientsActionButton(
                          label: 'Import from Contacts',
                          outlined: true,
                          onTap: _openImportClients,
                        );
                        final addButton = _ClientsActionButton(
                          label: 'Add Client Manually',
                          outlined: false,
                          onTap: _openAddClient,
                        );
                        if (narrow) {
                          return Column(
                            children: [
                              importButton,
                              const SizedBox(height: 12),
                              addButton,
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(child: importButton),
                            const SizedBox(width: 16),
                            Expanded(child: addButton),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            if (_loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: TextButton(
                    onPressed: () {
                      setState(() => _loading = true);
                      _loadClients();
                    },
                    child: Text('$_error. Tap to retry.'),
                  ),
                ),
              )
            else if (matches.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _search.text.isEmpty
                          ? 'No clients yet'
                          : 'No clients match your search',
                      style: AppTextStyles.subtitle,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                sliver: SliverList.builder(
                  itemCount: matches.length,
                  itemBuilder: (context, index) => Padding(
                    key: ValueKey(matches[index].id),
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Sign2DigitalClientCard(
                      client: widget.createdJobsForClient(matches[index].id).isEmpty
                          ? matches[index]
                          : matches[index].withJobCount(
                              matches[index].jobCount +
                                  widget.createdJobsForClient(matches[index].id).length,
                            ),
                      onTap: () => _openClientDetails(matches[index]),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ClientsActionButton extends StatelessWidget {
  const _ClientsActionButton({
    required this.label,
    required this.onTap,
    required this.outlined,
  });

  final String label;
  final VoidCallback onTap;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final style = outlined
        ? OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 13),
          )
        : FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 13),
          );
    final child = Center(
      child: Text(
        label,
        maxLines: 2,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: outlined
          ? OutlinedButton(onPressed: onTap, style: style, child: child)
          : FilledButton(onPressed: onTap, style: style, child: child),
    );
  }
}
