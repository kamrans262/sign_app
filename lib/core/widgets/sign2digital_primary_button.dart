// Sign2Digital Login UI Package — shared brand-primary button.
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

class Sign2DigitalPrimaryButton extends StatelessWidget {
  const Sign2DigitalPrimaryButton({
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.enabled = true,
    this.height = 48,
    this.leading,
    super.key,
  });

  final String label;
  final VoidCallback onPressed;
  final bool loading;
  final bool enabled;
  final double height;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: FilledButton(
        onPressed: enabled && !loading ? onPressed : null,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.white,
          disabledBackgroundColor: AppColors.primary.withAlpha(115),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
        ),
        child: loading
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.white,
                ),
              )
            : leading == null
                ? Text(label, style: AppTextStyles.primaryButton)
                : Row(mainAxisSize: MainAxisSize.min, children: [
                    leading!,
                    const SizedBox(width: 10),
                    Flexible(child: Text(label,
                      maxLines: 2, textAlign: TextAlign.center,
                      style: AppTextStyles.primaryButton)),
                  ]),
      ),
    );
  }
}
