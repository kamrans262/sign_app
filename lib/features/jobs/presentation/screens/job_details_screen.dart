import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:printing/printing.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/sign2digital_bottom_navigation_bar.dart';
import '../../../../core/widgets/sign2digital_header.dart';
import '../../../../core/widgets/sign2digital_selection_sheet.dart';
import '../../domain/job_details_model.dart';
import 'job_photos_screen.dart';
import 'job_notes_screen.dart';
import '../../domain/job_model.dart';
import '../../../quotes/presentation/screens/create_quote_screen.dart';
import '../../../quotes/data/remote_quote_repository.dart';
import '../../../quotes/presentation/screens/review_quote_screen.dart';
import '../../../quotes/presentation/screens/quote_preview_screen.dart';
import '../../../documents/presentation/screens/documents_screen.dart';
import '../../../documents/presentation/screens/reports_screen.dart';
import '../../../documents/domain/document_record.dart';
import '../../../quotes/data/signed_quote_file_store.dart';
import '../../../documents/data/remote_signed_document_repository.dart';
import '../../../clients/domain/client_profile.dart';
import '../widgets/sign2digital_job_financial_card.dart';
import '../widgets/sign2digital_job_progress_indicator.dart';
import '../widgets/sign2digital_job_section_card.dart';
import '../widgets/sign2digital_job_status_badge.dart';
import '../widgets/sign2digital_remaining_balance_card.dart';

/// Job-specific details on a separate route. The underlying dashboard shell
/// keeps its selected filter/search state and bottom bar is never duplicated.
class JobDetailsScreen extends StatelessWidget {
  const JobDetailsScreen({
    super.key,
    required this.job,
    this.details,
    this.onSectionTap,
    this.onTabSelected,
    this.companyId,
    this.client,
    this.onManageJob,
  });

  final JobModel job;
  final JobDetailsModel? details;
  final ValueChanged<JobSection>? onSectionTap;
  final ValueChanged<int>? onTabSelected;
  /// Selected issuer from the dashboard; null for independent previews.
  final String? companyId;
  /// Resolved from the real local client ID, never a name-only match.
  final ClientProfile? client;
  /// Only supplied for authenticated, persisted jobs. Demo layout unchanged.
  final Future<bool> Function(JobModel job, String action)? onManageJob;

  Future<void> _showJobActions(BuildContext context) async {
    final manage = onManageJob;
    if (manage == null) return;
    final options = job.category == JobCategory.archived
        ? const ['Restore Job']
        : <String>[
            'Edit Job',
            if (job.stage == JobStage.planning) 'Start Job',
            if (job.stage == JobStage.inProgress ||
                job.stage == JobStage.overdue) 'Set to Planning',
            if (job.category == JobCategory.completed) 'Reopen Job',
            if (job.category != JobCategory.completed) 'Mark Completed',
            'Archive Job',
          ];
    var action = await Sign2DigitalSelectionSheet.show(
      context, title: 'Manage Job', icon: Icons.work_outline,
      subtitle: job.referenceNumber, options: options,
    );
    if (!context.mounted || action == null) return;
    if (action == 'Archive Job') {
      final confirmation = await Sign2DigitalSelectionSheet.show(
        context, title: 'Archive Job',
        icon: Icons.archive_outlined,
        subtitle: 'This job can be restored later.',
        options: const ['Cancel', 'Archive Job'],
      );
      if (!context.mounted || confirmation != 'Archive Job') return;
    }
    final updated = await manage(job, action);
    if (context.mounted && updated) {
      Navigator.of(context).pop();
    }
  }


