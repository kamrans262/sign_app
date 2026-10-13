import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// The same soft-shadow surface for quote extraction and quote review.
class Sign2DigitalQuoteShadowPanel extends StatelessWidget {
  const Sign2DigitalQuoteShadowPanel({
    super.key, required this.child,
    this.padding = EdgeInsets.zero,
    this.clip = false,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool clip;

  static BoxDecoration get decoration => BoxDecoration(
    color: AppColors.white,
    border: Border.all(color: AppColors.lightBorder),
    borderRadius: BorderRadius.circular(10),
    boxShadow: const [BoxShadow(
      color: Color(0x1A000000), offset: Offset(0, 4), blurRadius: 24,
    )],
  );

  @override
  Widget build(BuildContext context) => Container(
    clipBehavior: clip ? Clip.antiAlias : Clip.none,
    decoration: decoration,
    padding: padding,
    child: child,
  );
}
