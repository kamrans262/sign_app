import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/dashboard_colors.dart';
import '../../domain/client_profile.dart';

class Sign2DigitalClientCard extends StatelessWidget {
  const Sign2DigitalClientCard({super.key, required this.client, this.onTap});

  final ClientProfile client;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: AppColors.lightBorder),
        borderRadius: BorderRadius.circular(10),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 27,
                backgroundColor: DashboardColors.paleBlue,
                backgroundImage: client.logoAsset != null
                    ? AssetImage(client.logoAsset!)
                    : null,
                child: client.logoAsset == null
                    ? Text(
                        client.initials,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        // Keep the jobs badge on the title row, while allowing
                        // a vertical fallback for very narrow / enlarged text.
                        final companyName = Text(
                          client.companyName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 16,
                            letterSpacing: -0.3,
                            fontWeight: FontWeight.w600,
                            color: AppColors.dark,
                          ),
                        );
                        final jobsBadge = Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: DashboardColors.paleBlue,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Text(
                            '${client.jobCount} ${client.jobCount == 1 ? 'job' : 'jobs'}',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              letterSpacing: -0.3,
                              fontWeight: FontWeight.w500,
                              color: AppColors.primary,
                            ),
                          ),
                        );
                        final compact =
                            constraints.maxWidth < 150 ||
                            MediaQuery.textScalerOf(context).scale(12) > 18;
                        if (compact) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              companyName,
                              const SizedBox(height: 6),
                              jobsBadge,
                            ],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(child: companyName),
                            const SizedBox(width: 8),
                            jobsBadge,
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 5),
                    Text(
                      client.companyType,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _detailStyle,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      client.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _detailStyle,
                    ),
                    Text(
                      client.phone,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _detailStyle,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 7),
              const Icon(
                Icons.chevron_right,
                size: 25,
                color: AppColors.secondaryText,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static const _detailStyle = TextStyle(
    fontFamily: 'Inter',
    fontWeight: FontWeight.w500,
    fontSize: 14,
    color: AppColors.placeholder,
  );
}
