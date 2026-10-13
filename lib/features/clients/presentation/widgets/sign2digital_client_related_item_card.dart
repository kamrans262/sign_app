import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/client_details_model.dart';
import 'sign2digital_status_badge.dart';

class Sign2DigitalClientRelatedItemCard extends StatelessWidget {
  const Sign2DigitalClientRelatedItemCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  final ClientRelatedRecord item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.lightBorder),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.dark,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(item.description, style: _detailStyle),
                    const SizedBox(height: 5),
                    Text(item.meta, style: _detailStyle),
                  ],
                ),
              ),
              if (item.status != null) ...[
                const SizedBox(width: 8),
                Sign2DigitalStatusBadge(status: item.status!),
              ],
              const SizedBox(width: 6),
              const Icon(
                Icons.chevron_right,
                color: AppColors.secondaryText,
                size: 25,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static const _detailStyle = TextStyle(
    fontFamily: 'Inter',
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.placeholder,
  );
}
