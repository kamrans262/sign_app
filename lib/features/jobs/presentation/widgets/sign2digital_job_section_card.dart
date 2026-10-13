import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/dashboard_colors.dart';
import '../../../../core/widgets/sign2digital_outlined_container.dart';
import '../../domain/job_details_model.dart';

class Sign2DigitalJobSectionCard extends StatelessWidget {
  const Sign2DigitalJobSectionCard({
    super.key,
    required this.details,
    required this.onTap,
  });

  final JobSectionDetails details;
  final VoidCallback onTap;

  static String? _asset(JobSection section) => switch (section) {
    JobSection.quotes => 'assets/icons/jobs.svg',
    JobSection.addenda => 'assets/icons/doc_numbering.svg',
    JobSection.documents => 'assets/icons/description.svg',
    JobSection.notes => 'assets/icons/description.svg',
    JobSection.siteReports => 'assets/icons/description.svg',
    JobSection.invoices => 'assets/icons/doc_numbering.svg',
    _ => null,
  };

  static IconData _icon(JobSection section) => switch (section) {
    JobSection.photos => Icons.photo_outlined,
    JobSection.purchases => Icons.shopping_cart_outlined,
    JobSection.time => Icons.history_toggle_off_outlined,
    JobSection.deposits => Icons.savings_outlined,
    JobSection.acceptance => Icons.check_circle,
    _ => Icons.description_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final asset = _asset(details.section);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key('job-section-${details.section.name}'),
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Semantics(
          button: true,
          label: '${details.section.label}: ${details.subtitle}',
          child: Sign2DigitalOutlinedContainer(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: DashboardColors.paleBlue,
                  ),
                  child: Center(
                    child: asset == null
                        ? Icon(
                            _icon(details.section),
                            size: 22,
                            color: AppColors.primary,
                          )
                        : SvgPicture.asset(
                            asset,
                            width: 22,
                            height: 22,
                            colorFilter: const ColorFilter.mode(
                              AppColors.primary,
                              BlendMode.srcIn,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        details.section.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          letterSpacing: -0.3,
                          color: AppColors.dark,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        details.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                          letterSpacing: -0.3,
                          color: AppColors.placeholder,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
