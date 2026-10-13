import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/dashboard_colors.dart';
import '../../../../core/widgets/sign2digital_outlined_container.dart';
import '../../domain/job_details_model.dart';

/// A single Figma financial card; its value is supplied by the caller.
class Sign2DigitalJobFinancialCard extends StatelessWidget {
  const Sign2DigitalJobFinancialCard({
    super.key,
    required this.label,
    required this.amountChf,
    required this.icon,
    this.iconAsset,
  });

  final String label;
  final int amountChf;
  final IconData icon;
  final String? iconAsset;

  @override
  Widget build(BuildContext context) {
    return Sign2DigitalOutlinedContainer(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: DashboardColors.paleBlue,
            ),
            child: Center(
              child: iconAsset == null
                  ? Icon(icon, size: 22, color: AppColors.primary)
                  : SvgPicture.asset(
                      iconAsset!,
                      width: 22,
                      height: 22,
                      colorFilter: const ColorFilter.mode(
                        AppColors.primary,
                        BlendMode.srcIn,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                    letterSpacing: -0.3,
                    color: AppColors.placeholder,
                  ),
                ),
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    JobDetailsModel.formatChf(amountChf),
                    maxLines: 1,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      letterSpacing: -0.3,
                      color: AppColors.dark,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
