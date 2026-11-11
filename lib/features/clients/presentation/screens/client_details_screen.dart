import '../../../../core/navigation/sign2digital_navigation.dart';
import 'package:sign2digital/features/quotes/presentation/screens/create_quote_screen.dart';
import 'package:flutter/material.dart';

import '../../../jobs/presentation/screens/create_job_screen.dart';
import '../../../jobs/domain/create_job_draft.dart';
import '../../../jobs/domain/job_model.dart';
import '../../../jobs/data/demo_created_job_repository.dart';
import '../../../jobs/data/remote_job_repository.dart';
import '../../../jobs/presentation/screens/job_details_screen.dart';
import '../../../documents/data/remote_document_repository.dart';
import '../../../documents/presentation/screens/document_details_screen.dart';
import '../../../invoices/data/remote_invoice_repository.dart';
import '../../../invoices/presentation/screens/invoice_details_screen.dart';
import '../../../../core/services/active_company_session.dart';
import '../../../../core/services/sign_api_client.dart';

import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/sign2digital_header.dart';
import '../../../../core/widgets/sign2digital_primary_button.dart';
import '../../data/client_repository.dart';
import '../../data/demo_client_details.dart';
import '../../data/remote_client_repository.dart';
import '../../domain/client_details_model.dart';
import '../../domain/client_draft.dart';
import '../../domain/client_profile.dart';
import '../widgets/sign2digital_client_action_card.dart';
import '../widgets/sign2digital_client_avatar.dart';
import '../widgets/sign2digital_client_related_item_card.dart';
import '../widgets/sign2digital_details_tabs.dart';
import '../widgets/sign2digital_statistics_card.dart';
import '../widgets/sign2digital_status_badge.dart';
import 'add_client_screen.dart';

/// Company-bound client dossier, using real related records when signed in.
class ClientDetailsScreen extends StatefulWidget {
  const ClientDetailsScreen({
    super.key,
    required this.client,
    required this.repository,
    this.onNewQuote,
    this.onNewJob,
    this.onViewAllJobs,
    this.onJobCreated,
    this.onOpenJob,
    this.createdJobsForClient,
    this.companyId,
  });

  final ClientProfile client;
  final ClientRepository repository;
  final ValueChanged<ClientProfile>? onNewQuote;
  final ValueChanged<ClientProfile>? onNewJob;
  final ValueChanged<ClientProfile>? onViewAllJobs;
  final Future<JobModel> Function(CreateJobDraft)? onJobCreated;
  final Future<void> Function(JobModel)? onOpenJob;
  final List<JobModel> Function(String clientId)? createdJobsForClient;
  final String? companyId;

  @override
  State<ClientDetailsScreen> createState() => _ClientDetailsScreenState();
}

class _ClientDetailsScreenState extends State<ClientDetailsScreen> {
  late ClientProfile _client;
  int _tabIndex = 0;
  ClientDetailsModel? _liveDetails;
  bool _detailsLoading = false;
  String? _detailsError;
  // Used only when Client Details is opened outside the dashboard shell.
  final DemoCreatedJobRepository _standaloneJobs = DemoCreatedJobRepository();

  List<JobModel> get _createdClientJobs =>
      widget.repository is RemoteClientRepository
          ? const <JobModel>[] :
      widget.createdJobsForClient?.call(_client.id) ??
      _standaloneJobs.forClient(_client.id);

  Future<void> _openExistingJob(JobModel job) async {
    final open = widget.onOpenJob;
    if (open != null) {
      await open(job);
    } else {
      await Sign2DigitalNavigation.push<void>(context,
        MaterialPageRoute<void>(builder: (_) => JobDetailsScreen(
          job: job,
          client: _client,
          companyId: widget.companyId,
        )),
      );
    }
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _client = widget.client;
    if (widget.repository is RemoteClientRepository) _loadDetails();
  }

  Future<void> _loadDetails() async {
    final repository = widget.repository;
    if (repository is! RemoteClientRepository || !mounted) return;
    final company = ActiveCompanySession.companyId;
    setState(() { _detailsLoading = true; _detailsError = null; });
    try {
      final details = await repository.details(_client.id);
      if (!mounted || company != ActiveCompanySession.companyId) return;
      setState(() {
        _liveDetails = details;
        _client = details.client;
        _detailsLoading = false;
      });
    } catch (error) {
      if (!mounted || company != ActiveCompanySession.companyId) return;
      setState(() {
        _detailsLoading = false;
        _detailsError = error is SignApiException ? error.message
            : 'Unable to load client details.';
      });
    }
  }

