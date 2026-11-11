import '../../../../core/navigation/sign2digital_navigation.dart';
import 'package:flutter/material.dart';
import '../../../auth/data/mobile_auth_repository.dart';

import 'create_job_screen.dart';
import '../../domain/create_job_draft.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/sign2digital_primary_button.dart';
import '../../../../core/widgets/sign2digital_search_field.dart';
import '../../../clients/presentation/widgets/sign2digital_details_tabs.dart';
import '../../data/mock_jobs.dart';
import '../../domain/job_model.dart';
import '../widgets/sign2digital_job_card.dart';

/// Content for the shared authenticated dashboard shell, which already owns
/// the logo header and the fixed five-tab bottom navigation.
class JobsScreen extends StatefulWidget {
  const JobsScreen({
    super.key,
    this.onCreateJob,
    this.onJobTap,
    this.onNotReady,
    this.createdJobs = const [],
    this.includeDemoJobs = true,
    this.loading = false,
    this.errorMessage,
    this.onRetry,
  });

  final VoidCallback? onCreateJob;
  final ValueChanged<JobModel>? onJobTap;
  final ValueChanged<String>? onNotReady;
  /// Newly created jobs from the authenticated dashboard session.
  final List<JobModel> createdJobs;
  /// Demo cards are visible only in standalone UI preview mode.
  final bool includeDemoJobs;
  final bool loading;
  final String? errorMessage;
  final VoidCallback? onRetry;

  @override
  State<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends State<JobsScreen> {
  final TextEditingController _search = TextEditingController();
  JobCategory _category = JobCategory.active;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _openCreateJob() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final draft = await Sign2DigitalNavigation.push<CreateJobDraft>(context,
      MaterialPageRoute<CreateJobDraft>(
        builder: (_) => const CreateJobScreen(),
      ),
    );
    if (!mounted || draft == null) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Job draft created locally. Not saved to the server.'),
      ),
    );
  }

  void _notify(String label) {
    if (widget.onNotReady != null) {
      widget.onNotReady!(label);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$label will be available in a future screen.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final jobs = <JobModel>[
      ...widget.createdJobs.where(
        (job) => job.category == _category && job.matches(_search.text)),
      if (widget.includeDemoJobs && !MobileAuthRepository.shared.isSignedIn)
        ...MockJobsData.search(category: _category, query: _search.text),
    ];
    final categories = JobCategory.values;
    final labels = [
      for (final category in categories)
        '${switch (category) {
          JobCategory.active => 'Active',
          JobCategory.completed => 'Completed',
          JobCategory.archived => 'Archived',
        }} (${(widget.includeDemoJobs && !MobileAuthRepository.shared.isSignedIn ? MockJobsData.count(category) : 0) + widget.createdJobs.where(
          (job) => job.category == category,
        ).length})',
    ];
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth:
          MediaQuery.orientationOf(context) == Orientation.landscape
              ? double.infinity : 560),
        child: CustomScrollView(
          key: const Key('jobs-scroll'),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Sign2DigitalSearchField(
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                      onTrailingTap: () =>
                          FocusManager.instance.primaryFocus?.unfocus(),
                    ),
                    const SizedBox(height: 20),
                    Sign2DigitalDetailsTabs(
                      labels: labels,
                      selectedIndex: _category.index,
                      onSelected: (index) {
                        FocusManager.instance.primaryFocus?.unfocus();
                        setState(() => _category = categories[index]);
                      },
                    ),
                    const SizedBox(height: 20),
                    // Reuse the existing primary button without modifying its API.
                    // The icon and label are painted as one centered overlay.
                    Semantics(
                      label: 'Create Job',
                      button: true,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Sign2DigitalPrimaryButton(
                            key: const Key('create-job-button'),
                            label: '',
                            onPressed: () {
                              FocusManager.instance.primaryFocus?.unfocus();
                              if (widget.onCreateJob != null) {
                                widget.onCreateJob!();
                              } else {
                                _openCreateJob();
                              }
                            },
                          ),
                          const IgnorePointer(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.add,
                                  size: 24,
                                  color: AppColors.white,
                                ),
                                SizedBox(width: 10),
                                Text(
                                  'Create Job',
                                  style: AppTextStyles.primaryButton,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (widget.loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator(
                  color: AppColors.primary,
                )),
              )
            else if (widget.errorMessage != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(widget.errorMessage!,
                          style: AppTextStyles.subtitle,
                          textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: widget.onRetry,
                          child: const Text('Try Again'),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else if (jobs.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'No jobs found',
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
                  itemCount: jobs.length,
                  itemBuilder: (context, index) {
                    final job = jobs[index];
                    return Padding(
                      key: ValueKey(job.id),
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Sign2DigitalJobCard(
                        job: job,
                        onTap: () {
                          FocusManager.instance.primaryFocus?.unfocus();
                          if (widget.onJobTap != null) {
                            widget.onJobTap!(job);
                          } else {
                            _notify('Job Details');
                          }
                        },
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
