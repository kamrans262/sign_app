import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/sign2digital_checkbox.dart';
import '../../../../core/widgets/sign2digital_info_banner.dart';
import '../../../../core/widgets/sign2digital_outlined_container.dart';
import '../../domain/document_record.dart';

/// The approved M12 wizard review design, shared with the saved-report viewer.
/// This is presentation only: it never changes or approves a report.
class SiteReportReviewContent extends StatelessWidget {
  const SiteReportReviewContent({
    super.key,
    required this.report,
    this.showInstruction = false,
    this.onChooseJob,
    this.onChooseDate,
    this.onEditDetails,
  });

  final DocumentRecord report;
  final bool showInstruction;
  final VoidCallback? onChooseJob;
  final VoidCallback? onChooseDate;
  final VoidCallback? onEditDetails;

  String _dateText(DateTime value) {
    const months = ['January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'];
    return '${months[value.month - 1]} ${value.day}, ${value.year}';
  }

  Widget _reviewValue({
    required String label,
    required String hint,
    required String icon,
    required String value,
    VoidCallback? onTap,
    bool withArrow = false,
  }) {
    final content = Sign2DigitalOutlinedContainer(
      constraints: const BoxConstraints(minHeight: 71),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SvgPicture.asset(icon, width: 24, height: 24),
          const SizedBox(width: 15),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTextStyles.fieldLabel),
              const SizedBox(height: 5),
              Text(
                value.isEmpty ? hint : value,
                style: value.isEmpty
                    ? AppTextStyles.fieldHint : AppTextStyles.fieldInput,
                softWrap: true,
              ),
            ],
          )),
          if (withArrow) ...[
            const SizedBox(width: 8),
            const Icon(Icons.keyboard_arrow_down_rounded,
                color: AppColors.secondaryText),
          ],
        ],
      ),
    );
    return onTap == null ? content : InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: content,
    );
  }

  Widget _reviewCover(SiteReportDetails site) {
    final photos = site.photos;
    return Container(
      key: const Key('review-report-cover'),
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.lightBorder),
        boxShadow: const [BoxShadow(
          color: Color(0x0D000000),
          offset: Offset(0, 4),
          blurRadius: 24,
        )],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: photos.length > 1
            ? GridView.builder(
                key: const Key('review-report-photo-grid'),
                padding: const EdgeInsets.all(10),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 188 / 118,
                ),
                itemCount: photos.length,
                itemBuilder: (context, index) => ClipRRect(
                  key: Key('review-report-photo-$index'),
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    photos[index].bytes,
                    key: index == 0
                        ? const Key('review-report-cover-image')
                        : Key('review-report-photo-image-$index'),
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const Center(
                      child: Icon(Icons.broken_image_outlined),
                    ),
                  ),
                ),
              )
            : AspectRatio(
                aspectRatio: 390 / 182,
                child: photos.isEmpty
                    ? const ColoredBox(
                        color: Color(0xFFF3F5F7),
                        child: Center(child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.image_outlined,
                              color: AppColors.placeholder, size: 26),
                            SizedBox(height: 5),
                            Text('No report photo selected',
                              style: TextStyle(
                                fontFamily: 'Inter', fontSize: 13,
                                color: AppColors.placeholder)),
                          ],
                        )),
                      )
                    : Image.memory(
                        photos.first.bytes,
                        key: const Key('review-report-cover-image'),
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const Center(
                          child: Icon(Icons.broken_image_outlined)),
                      ),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final site = report.siteReportDetails;
    if (site == null) return const SizedBox.shrink();
    final sections = site.sectionContent;
    final actions = site.actionItems.map((item) {
      return [
        item.description,
        if (item.assignee.isNotEmpty) 'Owner: ${item.assignee}',
        if (item.dueDate != null) 'Due: ${_dateText(item.dueDate!)}',
      ].join(' • ');
    }).join('\n');
    return Column(
      key: const Key('review-reports-body'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _reviewCover(site),
        const SizedBox(height: 20),
        Text(report.title,
          key: const Key('review-report-title'),
          style: const TextStyle(
            fontFamily: 'Inter', fontSize: 20,
            fontWeight: FontWeight.w600, color: AppColors.dark,
          ),
        ),
        const SizedBox(height: 20),
        _reviewValue(label: 'Report Number', hint: '', 
          icon: 'assets/icons/description.svg', value: report.number),
        const SizedBox(height: 15),
        _reviewValue(label: 'Job', hint: 'e.g, Site renovation',
          icon: 'assets/icons/description.svg', value: report.project,
          onTap: onChooseJob, withArrow: onChooseJob != null),
        const SizedBox(height: 15),
        _reviewValue(label: 'Client', hint: 'e.g, Marc dupont',
          icon: 'assets/icons/user.svg', value: report.customer),
        const SizedBox(height: 15),
        _reviewValue(label: 'Report Date', hint: 'Select date',
          icon: 'assets/icons/calendar-outlined.svg',
          value: _dateText(site.reportDate), onTap: onChooseDate),
        const SizedBox(height: 15),
        _reviewValue(label: 'Site Location', hint: 'Enter site location',
          icon: 'assets/icons/description.svg', value: site.location,
          onTap: onEditDetails),
        const SizedBox(height: 15),
        _reviewValue(label: 'Prepared By', hint: 'e.g, Jean Dupont',
          icon: 'assets/icons/user.svg', value: site.preparedBy,
          onTap: onEditDetails),
        const SizedBox(height: 15),
        _reviewValue(label: 'Weather Condition', hint: '',
          icon: 'assets/icons/description.svg', value: site.weatherCondition),
        const SizedBox(height: 20),
        for (final section in SiteReportSection.values)
          if (site.selectedSections.contains(section)) ...[
            Row(children: [
              IgnorePointer(child: Sign2DigitalCheckbox(
                key: Key('review-report-section-${section.name}'),
                value: true,
                label: section.label,
                showLabel: false,
                boxSize: 16,
                onChanged: (_) {},
              )),
              const SizedBox(width: 10),
              Expanded(child: Text(
                section.label,
                style: const TextStyle(
                  fontFamily: 'Inter', fontSize: 14,
                  fontWeight: FontWeight.w500, letterSpacing: -0.3,
                  color: AppColors.placeholder,
                ),
              )),
            ]),
            const SizedBox(height: 10),
            if (section != SiteReportSection.photos &&
                (sections[section] ?? '').trim().isNotEmpty) ...[
              _reviewValue(label: section.label, hint: '',
                icon: 'assets/icons/description.svg',
                value: sections[section]!.trim()),
              const SizedBox(height: 15),
            ] else
              const SizedBox(height: 5),
          ],
        for (final (label, values) in <(String, List<String>)>[
          ('Attendees', site.attendees),
          ('Absentees', site.absentees),
          ('Decisions', site.decisions),
          ('Outstanding Points', site.outstandingPoints),
          ('Next Steps', site.nextSteps),
        ])
          if (values.isNotEmpty) ...[
            _reviewValue(label: label, hint: '',
              icon: 'assets/icons/description.svg', value: values.join('\n')),
            const SizedBox(height: 15),
          ],
        if (actions.isNotEmpty) ...[
          _reviewValue(label: 'Action Items', hint: '',
            icon: 'assets/icons/description.svg', value: actions),
          const SizedBox(height: 15),
        ],
        if (showInstruction) ...[
          const SizedBox(height: 5),
          const Sign2DigitalInfoBanner(
            key: Key('review-report-info'),
            message: 'Please review all information before generating the report',
            verticalPadding: 10, iconSize: 24, iconGap: 10, fontSize: 13,
          ),
        ],
      ],
    );
  }
}
