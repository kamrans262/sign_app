import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/dashboard_colors.dart';
import '../../../quotes/presentation/widgets/sign2digital_quote_shadow_panel.dart';

/// Shared action card; all five profile settings rows have identical styling.
class ProfileSettingsActionCard extends StatelessWidget {
  const ProfileSettingsActionCard({
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
    child: Material(
      color: Colors.transparent,
      child: Semantics(
        button: true,
        label: title,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            child: Row(children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: DashboardColors.paleBlue,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 24, color: AppColors.primary),
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
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    letterSpacing: -0.3,
                    color: AppColors.placeholder,
                  )),
                ],
              )),
              const SizedBox(width: 10),
              const Icon(
                Icons.chevron_right_rounded,
                size: 24,
                color: AppColors.secondaryText,
              ),
            ]),
          ),
        ),
      ),
    ),
  );
}
