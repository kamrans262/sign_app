import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Full-width underline tabs, shared by Add Signature and In-Person Signature.
class Sign2DigitalSignatureTabs extends StatelessWidget {
  const Sign2DigitalSignatureTabs({
    super.key,
    required this.labels,
    required this.ids,
    required this.selectedIndex,
    required this.onSelected,
    required this.keyPrefix,
  }) : assert(labels.length == ids.length);

  final List<String> labels;
  final List<String> ids;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: Stack(
      children: [
        const Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SizedBox(
            height: 1,
            child: ColoredBox(color: AppColors.lightBorder),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < labels.length; i++) ...[
                if (i != 0) const SizedBox(width: 30),
                InkWell(
                  key: Key('$keyPrefix-${ids[i]}'),
                  onTap: () => onSelected(i),
                  child: Container(
                    padding: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: i == selectedIndex
                              ? AppColors.primary
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                    child: Text(
                      labels[i],
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: i == selectedIndex
                            ? AppColors.primary
                            : AppColors.placeholder,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}