  Future<void> _openSection(BuildContext context, JobSection section) async {
    if (onSectionTap != null) {
      onSectionTap!(section);
      return;
    }
    if (section == JobSection.quotes) {
      // Offer existing real quotes without replacing the original Create Quote
      // route or introducing a separate, inconsistent UI design.
      if (onManageJob != null) {
        try {
          final saved = await RemoteQuoteRepository.shared.listQuotes(jobId:job.id);
          if (!context.mounted) return;
          final visible = saved.where((quote) =>
              quote.serverStatus != 'archived').toList();
          if (visible.isNotEmpty) {
            String optionFor(int index) =>
                '${visible[index].quoteNumber} — ${visible[index].serverStatus}';
            final options = [
              'Create New Quote',
              for (var i = 0; i < visible.length; i++) optionFor(i),
            ];
            final choice = await Sign2DigitalSelectionSheet.show(
              context,
              title: 'Job Quotes',
              subtitle: job.referenceNumber,
              icon: Icons.description_outlined,
              options: options,
            );
            if (!context.mounted || choice == null) return;
            if (choice != 'Create New Quote') {
              final index = options.indexOf(choice) - 1;
              if (index >= 0 && index < visible.length) {
                final selected = visible[index];
                Navigator.of(context).push<void>(MaterialPageRoute<void>(
                  builder: (_) => selected.approvedLocally
                      ? QuotePreviewScreen(quote: selected)
                      : ReviewQuoteScreen(initialDraft: selected),
                ));
              }
              return;
            }
          }
        } catch (error) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Could not load saved quotes: $error'),
          ));
        }
      }
      Navigator.of(context).push<void>(MaterialPageRoute<void>(
        builder: (_) => CreateQuoteScreen(
          jobId: job.id,
          clientId: job.clientId,
          clientName: client?.id == job.clientId
              ? client!.companyName : job.clientName,
          clientEmail: client?.id == job.clientId ? client!.email : null,
          clientPhone: client?.id == job.clientId ? client!.phone : null,
          clientAddress: client?.id == job.clientId ? client!.address : null,
          companyId: companyId,
        ),
      ));
      return;
    }
    if (section == JobSection.addenda) {
      await Navigator.of(context).push<void>(MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(child: Column(children: [
            Sign2DigitalHeader(
              title: 'Addenda',
              onBack: () => Navigator.of(context).maybePop(),
            ),
            Expanded(child: DocumentsScreen(
              initialCategory: DocumentCategory.addends,
              jobId: job.id,
            )),
          ])),
        ),
      ));
      return;
    }
    if (section == JobSection.documents) {
      // Authenticated jobs always use server-verified signed PDF metadata,
      // never client-side demo files or inferred signing status.
      if (onManageJob != null) {
        try {
          final signed = await RemoteSignedDocumentRepository.shared.list(
            jobId: job.id,
          );
          if (!context.mounted) return;
          if (signed.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('No signed documents for this job yet.'),
            ));
            return;
          }
          await showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            builder: (sheetContext) => SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Signed Job Documents',
                      style: TextStyle(fontSize: 18,
                          fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    for (final file in signed)
                      ListTile(
                        key: Key('signed-job-document-${file.documentId}'),
                        leading: const Icon(Icons.picture_as_pdf_outlined),
                        title: Text(file.quoteNumber),
                        subtitle: Text('Signed ${file.signedAt.toLocal()}'),
                        onTap: () async {
                          try {
                            final bytes=await RemoteSignedDocumentRepository.shared
                                .download(file);
                            await Printing.sharePdf(
                              bytes:bytes,
                              filename:'Signed_${file.documentId}.pdf',
                            );
                          } catch (_) {
                            if (!sheetContext.mounted) return;
                            ScaffoldMessenger.of(sheetContext).showSnackBar(
                              const SnackBar(content:Text(
                                'Could not open this signed PDF.')),
                            );
                          }
                        },
                      ),
                  ],
                ),
              ),
            ),
          );
        } catch (_) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not load signed job documents.'),
          ));
        }
        return;
      }
      // Preserve the existing card layout; only show signed PDFs when a
      // verified document has actually been indexed under this job ID.
      try {
        final signed = await SignedQuoteFileStore.shared.forJob(job.id);
        if (!context.mounted) return;
        if (signed.isNotEmpty) {
          await showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            builder: (sheetContext) => SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Signed Job Documents',
                      style: TextStyle(fontSize: 18,
                          fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    for (final file in signed)
                      ListTile(
                        key: Key('signed-job-document-${file.documentId}'),
                        leading: const Icon(Icons.picture_as_pdf_outlined),
                        title: Text(file.quoteNumber),
                        subtitle: Text('Signed ${file.signedAt.toLocal()}'),
                        onTap: () async {
                          try {
                            final bytes = await SignedQuoteFileStore.shared.read(file);
                            await Printing.sharePdf(
                              bytes: bytes,
                              filename: 'Signed_${file.fileName}',
                            );
                          } catch (_) {
                            if (!sheetContext.mounted) return;
                            ScaffoldMessenger.of(sheetContext).showSnackBar(
                              const SnackBar(content: Text(
                                'Could not open this signed PDF.')),
                            );
                          }
                        },
                      ),
                  ],
                ),
              ),
            ),
          );
          return;
        }
      } catch (_) {
        // Leave the original placeholder intact if local storage is unavailable.
      }
      if (!context.mounted) return;
    }
    if (section == JobSection.siteReports) {
      await Navigator.of(context).push<void>(MaterialPageRoute<void>(
        builder: (_) => ReportsScreen(
          jobId: int.tryParse(job.id) != null ? job.id : null,
          onNavigationSelected: (index) => _selectTab(context, index),
        ),
      ));
      return;
    }
    if (section == JobSection.photos) {
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => JobPhotosScreen(
            job: job,
            onTabSelected: (index) => _selectTab(context, index),
          ),
        ),
      );
      return;
    }
    if (section == JobSection.notes) {
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => JobNotesScreen(
            job: job,
            onTabSelected: (index) => _selectTab(context, index),
          ),
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${section.label} is not connected yet.')),
    );
  }

  void _selectTab(BuildContext context, int index) {
    if (index == 1) return;
    if (onTabSelected != null) {
      onTabSelected!(index);
    } else {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = details ?? (int.tryParse(job.id) != null
        ? JobDetailsModel.liveUnconnected(job)
        : JobDetailsModel.demoFor(job));
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Sign2DigitalHeader(
              title: job.title,
              onBack: () => Navigator.of(context).maybePop(),
              trailing: onManageJob == null ? null : SizedBox(
                width: 40, height: 40,
                child: Material(
                  color: AppColors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: const BorderSide(color: AppColors.lightBorder),
                  ),
                  child: IconButton(
                    key: const Key('manage-job-action'),
                    tooltip: 'Manage Job',
                    padding: EdgeInsets.zero,
                    onPressed: () => _showJobActions(context),
                    icon: const Icon(Icons.more_horiz_rounded,
                      color: AppColors.primary, size: 22),
                  ),
                ),
              ),
            ),
            Expanded(
              child: SizedBox(
                width: double.infinity,
                child: SingleChildScrollView(
                  key: const Key('job-details-scroll'),
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _JobSummary(job: job),
                      const SizedBox(height: 15),
                      const Text(
                        'Job Progress',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.dark,
                        ),
                      ),
                      const SizedBox(height: 9),
                      Sign2DigitalJobProgressIndicator(
                        percentage: job.progressPercentage,
                        percentageColor: AppColors.primary,
                      ),
                      const SizedBox(height: 25),
                      _ResponsiveCardGrid(
                        count: 6,
                        builder: (index) => switch (index) {
                          0 => Sign2DigitalJobFinancialCard(
                            label: 'Quote amount',
                            amountChf: data.quoteAmountChf,
                            showAmount: data.financialsAvailable,
                            icon: Icons.description_outlined,
                            iconAsset: 'assets/icons/description.svg',
                          ),
                          1 => Sign2DigitalJobFinancialCard(
                            label: 'Expenses',
                            amountChf: data.expensesChf,
                            showAmount: data.financialsAvailable,
                            icon: Icons.shopping_cart_outlined,
                          ),
                          2 => Sign2DigitalJobFinancialCard(
                            label: 'Labour cost',
                            amountChf: data.labourCostChf,
                            showAmount: data.financialsAvailable,
                            icon: Icons.groups_outlined,
                            iconAsset: 'assets/icons/team_members.svg',
                          ),
                          3 => Sign2DigitalJobFinancialCard(
                            label: 'Deposits',
                            amountChf: data.depositsChf,
                            showAmount: data.financialsAvailable,
                            icon: Icons.savings_outlined,
                          ),
                          4 => Sign2DigitalJobFinancialCard(
                            label: 'Invoiced',
                            amountChf: data.invoicedChf,
                            showAmount: data.financialsAvailable,
                            icon: Icons.description_outlined,
                            iconAsset: 'assets/icons/doc_numbering.svg',
                          ),
                          _ => Sign2DigitalJobFinancialCard(
                            label: 'Received',
                            amountChf: data.receivedChf,
                            showAmount: data.financialsAvailable,
                            icon: Icons.check_circle,
                          ),
                        },
                      ),
                      const SizedBox(height: 20),
                      Sign2DigitalRemainingBalanceCard(
                        balanceChf: data.remainingBalanceChf,
                        showAmount: data.financialsAvailable,
                      ),
                      const SizedBox(height: 20),
                      _ResponsiveCardGrid(
                        count: data.sections.length,
                        builder: (index) => Sign2DigitalJobSectionCard(
                          details: data.sections[index],
                          onTap: () => _openSection(
                            context,
                            data.sections[index].section,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Sign2DigitalBottomNavigationBar(
        selectedIndex: 1,
        onSelected: (index) => _selectTab(context, index),
      ),
    );
  }
}

/// Lays out entire rows at their natural content height instead of forcing
/// every card into an 82px GridView cell. At the reference width, compact
/// one-line cards retain the 82px minimum; a wrapped label can grow without
/// clipping. IntrinsicHeight keeps both cards in a row the same height.
class _ResponsiveCardGrid extends StatelessWidget {
  const _ResponsiveCardGrid({required this.count, required this.builder});

  final int count;
  final Widget Function(int index) builder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 335
            ? 1
            : constraints.maxWidth >= 1040
            ? 4
            : constraints.maxWidth >= 700
            ? 3
            : 2;
        final rowCount = (count + columns - 1) ~/ columns;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var row = 0; row < rowCount; row++) ...[
              if (row > 0) const SizedBox(height: 16),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var column = 0; column < columns; column++) ...[
                      if (column > 0) const SizedBox(width: 12),
                      Expanded(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 82),
                          child: row * columns + column < count
                              ? builder(row * columns + column)
                              : const SizedBox.shrink(),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _JobSummary extends StatelessWidget {
  const _JobSummary({required this.job});

  final JobModel job;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final imageWidth = constraints.maxWidth < 310 ? 88.0 : 106.0;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                job.imageAsset,
                key: Key('job-detail-image-${job.id}'),
                width: imageWidth,
                height: 90,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: imageWidth,
                  height: 90,
                  color: const Color(0xFFE3ECF0),
                  alignment: Alignment.center,
                  child: const Icon(Icons.image_outlined),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: LayoutBuilder(
                builder: (context, available) {
                  final title = Text(
                    job.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.fieldLabel,
                  );
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (available.maxWidth >= 245)
                        Row(
                          children: [
                            Expanded(child: title),
                            const SizedBox(width: 6),
                            Sign2DigitalJobStatusBadge(stage: job.stage),
                          ],
                        )
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 5,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            title,
                            Sign2DigitalJobStatusBadge(stage: job.stage),
                          ],
                        ),
                      const SizedBox(height: 5),
                      Text(
                        job.clientName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          letterSpacing: -0.3,
                          color: AppColors.placeholder,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 12,
                        runSpacing: 5,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            job.referenceNumber,
                            maxLines: 1,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.placeholder,
                            ),
                          ),
                          SizedBox(
                            width: math.min(available.maxWidth, 165.0),
                            child: Row(
                              children: [
                                SvgPicture.asset(
                                  'assets/icons/calendar-outlined.svg',
                                  width: 14,
                                  height: 14,
                                  colorFilter: const ColorFilter.mode(
                                    AppColors.placeholder,
                                    BlendMode.srcIn,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    job.formattedDueDate,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontWeight: FontWeight.w500,
                                      fontSize: 13,
                                      color: AppColors.placeholder,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
