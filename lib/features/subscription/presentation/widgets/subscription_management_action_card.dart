import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/dashboard_colors.dart';
import '../../../quotes/presentation/widgets/sign2digital_quote_shadow_panel.dart';

/// All five management actions share a single surface and icon treatment.
class SubscriptionManagementActionCard extends StatelessWidget {
  const SubscriptionManagementActionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Sign2DigitalQuoteShadowPanel(
    clip: true,
    child: Semantics(
      button: true,
      label: title,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: DashboardColors.paleBlue,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 15),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.3,
                      color: AppColors.dark,
                    )),
                    const SizedBox(height: 5),
                    Text(subtitle, style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.placeholder,
                    )),
                  ],
                )),
                const SizedBox(width: 10),
                const Icon(Icons.chevron_right_rounded,
                  size: 24, color: AppColors.secondaryText),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
