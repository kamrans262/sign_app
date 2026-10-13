import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class Sign2DigitalJobProgressIndicator extends StatelessWidget {
  const Sign2DigitalJobProgressIndicator({
    super.key,
    required this.percentage,
    this.percentageColor = AppColors.placeholder,
    this.barHeight = 5,
    this.labelGap = 5,
  });

  final double percentage;
  final Color percentageColor;
  final double barHeight;
  final double labelGap;

  @override
  Widget build(BuildContext context) {
    final progress = percentage.isFinite
        ? percentage.clamp(0.0, 100.0).toDouble()
        : 0.0;
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: barHeight,
              child: LinearProgressIndicator(
                value: progress / 100,
                backgroundColor: const Color(0xFFE9EDF0),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.primary,
                ),
                minHeight: barHeight,
              ),
            ),
          ),
        ),
        SizedBox(width: labelGap),
        Text(
          '${progress.round()}%',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: percentageColor,
          ),
        ),
      ],
    );
  }
}
