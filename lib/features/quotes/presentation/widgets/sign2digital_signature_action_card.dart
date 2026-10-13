import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class Sign2DigitalSignatureActionCard extends StatelessWidget {
  const Sign2DigitalSignatureActionCard({
    super.key, required this.label, required this.icon, required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.white,
    borderRadius: BorderRadius.circular(10),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        constraints: const BoxConstraints(minHeight: 76),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.lightBorder),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 24, color: AppColors.primary),
          const SizedBox(height: 5),
          Text(label, maxLines: 2, textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: 'Inter', fontSize: 12,
              fontWeight: FontWeight.w500, color: AppColors.primary,
              letterSpacing: -0.3)),
        ]),
      ),
    ),
  );
}
