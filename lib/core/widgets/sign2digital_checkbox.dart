// Sign2Digital Login UI Package — checked-state control with semantics.
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class Sign2DigitalCheckbox extends StatelessWidget {
  const Sign2DigitalCheckbox({
    required this.value,
    required this.onChanged,
    this.label = 'Keep me signed in',
    this.showLabel = true,
    this.boxSize = 20,
    super.key,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final String label;
  final bool showLabel;
  final double boxSize;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      checked: value,
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: boxSize,
              height: boxSize,
              decoration: BoxDecoration(
                color: value ? AppColors.primary : AppColors.white,
                borderRadius: BorderRadius.circular(5),
                border: Border.all(
                  color: value ? AppColors.primary : AppColors.placeholder,
                ),
              ),
              child: value
                  ? Icon(
                      Icons.check_rounded,
                      color: AppColors.white,
                      size: boxSize - 4,
                    )
                  : null,
            ),
            if (showLabel) ...[
              const SizedBox(width: 8),
              Flexible(child: Text(label, style: AppTextStyles.small)),
            ],
          ],
        ),
      ),
    );
  }
}
