import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class Sign2DigitalDetailsTabs extends StatelessWidget {
  const Sign2DigitalDetailsTabs({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(labels.length, (index) {
          final active = selectedIndex == index;
          return InkWell(
            key: Key('details-tab-$index'),
            onTap: () => onSelected(index),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 13),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: active ? AppColors.primary : AppColors.lightBorder,
                    width: active ? 2 : 1,
                  ),
                ),
              ),
              child: Text(
                labels[index],
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  letterSpacing: -0.3,
                  fontWeight: FontWeight.w500,
                  color: active ? AppColors.primary : AppColors.placeholder,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
