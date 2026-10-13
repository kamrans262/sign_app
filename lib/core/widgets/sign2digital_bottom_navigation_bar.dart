import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../assets/dashboard_assets.dart';
import '../theme/app_colors.dart';

class Sign2DigitalBottomNavigationBar extends StatelessWidget {
  const Sign2DigitalBottomNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const labels = ['Home', 'Jobs', 'Clients', 'Documents', 'More'];
  static const icons = [
    DashboardAssets.homeIcon,
    DashboardAssets.jobsIcon,
    DashboardAssets.clientsIcon,
    DashboardAssets.documentIcon,
    DashboardAssets.moreIcon,
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.white,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 10),
          child: Row(
            children: List.generate(labels.length, (index) {
              final active = index == selectedIndex;
              final color = active
                  ? AppColors.primary
                  : AppColors.secondaryText;
              return Expanded(
                child: Semantics(
                  selected: active,
                  button: true,
                  label: '${labels[index]} tab',
                  child: InkWell(
                    key: Key('dashboard-tab-$index'),
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => onSelected(index),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (icons[index] != null)
                            SvgPicture.asset(
                              icons[index]!,
                              width: 23,
                              height: 23,
                              colorFilter: ColorFilter.mode(
                                color,
                                BlendMode.srcIn,
                              ),
                              semanticsLabel: labels[index],
                            )
                          else
                            Icon(
                              Icons.description_outlined,
                              color: color,
                              size: 23,
                            ),
                          const SizedBox(height: 5),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              labels[index],
                              maxLines: 1,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                letterSpacing: -0.3,
                                fontWeight: FontWeight.w500,
                                color: active
                                    ? AppColors.primary
                                    : AppColors.placeholder,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
