import 'package:flutter/material.dart';

import '../../../jobs/presentation/screens/jobs_screen.dart';
import '../../../jobs/presentation/screens/job_details_screen.dart';
import '../../../jobs/domain/job_model.dart';
import '../../../jobs/domain/create_job_draft.dart';
import '../../../jobs/data/demo_created_job_repository.dart';
import '../../../jobs/data/remote_job_repository.dart';
import '../../../jobs/domain/job_details_model.dart';
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
import '../../../reminders/presentation/screens/notification_inbox_screen.dart';
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
import '../../data/remote_client_repository.dart';
import '../../../auth/data/mobile_auth_repository.dart';
import '../../../../core/services/active_company_session.dart';
import '../../../../core/services/sign_api_client.dart';
import '../../../../core/navigation/sign2digital_navigation.dart';
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
  const ClientsScreen({super.key, this.repository,
    this.documentRepository, this.initialTab = 2});

  final ClientRepository? repository;
  /// Optional injected catalog for deterministic UI tests and embedded flows.
  /// Production retains the existing automatically selected repository.
  final DocumentRepository? documentRepository;
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
  int _documentsRevision = 0;
  String? _selectedCompanyId;
  NavigatorState? _dashboardNavigator;
  Route<dynamic>? _dashboardRoute;

  void _selectCompany(String? companyId) {
    if (!mounted || _selectedCompanyId == companyId) return;
    setState(() {
      _selectedCompanyId = companyId;
      // The selected company is the client-data isolation boundary.
      // Discard old list state and reload from the newly selected tenant.
      _clientsRevision++;
      _remoteJobs = const [];
      _jobsError = null;
      _jobsLoading = _usesRemoteJobs;
    });
    _loadJobs();
  }
  late final ClientRepository _repository;
  final DemoCreatedJobRepository _createdJobs = DemoCreatedJobRepository();

  List<JobModel> _remoteJobs = const [];
  String? _jobsError;
  bool _jobsLoading = false;
  int _jobFetchVersion = 0;

  bool get _usesRemoteJobs => _repository is RemoteClientRepository;
  List<JobModel> get _dashboardJobs =>
      _usesRemoteJobs ? _remoteJobs : _createdJobs.jobs;

  List<JobModel> _jobsForClient(String clientId) =>
      List<JobModel>.unmodifiable(
        _dashboardJobs.where((job) => job.clientId == clientId),
      );

  Future<void> _loadJobs() async {
    if (!_usesRemoteJobs || !mounted) return;
    final version = ++_jobFetchVersion;
    final companyId = ActiveCompanySession.companyId;
    setState(() {
      _jobsLoading = true;
      _jobsError = null;
    });
    try {
      final jobs = await RemoteJobRepository.shared.listJobs();
      if (!mounted || version != _jobFetchVersion ||
          ActiveCompanySession.companyId != companyId) {
        return;
      }
      setState(() {
        _remoteJobs = jobs;
        _jobsLoading = false;
        _jobsError = null;
        _homeRevision++;
        _clientsRevision++;
      });
    } catch (error) {
      if (!mounted || version != _jobFetchVersion ||
          ActiveCompanySession.companyId != companyId) {
        return;
      }
      setState(() {
        // Never keep another company's jobs on a failed tenant refresh.
        _remoteJobs = const [];
        _jobsLoading = false;
        _jobsError = error is SignApiException
            ? error.message : 'Unable to load your jobs.';
      });
    }
  }

  Future<JobModel> _recordCreatedJob(CreateJobDraft draft) async {
    if (_usesRemoteJobs) {
      final job = await RemoteJobRepository.shared.createJob(draft);
      await _loadJobs();
      if (mounted) setState(() => _homeRevision++);
      return job;
    }
    final job = _createdJobs.create(draft);
    if (mounted) setState(() => _homeRevision++);
    return job;
  }

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialTab;
    _selectedCompanyId = ActiveCompanySession.companyId?.toString();
    _repository = widget.repository ??
        (MobileAuthRepository.shared.isSignedIn
          ? RemoteClientRepository.shared
          : DemoClientRepository());
    if (_usesRemoteJobs) _loadJobs();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final navigator = Navigator.of(context);
    final route = ModalRoute.of(context);
    if (route == null) return;
    if (_dashboardNavigator != null && _dashboardRoute != null &&
        (!identical(_dashboardNavigator, navigator) ||
            !identical(_dashboardRoute, route))) {
      Sign2DigitalNavigation.detachDashboard(
        _dashboardNavigator!, _dashboardRoute!);
    }
    _dashboardNavigator = navigator;
    _dashboardRoute = route;
    Sign2DigitalNavigation.attachDashboard(
      navigator: navigator,
      route: route,
      selectTab: _selectDashboardTab,
    );
  }

  @override
  void dispose() {
    if (_dashboardNavigator != null && _dashboardRoute != null) {
      Sign2DigitalNavigation.detachDashboard(
        _dashboardNavigator!, _dashboardRoute!);
    }
    super.dispose();
  }

  void _openNotifications() {
    Sign2DigitalNavigation.push<void>(context,
      MaterialPageRoute<void>(builder: (_) => const NotificationInboxScreen()),
    );
  }

  void _showNotReady(String action) {
    if (action == 'Notifications') {
      _openNotifications();
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$action is not connected yet. This is a UI preview.'),
      ),
    );
  }

  void _selectDashboardTab(int index, {DocumentCategory? category}) {
    if (!mounted || index < 0 || index > 4) return;
    // An already selected tab has no new route or expensive refresh.
    if (_selectedIndex == index &&
        (index != 3 || category == null || category == _documentsCategory)) {
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _selectedIndex = index;
      if (index == 3) {
        _documentsCategory = category;
        _documentsRevision++;
      }
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
    await Sign2DigitalNavigation.open<void>(context, screen);
    if (mounted) setState(() => _homeRevision++);
  }

  Future<void> _createJobFromHome() async {
    final draft = await Sign2DigitalNavigation.open<CreateJobDraft>(
      context, CreateJobScreen(clientRepository: _repository));
    if (!mounted || draft == null) return;
    try {
      final job = await _recordCreatedJob(draft);
      await _openJobDetails(job);
    } catch (error) {
      _notifyHome(error is SignApiException
          ? error.message : 'Unable to create the job.');
    }
  }

  Future<void> _createClientFromHome() async {
    final draft = await Sign2DigitalNavigation.open<ClientDraft>(
      context, const AddClientScreen());
    if (draft == null || !mounted) return;
    try {
      await _repository.createClient(draft);
      if (mounted) setState(() => _clientsRevision++);
      _notifyHome(_repository is RemoteClientRepository
          ? 'Client saved to your company.' : 'Client added to the local demo list.');
    } catch (_) {
      _notifyHome('Unable to save the client.');
    }
    if (mounted) setState(() => _homeRevision++);
  }

  Future<void> _createExpenseFromHome() async {
    final draft = await Sign2DigitalNavigation.open<ExpenseRecord>(
      context, const AddExpenseScreen(selectedNavigationIndex: 0));
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
    final entry = await Sign2DigitalNavigation.open<LabourEntry>(
      context,
      AddLabourEntryScreen(
        kind: LabourEntryKind.timeSheet,
        jobs: LabourDemoJobs.all,
        selectedNavigationIndex: 0,
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
      tracking: QuoteTrackingHomeSession.trackingFor(quote.id),
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
          onNotificationTap: _openNotifications,
        ));
      case HomeAction.reminders:
        _openHomeRoute(RemindersScreen(
          selectedNavigationIndex: 0,
          onNavigationSelected: _selectDashboardTab,
          onNotificationTap: _openNotifications,
        ));
      case HomeAction.expenses:
        _openHomeRoute(ExpensesScreen(
          selectedNavigationIndex: 0,
          onNavigationSelected: _selectDashboardTab,
          onNotificationTap: _openNotifications,
        ));
      case HomeAction.createQuote:
        _openHomeRoute(CreateQuoteScreen(companyId: _selectedCompanyId));
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

  Future<bool> _manageJobAction(JobModel job, String action) async {
    if (!_usesRemoteJobs) return false;
    final jobId = int.tryParse(job.id);
    if (jobId == null || jobId <= 0) return false;
    try {
      final jobs = RemoteJobRepository.shared;
      switch (action) {
        case 'Edit Job':
          ClientProfile? linkedClient;
          for (final client in await _repository.listClients()) {
            if (client.id == job.clientId) {
              linkedClient = client;
              break;
            }
          }
          if (!mounted) return false;
          final draft = await Sign2DigitalNavigation.push<CreateJobDraft>(context,
            MaterialPageRoute<CreateJobDraft>(
              builder: (_) => CreateJobScreen(
                clientRepository: _repository,
                initialClient: linkedClient,
                initialJob: job,
              ),
            ),
          );
          if (draft == null) return false;
          await jobs.updateDraft(job, draft);
        case 'Start Job':
          await jobs.updateJob(jobId, {'stage': 'in_progress'});
        case 'Set to Planning':
          await jobs.updateJob(jobId, {'stage': 'planning'});
        case 'Mark Completed':
          await jobs.updateJob(jobId, {'stage': 'completed'});
        case 'Reopen Job':
          await jobs.updateJob(jobId, {
            'stage': 'in_progress',
            'progress_percentage': job.progressPercentage >= 100
                ? 0 : job.progressPercentage,
          });
        case 'Archive Job':
          await jobs.archiveJob(jobId);
        case 'Restore Job':
          await jobs.restoreJob(jobId);
        default:
          return false;
      }
      if (!mounted) return false;
      await _loadJobs();
      _notifyHome('Job updated successfully.');
      return true;
    } catch (error) {
      _notifyHome(error is SignApiException
          ? error.message : 'Unable to update this job.');
      return false;
    }
  }

  Future<void> _openJobDetails(JobModel job) async {
    FocusManager.instance.primaryFocus?.unfocus();
    ClientProfile? linkedClient;
    try {
      final clients = await _repository.listClients();
      for (final candidate in clients) {
        if (candidate.id == job.clientId) {
          linkedClient = candidate;
          break;
        }
      }
    } catch (_) {
      // A missing contact must not prevent access to the job itself.
    }
    if (!mounted) return;
    JobDetailsModel? realDetails;
    if (_usesRemoteJobs) {
      try {
        realDetails = await RemoteJobRepository.shared.loadDetails(job);
      } catch (error) {
        _notifyHome(error is SignApiException
            ? error.message : 'Unable to open the job.');
        return;
      }
      if (!mounted) return;
    }
    await Sign2DigitalNavigation.open<void>(
      context,
      JobDetailsScreen(
          job: realDetails?.job ?? job,
          details: realDetails,
          onManageJob: _usesRemoteJobs ? _manageJobAction : null,
          companyId: _selectedCompanyId,
          client: linkedClient,
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
      destination: 'job-details:${job.id}',
    );
    if (mounted && _usesRemoteJobs) await _loadJobs();
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
              onNotificationTap: _openNotifications,
              onProfileTap: () => Sign2DigitalNavigation.push<void>(context,
                MaterialPageRoute<void>(
                  builder: (_) => ProfileSettingsScreen(
                    onNotificationTap: _openNotifications,
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
                    includeDemoJobs: !_usesRemoteJobs,
                    additionalActiveJobs: _dashboardJobs.where(
                      (job) => job.category == JobCategory.active,
                    ).length,
                    onCompanySelected: _selectCompany,
                    onAction: _onHomeAction,
                  ),
                  JobsScreen(
                    createdJobs: _dashboardJobs,
                    includeDemoJobs: !_usesRemoteJobs,
                    loading: _usesRemoteJobs && _jobsLoading,
                    errorMessage: _usesRemoteJobs ? _jobsError : null,
                    onRetry: _loadJobs,
                    onCreateJob: _createJobFromHome,
                    onNotReady: _showNotReady,
                    onJobTap: _openJobDetails,
                  ),
                  _ClientsContent(
                    key: ValueKey('clients-content-$_clientsRevision'),
                    repository: _repository,
                    createdJobsForClient: _jobsForClient,
                    onJobCreated: _recordCreatedJob,
                    onOpenJob: _openJobDetails,
                    companyId: _selectedCompanyId,
                    showNotReady: _showNotReady,
                    onTabSelected: (index) =>
                        setState(() => _selectedIndex = index),
                  ),
                  DocumentsScreen(
                    repository: widget.documentRepository,
                    initialCategory: _documentsCategory,
                    refreshRevision: _documentsRevision,
                  ),
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
    this.companyId,
  });

  final ClientRepository repository;
  final ValueChanged<String> showNotReady;
  final ValueChanged<int> onTabSelected;
  final List<JobModel> Function(String clientId) createdJobsForClient;
  final Future<JobModel> Function(CreateJobDraft draft) onJobCreated;
  final Future<void> Function(JobModel) onOpenJob;
  final String? companyId;

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
    final tabIndex = await Sign2DigitalNavigation.open<int>(
      context, ImportClientsScreen());
    if (!mounted) return;
    // Reload after returning from reviewed phone import so saved clients
    // appear immediately in the current company list.
    await _loadClients();
    if (tabIndex != null && mounted) widget.onTabSelected(tabIndex);
  }

  Future<void> _openAddClient() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final draft = await Sign2DigitalNavigation.open<ClientDraft>(
      context, AddClientScreen());
    if (draft == null || !mounted) return;
    try {
      await widget.repository.createClient(draft);
      if (!mounted) return;
      _search.clear();
      await _loadClients();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.repository is RemoteClientRepository
            ? 'Client saved to your company.' : 'Client added to the local demo list')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to save the client.')),
      );
    }
  }

  Future<void> _openClientDetails(ClientProfile client) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await Sign2DigitalNavigation.open<void>(
      context,
      ClientDetailsScreen(
          client: client,
          repository: widget.repository,
          companyId: widget.companyId,
          createdJobsForClient: widget.createdJobsForClient,
          onJobCreated: widget.onJobCreated,
          onOpenJob: widget.onOpenJob,
          onViewAllJobs: (_) {
            Navigator.of(context).pop();
            widget.onTabSelected(1);
          },
        ),
      destination: 'client-details:${client.id}',
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
        constraints: BoxConstraints(maxWidth:
            MediaQuery.orientationOf(context) == Orientation.landscape
                ? double.infinity : 560),
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
