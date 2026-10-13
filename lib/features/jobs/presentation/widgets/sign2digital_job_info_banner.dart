import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Reusable contextual banner; dismissing hides it without mutating the job.
class Sign2DigitalJobInfoBanner extends StatelessWidget {
  const Sign2DigitalJobInfoBanner({
    super.key,
    required this.title,
    required this.description,
    this.icon,
    this.onDismiss,
  });

  final String title;
  final String description;
  final Widget? icon;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 72),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0x1A8A9AA8),
        border: Border.all(color: AppColors.lightBorder),
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 24)],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Color(0x0D000000),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            alignment: Alignment.center,
            child:
                icon ??
                const Icon(
                  Icons.picture_as_pdf_rounded,
                  color: Color(0xFFEA454B),
                  size: 23,
                ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.dark,
                  ),
                ),
                if (description.trim().isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.placeholder,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onDismiss != null) ...[
            const SizedBox(width: 6),
            IconButton(
              key: const Key('job-photo-dismiss-banner'),
              tooltip: 'Dismiss job information',
              onPressed: onDismiss,
              icon: const Icon(Icons.close, size: 20, color: Colors.black),
            ),
          ],
        ],
      ),
    );
  }
}
