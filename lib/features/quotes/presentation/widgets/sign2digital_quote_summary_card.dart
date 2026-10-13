import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sign2digital_outlined_container.dart';
import '../../../clients/presentation/widgets/sign2digital_status_badge.dart';

/// Shared document/quote summary for signing and completion screens.
class Sign2DigitalQuoteSummaryCard extends StatelessWidget {
  const Sign2DigitalQuoteSummaryCard({
    super.key,
    required this.quoteNumber,
    required this.projectName,
    this.subtitleGap = 5,
    this.titleOverride,
    this.customerName,
    this.documentDate,
    this.status,
    this.onTap,
    this.listStyle = false,
    this.detailsStyle = false,
    this.linkedStyle = false,
    this.onRemoveLink,
  });

  final String quoteNumber;
  final String projectName;
  final double subtitleGap;
  /// Optional document-list layout. Existing compact signing cards stay unchanged.
  final String? titleOverride;
  final String? customerName;
  final DateTime? documentDate;
  final String? status;
  final VoidCallback? onTap;
  final bool listStyle;
  final bool detailsStyle;
  final bool linkedStyle;
  final VoidCallback? onRemoveLink;

  String _shortDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _time(DateTime date) {
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    return '$hour:${date.minute.toString().padLeft(2, '0')} '
        '${date.hour < 12 ? 'AM' : 'PM'}';
  }

  static const _metaStyle = TextStyle(
    fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w500,
    color: AppColors.placeholder,
  );

  Widget _metadataColumn(String heading, String stamp) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(heading, style: _metaStyle, softWrap: true),
      const SizedBox(height: 4),
      Text(stamp, style: _metaStyle, softWrap: true),
    ],
  );

  Widget _info() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (listStyle)
        LayoutBuilder(builder: (context, constraints) {
          final name = Text(titleOverride ?? 'Quote $quoteNumber',
            style: const TextStyle(
              fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w600,
              letterSpacing: -0.3, color: AppColors.dark,
            ),
          );
          if (status == null) return name;
          if (constraints.maxWidth < 205) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                name,
                const SizedBox(height: 5),
                Align(
                  alignment: Alignment.centerRight,
                  child: Sign2DigitalStatusBadge(status: status!),
                ),
              ],
            );
          }
          return Row(children: [
            Expanded(child: name),
            const SizedBox(width: 8),
            Sign2DigitalStatusBadge(status: status!),
          ]);
        })
      else
        Text('Quote # $quoteNumber', style: const TextStyle(
          fontFamily: 'Inter', fontSize: 16,
          fontWeight: FontWeight.w600, letterSpacing: -0.3,
          color: AppColors.dark,
        )),
      SizedBox(height: subtitleGap),
      if (listStyle && documentDate != null)
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 6, child: _metadataColumn(
            projectName, _shortDate(documentDate!),
          )),
          const SizedBox(width: 8),
          Expanded(flex: 4, child: _metadataColumn(
            customerName ?? '', _time(documentDate!),
          )),
        ])
      else
        Text(projectName, style: const TextStyle(
          fontFamily: 'Inter', fontSize: 14,
          fontWeight: FontWeight.w500, color: AppColors.placeholder,
        )),
    ],
  );

  Widget _detailsSummary() => Row(
    key: const Key('document-details-summary'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Material(
        color: Colors.white,
        shape: const CircleBorder(),
        elevation: 2,
        shadowColor: const Color(0x18000000),
        child: SizedBox(
          width: 40, height: 40,
          child: Center(
            child: SvgPicture.asset(
              'assets/icons_2/pdf.svg', width: 27, height: 27,
            ),
          ),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titleOverride ?? 'Quote $quoteNumber',
            key: const Key('document-details-title'),
            style: TextStyle(
              fontFamily: 'Inter', fontSize: linkedStyle ? 16 : 18, fontWeight: FontWeight.w600,
              letterSpacing: -0.3, color: AppColors.dark,
            )),
          const SizedBox(height: 5),
          Text(projectName, style: const TextStyle(
            fontFamily: 'Inter', fontSize: 14,
            fontWeight: FontWeight.w400, letterSpacing: -0.3,
            color: AppColors.placeholder,
          )),
        ],
      )),
      if (status != null) ...[
        const SizedBox(width: 10),
        Sign2DigitalStatusBadge(status: status!),
      ],
      if (onRemoveLink != null) ...[
        const SizedBox(width: 8),
        IconButton(
          key: const Key('addendum-remove-linked-document'),
          onPressed: onRemoveLink,
          tooltip: 'Remove linked document',
          icon: const Icon(Icons.close, color: AppColors.dark),
        ),
      ],
    ],
  );

  @override
  Widget build(BuildContext context) {
    if (linkedStyle) {
      return Sign2DigitalOutlinedContainer(
        padding: const EdgeInsets.all(20), child: _detailsSummary());
    }
    if (detailsStyle) { return _detailsSummary(); }
    final content = Sign2DigitalOutlinedContainer(
      padding: EdgeInsets.symmetric(
        horizontal: 20, vertical: listStyle ? 15 : 20,
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: const BoxDecoration(
              color: Color(0xFFE3ECF0), shape: BoxShape.circle,
            ),
            child: Icon(Icons.description_outlined,
              color: listStyle ? AppColors.primary : AppColors.dark, size: 23),
          ),
          SizedBox(width: listStyle ? 15 : 10),
          Expanded(child: _info()),
          if (listStyle) ...[
            const SizedBox(width: 10),
            const Icon(Icons.chevron_right_rounded,
              color: AppColors.secondaryText, size: 24),
          ],
        ],
      ),
    );
    if (onTap == null) return content;
    return Semantics(
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: content,
      ),
    );
  }
}
