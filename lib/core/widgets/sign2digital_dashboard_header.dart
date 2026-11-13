import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../assets/dashboard_assets.dart';
import '../theme/app_colors.dart';
import '../../features/support/presentation/support_assistant_launcher.dart';

class Sign2DigitalDashboardHeader extends StatelessWidget {
  const Sign2DigitalDashboardHeader({
    super.key,
    this.onNotificationTap,
    this.onProfileTap,
    this.onSupportTap,
    this.profileImage,
  });

  final VoidCallback? onNotificationTap;
  // Retained only to avoid breaking older caller constructors. The profile
  // avatar is intentionally replaced with AI Support in all dashboard headers.
  final VoidCallback? onProfileTap;
  final VoidCallback? onSupportTap;
  final ImageProvider<Object>? profileImage;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Image.asset(
                DashboardAssets.headerLogo,
                width: 165,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Text(
                  'Sign2Digital',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.dark,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 48,
            height: 48,
            child: Material(
              color: AppColors.white,
              shape: const CircleBorder(
                side: BorderSide(color: AppColors.lightBorder),
              ),
              elevation: 1,
              shadowColor: const Color(0x05000000),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onNotificationTap,
                child: Center(
                  child: SvgPicture.asset(
                    DashboardAssets.bellIcon,
                    width: 24,
                    height: 24,
                    semanticsLabel: 'Notifications',
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 48,
            height: 48,
            child: Material(
              color: AppColors.white,
              shape: const CircleBorder(
                side: BorderSide(color: AppColors.lightBorder),
              ),
              elevation: 1,
              shadowColor: const Color(0x05000000),
              child: InkWell(
                key: const Key('dashboard-support-button'),
                customBorder: const CircleBorder(),
                onTap: onSupportTap ?? () =>
                    SupportAssistantLauncher.show(context, screen: 'home'),
                child: const Center(
                  child: Icon(Icons.support_agent_outlined,
                    size: 24, color: AppColors.primary),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
