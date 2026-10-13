import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sign2digital_outlined_container.dart';

/// Shared document/quote summary for signing and completion screens.
class Sign2DigitalQuoteSummaryCard extends StatelessWidget {
  const Sign2DigitalQuoteSummaryCard({
    super.key,
    required this.quoteNumber,
    required this.projectName,
    this.subtitleGap = 5,
  });

  final String quoteNumber;
  final String projectName;
  final double subtitleGap;

  @override
  Widget build(BuildContext context) => Sign2DigitalOutlinedContainer(
    padding: const EdgeInsets.all(20),
    child: Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            color: Color(0xFFE3ECF0),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.description_outlined,
            color: AppColors.dark,
            size: 23,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Quote # $quoteNumber',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.3,
                  color: AppColors.dark,
                ),
              ),
              SizedBox(height: subtitleGap),
              Text(
                projectName,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.placeholder,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
