import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'sign2digital_outlined_container.dart';

/// Interactive counterpart of Sign2DigitalInputField using identical styling.
class Sign2DigitalSelectionField extends StatelessWidget {
  const Sign2DigitalSelectionField({
    super.key,
    required this.label,
    required this.iconAsset,
    required this.hintText,
    required this.onTap,
    this.value,
    this.errorText,
  });

  final String label;
  final String iconAsset;
  final String hintText;
  final VoidCallback onTap;
  final String? value;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final selected = value != null && value!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          label: label,
          value: selected ? value : hintText,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(10),
              child: Sign2DigitalOutlinedContainer(
                constraints: const BoxConstraints(minHeight: 71),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.fieldHorizontal,
                  vertical: AppSpacing.fieldVertical,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SvgPicture.asset(
                      iconAsset,
                      width: 20,
                      height: 20,
                      semanticsLabel: '$label icon',
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(label, style: AppTextStyles.fieldLabel),
                          const SizedBox(height: 5),
                          Text(
                            selected ? value! : hintText,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: selected
                                ? AppTextStyles.fieldInput
                                : AppTextStyles.fieldHint,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(left: 15, top: 5),
            child: Text(
              errorText!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }
}
