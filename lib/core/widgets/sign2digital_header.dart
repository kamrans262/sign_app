// Sign2Digital Login UI Package — geometrically centered header.
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

class Sign2DigitalHeader extends StatelessWidget {
  const Sign2DigitalHeader({
    this.title,
    this.logoAsset,
    this.showBackButton = true,
    this.onBack,
    this.trailing,
    this.height = 109,
    super.key,
  });

  final String? title;
  final String? logoAsset;
  final bool showBackButton;
  final VoidCallback? onBack;
  final Widget? trailing;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.white,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final logoWidth = (constraints.maxWidth - 136)
                .clamp(100.0, 186.0)
                .toDouble();
            return Stack(
              alignment: Alignment.center,
              children: [
                if (logoAsset != null)
                  Image.asset(
                    logoAsset!,
                    width: logoWidth,
                    height: 55,
                    fit: BoxFit.contain,
                    semanticLabel: 'Sign2Digital',
                  )
                else if (title != null)
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: (constraints.maxWidth - 140)
                          .clamp(120.0, 400.0)
                          .toDouble(),
                    ),
                    child: Text(
                      title!,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.heading,
                    ),
                  ),
                if (showBackButton)
                  Positioned(
                    left: AppSpacing.screenHorizontal,
                    child: _HeaderBackButton(
                      onPressed:
                          onBack ??
                          () {
                            final navigator = Navigator.maybeOf(context);
                            if (navigator != null && navigator.canPop()) {
                              navigator.maybePop();
                            }
                          },
                    ),
                  ),
                if (trailing != null)
                  Positioned(
                    right: AppSpacing.screenHorizontal,
                    child: trailing!,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _HeaderBackButton extends StatelessWidget {
  const _HeaderBackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Back',
      child: Material(
        color: AppColors.white,
        elevation: 0.5,
        shadowColor: const Color(0x05000000),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.button),
          side: const BorderSide(color: AppColors.lightBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: const SizedBox(
            width: 40,
            height: 40,
            child: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 20,
              color: AppColors.secondaryText,
            ),
          ),
        ),
      ),
    );
  }
}
