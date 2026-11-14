import 'package:flutter/material.dart';
import '../../../../core/theme/sign2digital_motion.dart';

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
import '../../../invoices/domain/invoice_record.dart';
import '../../../expenses/presentation/screens/expenses_screen.dart';
import '../../../expenses/presentation/screens/add_expense_screen.dart';
import '../../../expenses/data/demo_expense_repository.dart';
import '../../../expenses/data/remote_expense_repository.dart';
import '../../../expenses/domain/expense_record.dart';
import '../../../labour/presentation/screens/add_labour_entry_screen.dart';
import '../../../labour/data/demo_labour_repository.dart';
import '../../../labour/data/remote_labour_repository.dart';
import '../../../labour/domain/labour_entry.dart';
import '../../../reminders/presentation/screens/reminders_screen.dart';
import '../../../reminders/presentation/screens/notification_inbox_screen.dart';
import '../../../documents/presentation/screens/documents_screen.dart';
import '../../../quotes/domain/quote_tracking_home_session.dart';
import '../../../quotes/presentation/screens/signature_request_screen.dart';
import '../../../profile/presentation/screens/profile_settings_screen.dart';
import '../../../profile/presentation/screens/help_support_screen.dart';
import '../../../company/presentation/screens/create_company_screen.dart';
import '../../../company/presentation/screens/company_team_screen.dart';
import '../../../deposits/presentation/screens/deposits_screen.dart';
import '../../../documents/data/remote_general_document_repository.dart';
import '../../../documents/data/remote_site_report_repository.dart';
import '../../../documents/presentation/screens/ai_documents_screen.dart';
import '../../../documents/presentation/screens/reports_screen.dart';
import '../../../equipment/data/remote_equipment_repository.dart';
import '../../../equipment/presentation/screens/equipment_screen.dart';
import '../../../labour/presentation/screens/time_labour_screen.dart';
import '../../../support/presentation/support_assistant_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/sign2digital_bottom_navigation_bar.dart';
import '../../../../core/widgets/sign2digital_dashboard_header.dart';
import '../../../../core/widgets/sign2digital_search_field.dart';
import '../../data/client_repository.dart';
import '../../data/demo_client_repository.dart';
import '../../data/remote_client_repository.dart';
import '../../../auth/data/mobile_auth_repository.dart';
import '../../../company/data/remote_company_repository.dart';
import '../../../company/domain/company_profile.dart';
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
    this.documentRepository, this.invoiceRepository, this.initialTab = 2});

  final ClientRepository? repository;
  /// Optional injected catalog for deterministic UI tests and embedded flows.
  /// Production retains the existing automatically selected repository.
  final DocumentRepository? documentRepository;
  /// Explicit repository injection for isolated navigation tests only.
  final InvoiceRepository? invoiceRepository;
  /// The real login route starts on Home (0). Existing clients-only embed
  /// points keep their original initial tab (2) for backwards compatibility.
  final int initialTab;

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> with WidgetsBindingObserver {
  late int _selectedIndex;
  DocumentCategory? _documentsCategory;
  int _homeRevision = 0;
  int _clientsRevision = 0;
  int _documentsRevision = 0;
  int _tabEpoch = 0;
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
    if (!_usesRemoteJobs || !mounted ||
        !ActiveCompanySession.canRead('jobs')) return;
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
    WidgetsBinding.instance.addObserver(this);
    _selectedIndex = widget.initialTab;
    _selectedCompanyId = ActiveCompanySession.companyId?.toString();
    ActiveCompanySession.access.addListener(_onCompanyAccessChanged);
    _repository = widget.repository ??
        (MobileAuthRepository.shared.isSignedIn
          ? RemoteClientRepository.shared
          : DemoClientRepository());
    if (_usesRemoteJobs) _loadJobs();
  }

  void _onCompanyAccessChanged() {
    if (!mounted) return;
    final index = _selectedIndex;
    final disallowed = (index == 1 && !ActiveCompanySession.canRead('jobs')) ||
        (index == 2 && !ActiveCompanySession.canRead('clients')) ||
        (index == 3 && !ActiveCompanySession.canRead('documents'));
    setState(() {
      if (disallowed) _selectedIndex = 0;
      _remoteJobs = const [];
      _clientsRevision++;
      _documentsRevision++;
      _homeRevision++;
    });
    if (ActiveCompanySession.canRead('jobs')) _loadJobs();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !_usesRemoteJobs ||
        !MobileAuthRepository.shared.isSignedIn) return;
    // Reload verified grants when returning to the app. Server middleware
    // independently enforces updated/revoked access for every API request.
    RemoteCompanyRepository.shared.list().catchError((Object _) {
      // Preserve the last verified display during temporary network failure;
      // the server remains the authority for actions and company data.
      return <CompanyProfile>[];
    });
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
    WidgetsBinding.instance.removeObserver(this);
    ActiveCompanySession.access.removeListener(_onCompanyAccessChanged);
    if (_dashboardNavigator != null && _dashboardRoute != null) {
      Sign2DigitalNavigation.detachDashboard(
        _dashboardNavigator!, _dashboardRoute!);
    }
    super.dispose();
  }

  Future<void> _openSupportAssistant() async {
    final screen = switch (_selectedIndex) {
      1 => 'jobs',
      2 => 'clients',
      3 => 'documents',
      4 => 'settings',
      _ => 'home',
    };
    await SupportAssistantLauncher.show(context, screen: screen,
      onNavigate: (destination) => _openSupportDestination(destination));
  }

  Future<void> _openSupportDestination(String destination) async {
    if (!mounted) return;
    final requiredModule = switch (destination) {
      'clients' => 'clients',
      'jobs' => 'jobs',
      'quotes' => 'quotes',
      'documents' => 'documents',
      'invoices' => 'invoices',
      'expenses' => 'expenses',
      'deposits' => 'invoices',
      'labour' => 'labour',
      'equipment' => 'equipment',
      'reports' => 'reports',
      'ai_documents' => 'documents',
      _ => null,
    };
    if ((requiredModule != null &&
          !ActiveCompanySession.canRead(requiredModule)) ||
        (destination == 'deposits' &&
          !ActiveCompanySession.canRead('jobs')) ||
        (destination == 'quotes' &&
          !ActiveCompanySession.canRead('documents'))) {
      _notifyHome('Your company role does not allow access to this module.');
      return;
    }
    switch (destination) {
      case 'clients':
        _selectDashboardTab(2);
      case 'jobs':
        _selectDashboardTab(1);
      case 'quotes':
        _onHomeAction(HomeAction.quotes);
      case 'documents':
        _selectDashboardTab(3);
      case 'invoices':
        _onHomeAction(HomeAction.invoices);
      case 'expenses':
        _onHomeAction(HomeAction.expenses);
      case 'deposits':
        await _openHomeRoute(DepositsScreen(
          selectedNavigationIndex: _selectedIndex,
          onNavigationSelected: _selectDashboardTab));
      case 'labour':
        await _openHomeRoute(TimeLabourScreen(
          selectedNavigationIndex: _selectedIndex,
          onNavigationSelected: _selectDashboardTab));
      case 'equipment':
        await _openHomeRoute(EquipmentScreen(
          repository: RemoteEquipmentRepository.shared,
          onNavigationSelected: _selectDashboardTab,
          onNotificationTap: _openNotifications));
      case 'reports':
        await _openHomeRoute(ReportsScreen(
          repository: RemoteSiteReportRepository.shared,
          onNavigationSelected: _selectDashboardTab,
          onNotificationTap: _openNotifications));
      case 'ai_documents':
        await _openHomeRoute(AiDocumentsScreen(
          repository: RemoteGeneralDocumentRepository.shared,
          onNavigationSelected: _selectDashboardTab,
          onNotificationTap: _openNotifications));
      case 'reminders':
        await _openHomeRoute(RemindersScreen(
          onNavigationSelected: _selectDashboardTab,
          onNotificationTap: _openNotifications));
      case 'settings':
        await _openHomeRoute(ProfileSettingsScreen(
          onNotificationTap: _openNotifications,
          onNavigationSelected: _selectDashboardTab));
      case 'support':
        await _openHomeRoute(const HelpSupportScreen());
      case 'companies':
        if (ActiveCompanySession.companyId != null &&
            !ActiveCompanySession.isOwner) return;
        await _openHomeRoute(const CreateCompanyScreen());
      case 'team':
        final id = ActiveCompanySession.companyId;
        if (id == null || !ActiveCompanySession.isOwner) {
          _notifyHome('Only the company owner can manage team invitations.');
          return;
        }
        try {
          final companies = await RemoteCompanyRepository.shared.list();
          if (!mounted || id != ActiveCompanySession.companyId) return;
          final selected = companies.where((c) => c.id == '$id');
          if (selected.isEmpty) {
            _notifyHome('Unable to open the selected company team.');
            return;
          }
          await _openHomeRoute(CompanyTeamScreen(
            companyId: '$id', companyName: selected.first.companyName,
            role: ActiveCompanySession.role));
        } catch (_) {
          _notifyHome('Unable to load company team. Please retry.');
        }
      default:
        _notifyHome('This destination is not available.');
    }
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
    if ((index == 1 && !ActiveCompanySession.canRead('jobs')) ||
        (index == 2 && !ActiveCompanySession.canRead('clients')) ||
        (index == 3 && !ActiveCompanySession.canRead('documents'))) return;
    // An already selected tab has no new route or expensive refresh.
    if (_selectedIndex == index &&
        (index != 3 || category == null || category == _documentsCategory)) {
      // Tapping Jobs again is also an explicit refresh of live progress.
      if (index == 1 && _usesRemoteJobs) {
        _loadJobs();
      }
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _tabEpoch++;
      _selectedIndex = index;
      if (index == 3) {
        _documentsCategory = category;
        _documentsRevision++;
      }
      if (index == 0) _homeRevision++;
    });
    // Module activity can change progress independently of job edits.
    // Always get fresh server percentages when re-entering the Jobs tab.
    if (index == 1 && _usesRemoteJobs) {
      _loadJobs();
    }
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
    if (!ActiveCompanySession.canWrite('jobs')) return;
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
    if (!ActiveCompanySession.canWrite('clients')) return;
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
    if (!ActiveCompanySession.canWrite('expenses')) return;
    final draft = await Sign2DigitalNavigation.open<ExpenseRecord>(
      context, const AddExpenseScreen(selectedNavigationIndex: 0));
    if (draft == null || !mounted) return;
    try {
      final remote = MobileAuthRepository.shared.isSignedIn;
      await (remote ? RemoteExpenseRepository.shared
          : const DemoExpenseRepository()).saveDraft(draft);
      _notifyHome(remote ? 'Expense saved for review.'
          : 'Expense saved locally for review.');
    } catch (_) {
      _notifyHome('Unable to save the expense draft.');
    }
    if (mounted) setState(() => _homeRevision++);
  }

  Future<void> _createTimeFromHome() async {
    if (!ActiveCompanySession.canWrite('labour')) return;
    final remote = MobileAuthRepository.shared.isSignedIn;
    List<JobModel> availableJobs;
    try {
      availableJobs = remote ? await RemoteLabourRepository.shared.jobs()
          : LabourDemoJobs.all;
    } catch (error) {
      _notifyHome(error is SignApiException ? error.message
          : 'Unable to load your jobs.');
      return;
    }
    if (!mounted) return;
    final company = ActiveCompanySession.companyId;
    final entry = await Sign2DigitalNavigation.open<LabourEntry>(
      context,
      AddLabourEntryScreen(
        kind: LabourEntryKind.timeSheet,
        jobs: availableJobs,
        selectedNavigationIndex: 0,
      ),
    );
    if (entry == null || !mounted) return;
    if (remote && company != ActiveCompanySession.companyId) {
      _notifyHome('Company changed. Please add the time entry again.');
      return;
    }
    try {
      await (remote ? RemoteLabourRepository.shared
          : const DemoLabourRepository()).save(entry);
      _notifyHome(remote ? 'Time entry saved as Pending.'
          : 'Time entry saved locally as Pending.');
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
    final required = switch (action) {
      HomeAction.jobs || HomeAction.newJob => 'jobs',
      HomeAction.addClient => 'clients',
      HomeAction.quotes || HomeAction.createQuote ||
      HomeAction.signatureTracking => 'quotes',
      HomeAction.documents || HomeAction.createDocument => 'documents',
      HomeAction.invoices => 'invoices',
      HomeAction.expenses || HomeAction.addExpense => 'expenses',
      HomeAction.addTime => 'labour',
      HomeAction.reminders => null,
    };
    if (required != null && !ActiveCompanySession.can(
      required, const <HomeAction>{HomeAction.createQuote, HomeAction.newJob,
      HomeAction.addClient, HomeAction.createDocument, HomeAction.addExpense,
      HomeAction.addTime}.contains(action) ? 'write' : 'read')) return;
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
    if (!_usesRemoteJobs || !ActiveCompanySession.canWrite('jobs')) return false;
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
    await Sign2DigitalNavigation.runOnce<void>(
      context, 'job-details-load:${job.id}',
      () => _loadAndOpenJobDetails(job),
    );
  }

  Future<void> _loadAndOpenJobDetails(JobModel job) async {
    final tabEpoch = _tabEpoch;
    final originalCompany = ActiveCompanySession.companyId;
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
    if (!mounted || tabEpoch != _tabEpoch ||
        originalCompany != ActiveCompanySession.companyId) return;
    JobDetailsModel? realDetails;
    if (_usesRemoteJobs) {
      try {
        realDetails = await RemoteJobRepository.shared.loadDetails(job);
      } catch (error) {
        _notifyHome(error is SignApiException
            ? error.message : 'Unable to open the job.');
        return;
      }
      if (!mounted || tabEpoch != _tabEpoch ||
          originalCompany != ActiveCompanySession.companyId) return;
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
              onSupportTap: _openSupportAssistant,
            ),
            Expanded(
              child: Sign2DigitalAnimatedIndexedStack(
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
                  ActiveCompanySession.canRead('jobs') ? JobsScreen(
                    createdJobs: _dashboardJobs,
                    includeDemoJobs: !_usesRemoteJobs,
                    loading: _usesRemoteJobs && _jobsLoading,
                    errorMessage: _usesRemoteJobs ? _jobsError : null,
                    onRetry: _loadJobs,
                    onCreateJob: _createJobFromHome,
                    onNotReady: _showNotReady,
                    onJobTap: _openJobDetails,
                  ) : const SizedBox.shrink(),
                  ActiveCompanySession.canRead('clients') ? _ClientsContent(
                    key: ValueKey('clients-content-$_clientsRevision'),
                    repository: _repository,
                    createdJobsForClient: _jobsForClient,
                    onJobCreated: _recordCreatedJob,
                    onOpenJob: _openJobDetails,
                    companyId: _selectedCompanyId,
                    showNotReady: _showNotReady,
                    onTabSelected: _selectDashboardTab,
                  ) : const SizedBox.shrink(),
                  ActiveCompanySession.canRead('documents') ? DocumentsScreen(
                    repository: widget.documentRepository,
                    initialCategory: _documentsCategory,
                    refreshRevision: _documentsRevision,
                  ) : const SizedBox.shrink(),
                  MoreScreen(
                    invoiceRepository: widget.invoiceRepository,
                    onTabSelected: _selectDashboardTab,
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
                    if (ActiveCompanySession.canWrite('clients')) LayoutBuilder(
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
