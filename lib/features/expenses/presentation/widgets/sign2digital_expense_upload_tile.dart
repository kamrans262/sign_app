import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/sign2digital_outlined_container.dart';

/// Reusable Add Photo tile for Create Expense and Receipt.
class Sign2DigitalExpenseUploadTile extends StatelessWidget {
  const Sign2DigitalExpenseUploadTile({
    super.key,
    required this.onTap,
    this.enabled = true,
  });

  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: enabled ? onTap : null,
    borderRadius: BorderRadius.circular(10),
    child: Sign2DigitalOutlinedContainer(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        SvgPicture.asset('assets/icons/cloud-upload-outlined.svg',
          width: 24, height: 24),
        const SizedBox(height: 8),
        const Text('Add Photo', style: AppTextStyles.outlinedButton),
      ]),
    ),
  );
}
