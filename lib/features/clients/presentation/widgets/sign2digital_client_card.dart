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
                    Text(
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
                    ),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: DashboardColors.paleBlue,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Text(
                          '${client.jobCount} ${client.jobCount == 1 ? 'job' : 'jobs'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 10,
                            letterSpacing: -0.3,
                            fontWeight: FontWeight.w500,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
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
