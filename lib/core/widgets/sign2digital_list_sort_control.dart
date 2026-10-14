import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Same sort selection heading for Expenses and Time & Labour.
class Sign2DigitalListSortControl extends StatelessWidget {
  const Sign2DigitalListSortControl({
    super.key, required this.value, required this.onTap, this.valueKey,
  });
  final String value;
  final VoidCallback onTap;
  final Key? valueKey;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Text('Sort By: ', style: TextStyle(
            fontFamily: 'Inter', fontSize: 16, letterSpacing: -0.3,
            fontWeight: FontWeight.w500, color: AppColors.dark)),
          Flexible(child: Text(value,
            key: valueKey, overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Inter', fontSize: 16, letterSpacing: -0.3,
              fontWeight: FontWeight.w500, color: AppColors.primary))),
          const SizedBox(width: 8),
          const Icon(Icons.keyboard_arrow_down_rounded,
            size: 24, color: AppColors.primary),
        ]),
      ),
    ),
  );
}
