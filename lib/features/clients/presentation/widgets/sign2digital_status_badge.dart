import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/dashboard_colors.dart';

class Sign2DigitalStatusBadge extends StatelessWidget {
  const Sign2DigitalStatusBadge({super.key, required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final colors = switch (status.toLowerCase()) {
      'active' => (const Color(0xFFC4F0D0), const Color(0xFF18733D)),
      'customer-facing' => (const Color(0xFFC4F0D0), const Color(0xFF18733D)),
      'quote' => (DashboardColors.paleBlue, AppColors.primary),
      'in progress' => (const Color(0xFFFFE9E9), const Color(0xFFB42318)),
      'draft' => (const Color(0xFFFFF0F0), const Color(0xFFF04438)),
      'approved' || 'reimbursed' =>
        (const Color(0xFFC4F0D0), const Color(0xFF18733D)),
      'paid' => (const Color(0xFFC4F0D0), const Color(0xFF18733D)),
      'sent for signature' || 'signed' || 'completed' =>
        (const Color(0xFFC4F0D0), const Color(0xFF18733D)),
      _ => (DashboardColors.paleBlue, AppColors.primary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colors.$1,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Text(
        status,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: colors.$2,
        ),
      ),
    );
  }
}
