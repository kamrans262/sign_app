import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Shared white modal surface. Show through showDialog with a 50%-black barrier.
class Sign2DigitalModalSurface extends StatelessWidget {
  const Sign2DigitalModalSurface({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.white,
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 350),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(25),
          child: child,
        ),
      ),
    );
  }
}
