import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../assets/dashboard_assets.dart';
import '../theme/app_colors.dart';
import '../navigation/sign2digital_navigation.dart';
import '../services/active_company_session.dart';

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
    return ValueListenableBuilder<CompanyAccess?>(
      valueListenable: ActiveCompanySession.access,
      builder: (context, _, __) {
        // Preserve approved tab order and original numeric destinations.
        final visible = <int>[
          0,
          if (ActiveCompanySession.canRead('jobs')) 1,
          if (ActiveCompanySession.canRead('clients')) 2,
          if (ActiveCompanySession.canRead('documents')) 3,
          4,
        ];
        return Container(
      color: AppColors.white,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 10),
          child: Row(
            children: visible.map((index) {
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
                    onTap: () {
                      // A nested screen must return to the existing
                      // dashboard instead of independently popping routes.
                      if (!Sign2DigitalNavigation.selectDashboardTab(
                          context, index)) {
                        onSelected(index);
                      }
                    },
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
            }).toList(),
          ),
        ),
      ),
    );
      },
    );
  }
}
