import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_colors.dart';
import '../theme/dashboard_colors.dart';

class Sign2DigitalInfoBanner extends StatelessWidget {
  const Sign2DigitalInfoBanner({
    super.key,
    required this.message,
    this.iconAsset = 'assets/icons/info-circle-filled.svg',
    this.verticalPadding = 20,
    this.textColor = AppColors.primary,
  });

  final String message;
  final String iconAsset;
  final double verticalPadding;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: DashboardColors.paleBlue,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: verticalPadding),
        child: Row(
          children: [
            SvgPicture.asset(
              iconAsset,
              width: 20,
              height: 20,
              colorFilter: const ColorFilter.mode(
                AppColors.primary,
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  letterSpacing: -0.3,
                  color: textColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
