// Sign2Digital Login UI Package — shared social/secondary button.
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_colors.dart';

class Sign2DigitalOutlinedButton extends StatelessWidget {
  const Sign2DigitalOutlinedButton({
    required this.label,
    required this.onPressed,
    this.iconAsset,
    this.leading,
    this.enabled = true,
    super.key,
  });

  final String label;
  final VoidCallback onPressed;
  final String? iconAsset;
  final Widget? leading;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.button),
        side: const BorderSide(color: AppColors.lightBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onPressed : null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Center(
              child: Row(
                // Use the available width as a firm constraint so the label
                // can wrap beside the brand icon at accessibility text sizes.
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (iconAsset != null || leading != null) ...[
                    if (leading != null)
                      leading!
                    else
                      SvgPicture.asset(
                        iconAsset!,
                        width: 20,
                        height: 20,
                        semanticsLabel: '$label logo',
                      ),
                    const SizedBox(width: 20),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.outlinedButton,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
