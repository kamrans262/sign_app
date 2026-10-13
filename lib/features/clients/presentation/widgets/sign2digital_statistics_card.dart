import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/dashboard_colors.dart';

class Sign2DigitalStatisticsCard extends StatelessWidget {
  const Sign2DigitalStatisticsCard({
    super.key,
    required this.count,
    required this.label,
    required this.fallbackIcon,
    this.iconAsset,
  });

  final int count;
  final String label;
  final IconData fallbackIcon;
  final String? iconAsset;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: AppColors.lightBorder),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(12),
      child: LayoutBuilder(
        builder: (context, box) {
          final compact = box.maxWidth < 175;
          final diameter = compact ? 39.0 : 50.0;
          return Row(
            children: [
              Container(
                width: diameter,
                height: diameter,
                decoration: const BoxDecoration(
                  color: DashboardColors.paleBlue,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: iconAsset != null
                      ? SvgPicture.asset(
                          iconAsset!,
                          width: 23,
                          height: 23,
                          colorFilter: const ColorFilter.mode(
                            AppColors.primary,
                            BlendMode.srcIn,
                          ),
                        )
                      : Icon(fallbackIcon, size: 23, color: AppColors.primary),
                ),
              ),
              SizedBox(width: compact ? 6 : 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$count',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                        fontSize: 18,
                        letterSpacing: -0.3,
                        color: AppColors.dark,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      label,
                      softWrap: false,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                        color: AppColors.placeholder,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
