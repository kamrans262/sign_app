// Sign2Digital Login UI Package — reusable white outlined treatment.
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

abstract final class Sign2DigitalOutlinedDecoration {
  static BoxDecoration get standard => BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: AppColors.lightBorder),
        borderRadius: BorderRadius.circular(AppRadius.input),
      );
}

class Sign2DigitalOutlinedContainer extends StatelessWidget {
  const Sign2DigitalOutlinedContainer({
    required this.child,
    this.padding = EdgeInsets.zero,
    this.constraints,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final BoxConstraints? constraints;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: constraints,
      padding: padding,
      decoration: Sign2DigitalOutlinedDecoration.standard,
      child: child,
    );
  }
}
