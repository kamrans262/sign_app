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
    this.horizontalPadding = 20,
    this.textColor = AppColors.primary,
    this.iconSize = 20,
    this.iconGap = 12,
    this.fontSize = 13,
    this.title,
    this.leadingIcon,
    this.titleColor = AppColors.dark,
  });

  final String message;
  final String iconAsset;
  final double verticalPadding;
  final double horizontalPadding;
  final Color textColor;
  final double iconSize;
  final double iconGap;
  final double fontSize;
  final String? title;
  final IconData? leadingIcon;
  final Color titleColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: DashboardColors.paleBlue,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding, vertical: verticalPadding),
        child: Row(
          children: [
            if (leadingIcon != null)
              Icon(leadingIcon, size: iconSize, color: AppColors.primary)
            else
              SvgPicture.asset(
                iconAsset,
                width: iconSize,
                height: iconSize,
                colorFilter: const ColorFilter.mode(
                  AppColors.primary,
                  BlendMode.srcIn,
                ),
              ),
            SizedBox(width: iconGap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null) ...[
                    Text(title!, style: TextStyle(
                      fontFamily: 'Inter', fontSize: 14,
                      fontWeight: FontWeight.w600, color: titleColor,
                    )),
                    const SizedBox(height: 5),
                  ],
                  Text(
                    message,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: fontSize,
                      fontWeight: FontWeight.w400,
                      letterSpacing: -0.3,
                      color: textColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
