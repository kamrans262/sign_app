import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sign2digital_outlined_container.dart';

/// Shared local-image source choice used by Add Photos and future upload flows.
class Sign2DigitalPhotoSourceCard extends StatelessWidget {
  const Sign2DigitalPhotoSourceCard({
    super.key,
    required this.title,
    required this.description,
    required this.iconAsset,
    required this.onTap,
    this.enabled = true,
  });

  final String title;
  final String description;
  final String iconAsset;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(10),
        child: Sign2DigitalOutlinedContainer(
          constraints: const BoxConstraints(minHeight: 118),
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset(iconAsset, width: 24, height: 24),
              const SizedBox(height: 8),
              Text(
                title,
                maxLines: 2,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.dark,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                description,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.placeholder,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