  Future<void> _openRelatedRecord(ClientRelatedRecord record) async {
    if (widget.repository is! RemoteClientRepository) {
      if (_tabIndex == 0) {
        for (final job in _createdClientJobs) {
          if (job.id == record.id) { await _openExistingJob(job); return; }
        }
      }
      _notReady('Open related record');
      return;
    }
    try {
      switch (_tabIndex) {
        case 0:
          final id = int.tryParse(record.id);
          if (id == null || id < 1) throw StateError('Invalid job.');
          await _openExistingJob(await RemoteJobRepository.shared.getJob(id));
          break;
        case 1:
        case 2:
          final document = await RemoteDocumentRepository.shared.details(record.id);
          if (!mounted) return;
          await Sign2DigitalNavigation.open<void>(context,
              DocumentDetailsScreen(
                documentId: record.id, document: document,
                loadDocument: RemoteDocumentRepository.shared.details,
              ));
          break;
        case 3:
          final invoice = await RemoteInvoiceRepository.shared.invoiceDetail(record.id);
          if (!mounted) return;
          await Sign2DigitalNavigation.open<void>(context,
              InvoiceDetailsScreen(invoice: invoice,
                  repository: RemoteInvoiceRepository.shared));
          break;
        case 4:
          if (!mounted) return;
          await showDialog<void>(context: context, builder: (dialog) =>
              AlertDialog(title: Text(record.title),
                content: SingleChildScrollView(child: Text(record.description)),
                actions: [TextButton(
                  onPressed: () => Navigator.of(dialog).pop(),
                  child: const Text('Close'))]));
      }
      if (mounted) await _loadDetails();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(error is SignApiException ? error.message
            : 'Unable to open the related record.'),
      ));
    }
  }

  Future<void> _editClient() async {
    final draft = await Sign2DigitalNavigation.push<ClientDraft>(context,
      MaterialPageRoute<ClientDraft>(
        builder: (_) => AddClientScreen(initialClient: _client),
      ),
    );
    if (!mounted || draft == null) {
      return;
    }
    try {
      final updated = await widget.repository.updateClient(_client.id, draft);
      if (!mounted) {
        return;
      }
      setState(() => _client = updated);
      if (widget.repository is RemoteClientRepository) await _loadDetails();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.repository is RemoteClientRepository
            ? 'Client updated.' : 'Client updated in the local demo list')),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This repository does not support demo editing yet'),
        ),
      );
    }
  }

  Future<void> _openCreateJob() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final draft = await Sign2DigitalNavigation.push<CreateJobDraft>(context,
      MaterialPageRoute<CreateJobDraft>(
        builder: (_) => CreateJobScreen(
          initialClient: _client,
          clientRepository: widget.repository,
        ),
      ),
    );
    if (!mounted || draft == null) {
      return;
    }
    try {
      final job = widget.onJobCreated != null
          ? await widget.onJobCreated!(draft)
          : widget.repository is RemoteClientRepository
              ? await RemoteJobRepository.shared.createJob(draft)
              : _standaloneJobs.create(draft);
      if (!mounted) return;
      setState(() => _tabIndex = 0);
      if (widget.repository is RemoteClientRepository) await _loadDetails();
      if (!mounted) return;
      await _openExistingJob(job);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Unable to create the job.'),
      ));
    }
  }

  void _notReady(String action) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$action is not available in this UI preview.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final details = _liveDetails ??
        (widget.repository is RemoteClientRepository
            ? ClientDetailsModel(
                client: _client, status: 'Active',
                displayAddress: _client.address,
                totalQuotes: 0, totalDocuments: 0, totalInvoices: 0,
                jobs: const [], quotes: const [], documents: const [],
                invoices: const [], notes: const [],
              )
            : DemoClientDetails.forClient(_client));
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Column(
          children: [
            Sign2DigitalHeader(
              title: 'Client Details',
              onBack: () => Navigator.of(context).maybePop(),
            ),
            Expanded(
              child: (_detailsLoading ||
                      (_detailsError == null &&
                       widget.repository is RemoteClientRepository)) &&
                  _liveDetails == null
                  ? const Center(child: CircularProgressIndicator())
                  : _detailsError != null && _liveDetails == null
                  ? Center(child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [Text(_detailsError!,
                        style: AppTextStyles.subtitle),
                        TextButton(onPressed: _loadDetails,
                          child: const Text('Retry'))],
                    ))
                  : Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth:
                    MediaQuery.orientationOf(context) == Orientation.landscape
                        ? double.infinity : 560),
                  child: SingleChildScrollView(
                    key: const Key('client-details-scroll'),
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _profile(details),
                        const SizedBox(height: 25),
                        _contacts(details),
                        const SizedBox(height: 20),
                        _actions(),
                        const SizedBox(height: 20),
                        _statistics(details),
                        const SizedBox(height: 25),
                        Sign2DigitalDetailsTabs(
                          labels: [
                            'Jobs (${details.jobs.length + _createdClientJobs.length})',
                            'Quotes',
                            'Documents',
                            'Invoices',
                            'Notes',
                          ],
                          selectedIndex: _tabIndex,
                          onSelected: (index) =>
                              setState(() => _tabIndex = index),
                        ),
                        const SizedBox(height: 20),
                        _tabContent(details),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _profile(ClientDetailsModel details) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Sign2DigitalClientAvatar(client: _client),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_client.companyName, style: AppTextStyles.fieldLabel),
              const SizedBox(height: 5),
              Text(_client.companyType, style: _mutedStyle),
            ],
          ),
        ),
        const SizedBox(width: 7),
        Sign2DigitalStatusBadge(status: details.status),
      ],
    );
  }

  Widget _contacts(ClientDetailsModel details) {
    final rows = <({String asset, String value})>[
      (asset: 'assets/icons/phone.svg', value: _client.phone),
      (asset: 'assets/icons/email.svg', value: _client.email),
      (asset: 'assets/icons/address.svg', value: details.displayAddress),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows
          .where((row) => row.value.trim().isNotEmpty)
          .map(
            (row) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  SvgPicture.asset(
                    row.asset,
                    width: 20,
                    height: 20,
                    colorFilter: const ColorFilter.mode(
                      AppColors.placeholder,
                      BlendMode.srcIn,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      row.value,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        letterSpacing: -0.3,
                        color: AppColors.placeholder,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _actions() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Sign2DigitalClientActionCard(
            key: const Key('edit-client-action'),
            label: 'Edit Client',
            fallbackIcon: Icons.edit_outlined,
            onTap: _editClient,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Sign2DigitalClientActionCard(
            label: 'New Quote',
            fallbackIcon: Icons.request_quote_outlined,
            onTap: () => widget.onNewQuote != null
                ? widget.onNewQuote!(_client)
                : Sign2DigitalNavigation.push<void>(context,
                    MaterialPageRoute<void>(
                      builder: (_) => CreateQuoteScreen(
                        clientId: _client.id,
                        clientName: _client.companyName,
                        clientEmail: _client.email,
                        clientPhone: _client.phone,
                        clientAddress: _client.address,
                        companyId: widget.companyId,
                      ),
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Sign2DigitalClientActionCard(
            label: 'New Job',
            iconAsset: 'assets/icons/jobs.svg',
            fallbackIcon: Icons.work_outline,
            onTap: () => widget.onNewJob != null
                ? widget.onNewJob!(_client)
                : _openCreateJob(),
          ),
        ),
      ],
    );
  }

  Widget _statistics(ClientDetailsModel details) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 16) / 2;
        return Wrap(
          spacing: 16,
          runSpacing: 20,
          children: [
            SizedBox(
              width: width,
              child: Sign2DigitalStatisticsCard(
                count: widget.repository is RemoteClientRepository
                    ? details.jobs.length
                    : _client.jobCount + _createdClientJobs.length,
                label: 'Total jobs',
                iconAsset: 'assets/icons/jobs.svg',
                fallbackIcon: Icons.work_outline,
              ),
            ),
            SizedBox(
              width: width,
              child: Sign2DigitalStatisticsCard(
                count: details.totalQuotes,
                label: 'Total quotes',
                fallbackIcon: Icons.request_quote_outlined,
              ),
            ),
            SizedBox(
              width: width,
              child: Sign2DigitalStatisticsCard(
                count: details.totalDocuments,
                label: 'Documents',
                iconAsset: 'assets/icons/doc_numbering.svg',
                fallbackIcon: Icons.description_outlined,
              ),
            ),
            SizedBox(
              width: width,
              child: Sign2DigitalStatisticsCard(
                count: details.totalInvoices,
                label: 'Total invoices',
                fallbackIcon: Icons.receipt_long_outlined,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _tabContent(ClientDetailsModel details) {
    final records = switch (_tabIndex) {
      0 => <ClientRelatedRecord>[
          for (final job in _createdClientJobs)
            ClientRelatedRecord(
              id: job.id,
              title: job.title,
              description: job.description,
              meta: job.referenceNumber,
              status: job.statusLabel,
            ),
          ...details.jobs,
        ],
      1 => details.quotes,
      2 => details.documents,
      3 => details.invoices,
      _ => details.notes,
    };
    final names = ['jobs', 'quotes', 'documents', 'invoices', 'notes'];
    if (records.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Text(
          'No ${names[_tabIndex]} available',
          textAlign: TextAlign.center,
          style: AppTextStyles.subtitle,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final record in records) ...[
          Sign2DigitalClientRelatedItemCard(
            key: ValueKey(record.id),
            item: record,
            onTap: () => _openRelatedRecord(record),
          ),
          const SizedBox(height: 20),
        ],
        if (_tabIndex == 0)
          Sign2DigitalPrimaryButton(
            key: const Key('view-all-jobs-button'),
            label: 'View All Jobs (${widget.repository is RemoteClientRepository
                ? details.jobs.length : _client.jobCount + _createdClientJobs.length})',
            onPressed: () => widget.onViewAllJobs != null
                ? widget.onViewAllJobs!(_client)
                : _notReady('View All Jobs'),
          ),
      ],
    );
  }

  static const _mutedStyle = TextStyle(
    fontFamily: 'Inter',
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.placeholder,
  );
}
