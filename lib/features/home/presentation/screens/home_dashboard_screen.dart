import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/dashboard_colors.dart';
import '../../../../core/widgets/sign2digital_primary_button.dart';
import '../../../clients/data/client_repository.dart';
import '../../../documents/data/demo_document_repository.dart';
import '../../../documents/domain/document_record.dart';
import '../../../jobs/data/mock_jobs.dart';
import '../../../jobs/domain/job_model.dart';
import '../../../jobs/presentation/widgets/sign2digital_job_card.dart';
import '../../../quotes/domain/quote_review_models.dart';
import '../../../quotes/presentation/widgets/sign2digital_quote_shadow_panel.dart';

/// Home content inside the existing dashboard header and bottom navigation.
/// Existing repositories drive counts; preview records are explicitly labelled
/// and are never portrayed as live Laravel/account data.
class HomeDashboardScreen extends StatefulWidget {
  const HomeDashboardScreen({
    super.key,
    required this.clientRepository,
    required this.onNavigate,
    required this.onJobTap,
    required this.onCreateQuote,
    required this.onOpenQuoteTracking,
    this.documentRepository = const DemoDocumentRepository(),
    this.selectedQuote,
    this.refreshRevision = 0,
  });

  final ClientRepository clientRepository;
  final DocumentRepository documentRepository;
  final ValueChanged<int> onNavigate;
  final ValueChanged<JobModel> onJobTap;
  final VoidCallback onCreateQuote;
  final VoidCallback onOpenQuoteTracking;
  final QuoteReviewDraft? selectedQuote;
  final int refreshRevision;

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  int? _clientCount;
  int? _documentCount;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didUpdateWidget(covariant HomeDashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshRevision != widget.refreshRevision ||
        oldWidget.clientRepository != widget.clientRepository ||
        oldWidget.documentRepository != widget.documentRepository) {
      _reload();
    }
  }

  Future<void> _reload() async {
    if (mounted) {
      setState(() => _loading = true);
    }
    int? clients;
    int? documents;
    try {
      clients = (await widget.clientRepository.listClients()).length;
    } catch (_) {
      // A failed source must not display an invented zero.
    }
    try {
      documents = (await widget.documentRepository.listDocuments()).length;
    } catch (_) {
      // Other dashboard links stay usable while a source is unavailable.
    }
    if (!mounted) return;
    setState(() {
      _clientCount = clients;
      _documentCount = documents;
      _loading = false;
    });
  }

  String _count(int? value) => _loading ? '…' : (value?.toString() ?? '—');

  @override
  Widget build(BuildContext context) {
    final recentJobs = MockJobsData.search(
      category: JobCategory.active,
      query: '',
    ).take(2).toList(growable: false);
    final quote = widget.selectedQuote;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: RefreshIndicator(
          onRefresh: _reload,
          child: ListView(
            key: const Key('home-dashboard-scroll'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
            children: [
              const Text('Home', style: AppTextStyles.heading),
              const SizedBox(height: 8),
              const Text(
                'Your workspace at a glance',
                style: AppTextStyles.subtitle,
              ),
              const SizedBox(height: 20),
              Container(
                key: const Key('home-preview-notice'),
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: DashboardColors.paleBlue,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded,
                        color: AppColors.primary, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Workspace preview · The current Jobs, Clients and '
                        'Documents repositories include sample data. '
                        'Live business totals require the Laravel integration.',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          height: 1.45,
                          fontWeight: FontWeight.w500,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              const Text('Overview', style: AppTextStyles.fieldLabel),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  const gap = 12.0;
                  final columns = constraints.maxWidth >= 620 ? 3 : 2;
                  final cardWidth =
                      (constraints.maxWidth - gap * (columns - 1)) / columns;
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      SizedBox(
                        width: cardWidth,
                        child: _HomeStatCard(
                          key: const Key('home-stat-jobs'),
                          title: 'Active jobs',
                          value: MockJobsData.count(JobCategory.active)
                              .toString(),
                          icon: Icons.work_outline_rounded,
                          onTap: () => widget.onNavigate(1),
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _HomeStatCard(
                          key: const Key('home-stat-clients'),
                          title: 'Clients',
                          value: _count(_clientCount),
                          icon: Icons.people_outline_rounded,
                          onTap: () => widget.onNavigate(2),
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _HomeStatCard(
                          key: const Key('home-stat-documents'),
                          title: 'Documents',
                          value: _count(_documentCount),
                          icon: Icons.description_outlined,
                          onTap: () => widget.onNavigate(3),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              const Text('Quick actions', style: AppTextStyles.fieldLabel),
              const SizedBox(height: 12),
              Sign2DigitalPrimaryButton(
                key: const Key('home-create-quote'),
                label: 'Create Quote',
                leading: const Icon(Icons.add_rounded, size: 22),
                onPressed: widget.onCreateQuote,
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  const gap = 12.0;
                  final width = (constraints.maxWidth - gap) / 2;
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      SizedBox(
                        width: width,
                        child: _HomeShortcut(
                          key: const Key('home-go-jobs'),
                          icon: Icons.work_outline_rounded,
                          title: 'Jobs',
                          onTap: () => widget.onNavigate(1),
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: _HomeShortcut(
                          key: const Key('home-go-clients'),
                          icon: Icons.people_outline_rounded,
                          title: 'Clients',
                          onTap: () => widget.onNavigate(2),
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: _HomeShortcut(
                          key: const Key('home-go-documents'),
                          icon: Icons.description_outlined,
                          title: 'Documents',
                          onTap: () => widget.onNavigate(3),
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: _HomeShortcut(
                          key: const Key('home-go-more'),
                          icon: Icons.grid_view_rounded,
                          title: 'More tools',
                          onTap: () => widget.onNavigate(4),
                        ),
                      ),
                    ],
                  );
                },
              ),
              if (quote != null) ...[
                const SizedBox(height: 24),
                const Text('Signature tracking',
                    style: AppTextStyles.fieldLabel),
                const SizedBox(height: 12),
                Sign2DigitalQuoteShadowPanel(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        quote.quoteNumber.trim().isEmpty
                            ? 'Selected quote' : quote.quoteNumber,
                        style: AppTextStyles.fieldLabel,
                      ),
                      const SizedBox(height: 7),
                      const Text(
                        'Track the selected quote. Delivery and signature '
                        'status are only confirmed by verified events.',
                        style: AppTextStyles.subtitle,
                      ),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        key: const Key('home-open-signature-tracking'),
                        onPressed: widget.onOpenQuoteTracking,
                        icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                        label: const Text('View tracking'),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  const Expanded(
                    child: Text('Recent jobs',
                        style: AppTextStyles.fieldLabel),
                  ),
                  TextButton(
                    key: const Key('home-view-all-jobs'),
                    onPressed: () => widget.onNavigate(1),
                    child: const Text('View all'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text('Sample jobs', style: AppTextStyles.small),
              const SizedBox(height: 12),
              for (final job in recentJobs) ...[
                Sign2DigitalJobCard(
                  job: job,
                  onTap: () => widget.onJobTap(job),
                ),
                const SizedBox(height: 14),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeStatCard extends StatelessWidget {
  const _HomeStatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Sign2DigitalQuoteShadowPanel(
    clip: true,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 24, color: AppColors.primary),
              const SizedBox(height: 12),
              Text(
                value,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.dark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                maxLines: 2,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.secondaryText,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _HomeShortcut extends StatelessWidget {
  const _HomeShortcut({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Sign2DigitalQuoteShadowPanel(
    clip: true,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          child: Row(
            children: [
              Icon(icon, size: 22, color: AppColors.primary),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.dark,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  size: 18, color: AppColors.secondaryText),
            ],
          ),
        ),
      ),
    ),
  );
}
