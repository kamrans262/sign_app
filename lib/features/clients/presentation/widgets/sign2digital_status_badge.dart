import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/dashboard_colors.dart';

class Sign2DigitalStatusBadge extends StatelessWidget {
  const Sign2DigitalStatusBadge({super.key, required this.status});
  final String status;

  /// Display-only normalization. API, filters and saved statuses stay intact.
  static String displayLabel(String value) {
    final clean = value.trim().replaceAll(RegExp(r'[_]+'), ' ')
        .replaceAll(RegExp(r'\\s+'), ' ');
    if (clean.isEmpty) return '';
    const acronyms = {'pdf', 'ai', 'vat', 'qr', 'id'};
    return clean.split(' ').map((part) {
      if (part.isEmpty) return part;
      if (acronyms.contains(part.toLowerCase())) {
        return part.toUpperCase();
      }
      if (part.length > 1 && part == part.toUpperCase()) {
        return part;
      }
      return '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}';
    }).join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final colors = switch (status.trim().toLowerCase()
        .replaceAll(RegExp(r'[_]+'), ' ')) {
      'active' => (const Color(0xFFC4F0D0), const Color(0xFF18733D)),
      'customer-facing' => (const Color(0xFFC4F0D0), const Color(0xFF18733D)),
      'quote' => (DashboardColors.paleBlue, AppColors.primary),
      'in progress' => (const Color(0xFFFFE9E9), const Color(0xFFB42318)),
      'draft' => (const Color(0xFFFFF0F0), const Color(0xFFF04438)),
      'approved' || 'reimbursed' || 'received' =>
        (const Color(0xFFC4F0D0), const Color(0xFF18733D)),
      'today' || 'in use' || 'available' || 'paid' || 'generated' =>
        (const Color(0xFFC4F0D0), const Color(0xFF18733D)),
      'payment pending' || 'pending' =>
        (const Color(0xFFF0F2F4), AppColors.placeholder),
      'maintenance' =>
        (const Color(0xFFFFE9E9), const Color(0xFFB42318)),
      'overdue' => (const Color(0xFFFFE9E9), const Color(0xFFB42318)),
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
        displayLabel(status),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: colors.$2,
        ),
      ),
    );
  }
}
