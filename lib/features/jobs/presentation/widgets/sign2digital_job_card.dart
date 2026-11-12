import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/sign2digital_outlined_container.dart';
import '../../domain/job_model.dart';
import 'sign2digital_job_progress_indicator.dart';
import 'sign2digital_job_status_badge.dart';

/// Reusable Jobs-list card. The status chip is top-right, while the chevron is
/// centered against the entire card's height rather than the title row.
class Sign2DigitalJobCard extends StatelessWidget {
  const Sign2DigitalJobCard({
    super.key,
    required this.job,
    required this.onTap,
  });

  final JobModel job;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${job.title}, ${job.statusLabel}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Sign2DigitalOutlinedContainer(
            padding: const EdgeInsets.all(15),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 320;
                final imageWidth = compact ? 74.0 : 106.0;
                final imageHeight = compact ? 80.0 : 90.0;
                // The arrow's area is excluded from the text and progress bar.
                final badgeReserve = compact
                    ? 0.0
                    : math.max(0.0, _badgeReserve(job.stage) - 35);
                return Stack(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.asset(
                            job.imageAsset,
                            key: Key('job-image-${job.id}'),
                            width: imageWidth,
                            height: imageHeight,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                                  width: imageWidth,
                                  height: imageHeight,
                                  color: const Color(0xFFE3ECF0),
                                  alignment: Alignment.center,
                                  child: const Icon(
                                    Icons.image_outlined,
                                    color: AppColors.secondaryText,
                                  ),
                                ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (compact) const SizedBox(height: 30),
                                Padding(
                                  padding: EdgeInsets.only(right: badgeReserve),
                                  child: Text(
                                    job.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTextStyles.fieldLabel,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  job.clientName,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: -0.3,
                                    color: AppColors.placeholder,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  job.formattedAmount,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: -0.3,
                                    color: AppColors.dark,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Sign2DigitalJobProgressIndicator(
                                  percentage: job.progressPercentage,
                                ),
                                const SizedBox(height: 5),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.calendar_today_outlined,
                                      size: 15,
                                      color: AppColors.placeholder,
                                    ),
                                    const SizedBox(width: 5),
                                    Expanded(
                                      child: Text(
                                        job.formattedDueDate,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.placeholder,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Sign2DigitalJobStatusBadge(stage: job.stage),
                    ),
                    const Positioned.fill(
                      child: IgnorePointer(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Icon(
                            Icons.chevron_right,
                            size: 23,
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  static double _badgeReserve(JobStage stage) {
    return switch (stage) {
      JobStage.inProgress => 120,
      JobStage.planning => 89,
      JobStage.completed => 108,
      JobStage.overdue => 100,
    };
  }
}
