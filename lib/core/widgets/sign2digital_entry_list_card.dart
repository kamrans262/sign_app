import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'sign2digital_outlined_container.dart';
import '../../features/clients/presentation/widgets/sign2digital_status_badge.dart';

/// Shared compact list card used by Expenses and Time & Labour.
/// Status is above/beside the chevron but the chevron is vertically centered.
class Sign2DigitalEntryListCard extends StatelessWidget {
  const Sign2DigitalEntryListCard({
    super.key,
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.dateText,
    required this.trailingValue,
    required this.status,
    required this.onTap,
    this.titleKey,
    this.trailingKey,
    this.shadow = false,
  });

  final Widget leading;
  final String title, subtitle, dateText, trailingValue, status;
  final VoidCallback onTap;
  final Key? titleKey, trailingKey;
  final bool shadow;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: shadow ? const BoxDecoration(boxShadow: [
          BoxShadow(color: Color(0x0D000000),
            offset: Offset(0, 4), blurRadius: 24),
        ]) : null,
        child: Sign2DigitalOutlinedContainer(
          padding: const EdgeInsets.all(15),
          child: LayoutBuilder(builder: (context, box) {
            final compact = box.maxWidth < 290;
            return Row(crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                leading,
                SizedBox(width: compact ? 9 : 15),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, key: titleKey,
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontFamily: 'Inter',
                        fontSize: 16, fontWeight: FontWeight.w600,
                        letterSpacing: -0.3, color: AppColors.dark)),
                    const SizedBox(height: 5),
                    Text(subtitle, maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontFamily: 'Inter',
                        fontSize: 13, fontWeight: FontWeight.w500,
                        color: AppColors.placeholder)),
                    const SizedBox(height: 4),
                    Text(dateText, maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontFamily: 'Inter',
                        fontSize: 13, fontWeight: FontWeight.w500,
                        color: AppColors.placeholder)),
                  ],
                )),
                SizedBox(width: compact ? 4 : 10),
                Column(crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(trailingValue, key: trailingKey,
                      maxLines: 1,
                      style: const TextStyle(fontFamily: 'Inter',
                        fontSize: 14, height: 1, fontWeight: FontWeight.w500,
                        letterSpacing: -0.3, color: AppColors.dark)),
                    const SizedBox(height: 5),
                    Sign2DigitalStatusBadge(status: status),
                  ]),
                const SizedBox(width: 5),
                const Icon(Icons.chevron_right_rounded,
                  size: 24, color: AppColors.secondaryText),
              ]);
          }),
        ),
      ),
    ),
  );
}
