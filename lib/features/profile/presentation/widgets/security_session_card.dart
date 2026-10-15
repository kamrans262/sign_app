import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/dashboard_colors.dart';
import '../../../clients/presentation/widgets/sign2digital_status_badge.dart';
import '../../../quotes/presentation/widgets/sign2digital_quote_shadow_panel.dart';
import '../../data/security_access_repository.dart';

/// Reuses the same light-border shadow and 40px icon treatment as Profile.
class SecuritySessionCard extends StatelessWidget {
  const SecuritySessionCard({
    super.key,
    required this.session,
    this.onTap,
  });

  final SecurityDeviceSession session;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Sign2DigitalQuoteShadowPanel(
    clip: true,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: DashboardColors.paleBlue,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  session.isMobile
                      ? Icons.phonelink_rounded
                      : Icons.laptop_mac_outlined,
                  size: 24,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(session.deviceName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Inter', fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.3,
                      color: AppColors.dark,
                    )),
                  const SizedBox(height: 5),
                  Text(session.location, style: const TextStyle(
                    fontFamily: 'Inter', fontSize: 12,
                    color: AppColors.placeholder,
                  )),
                  Text(session.agentAndLastSeen, style: const TextStyle(
                    fontFamily: 'Inter', fontSize: 12,
                    color: AppColors.placeholder,
                  )),
                ],
              )),
              const SizedBox(width: 8),
              if (session.isCurrent)
                const Sign2DigitalStatusBadge(status: 'Current')
              else
                const Icon(Icons.chevron_right_rounded,
                  size: 24, color: AppColors.secondaryText),
            ],
          ),
        ),
      ),
    ),
  );
}
