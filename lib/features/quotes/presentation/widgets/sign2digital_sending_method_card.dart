import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// One of the three mutually exclusive sending-method choices.
class Sign2DigitalSendingMethodCard extends StatelessWidget {
  const Sign2DigitalSendingMethodCard({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: selected,
        label: label,
        child: Material(
          color: selected ? AppColors.primary : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color: selected ? AppColors.primary : AppColors.lightBorder,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 72),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 24,
                        color: selected ? Colors.white : AppColors.secondaryText),
                    const SizedBox(height: 3),
                    Text(label, maxLines: 2, textAlign: TextAlign.center,
                        style: TextStyle(fontFamily: 'Inter', fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: selected ? Colors.white : AppColors.placeholder)),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}
