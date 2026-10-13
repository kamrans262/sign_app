import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class Sign2DigitalSignatureActionCard extends StatelessWidget {
  const Sign2DigitalSignatureActionCard({
    super.key, required this.label, required this.icon, required this.onTap,
    this.selected = false, this.selectedIconColor, this.height = 76,
    this.documentStyling = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool selected;
  final Color? selectedIconColor;
  final double height;
  /// Documents action variant; existing signing card defaults stay unchanged.
  final bool documentStyling;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? AppColors.primary : AppColors.white,
    borderRadius: BorderRadius.circular(10),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        constraints: BoxConstraints(minHeight: height),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          border: Border.all(color: selected ? AppColors.primary : AppColors.lightBorder),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 24, color: selected ? (selectedIconColor ?? Colors.white) :
            (documentStyling ? AppColors.placeholder : AppColors.primary)),
          const SizedBox(height: 5),
          Text(label, maxLines: 2, textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Inter', fontSize: 12,
              fontWeight: FontWeight.w500,
              color: selected ? Colors.white :
                (documentStyling ? AppColors.placeholder : AppColors.primary),
              letterSpacing: -0.3)),
        ]),
      ),
    ),
  );
}
