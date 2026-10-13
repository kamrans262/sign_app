import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/job_model.dart';

/// A single reusable status appearance for job lifecycle stages.
/// Kept inside the Jobs feature to preserve customized global status badges.
class Sign2DigitalJobStatusBadge extends StatelessWidget {
  const Sign2DigitalJobStatusBadge({super.key, required this.stage});

  final JobStage stage;

  @override
  Widget build(BuildContext context) {
    final (label, background, foreground) = switch (stage) {
      JobStage.inProgress => (
        'In progress',
        const Color(0xFFE3ECF0),
        AppColors.primary,
      ),
      JobStage.planning => (
        'Planning',
        const Color(0xFFFFEEEE),
        const Color(0xFFF04438),
      ),
      JobStage.completed => (
        'Completed',
        const Color(0xFFC4F0D0),
        const Color(0xFF18733D),
      ),
      JobStage.overdue => (
        'Over due',
        const Color(0xFFFFD7D9),
        const Color(0xFFFA2D36),
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: foreground,
        ),
      ),
    );
  }
}
