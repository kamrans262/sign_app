// Sign2Digital Login UI Package — reusable icon/label/editable auth field.
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'sign2digital_outlined_container.dart';

class Sign2DigitalInputField extends StatelessWidget {
  const Sign2DigitalInputField({
    required this.label,
    required this.hintText,
    required this.iconAsset,
    required this.controller,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.obscureText = false,
    this.validator,
    this.textInputAction,
    this.trailing,
    this.inputPrefix,
    this.autofillHints,
    this.onFieldSubmitted,
    this.minLines = 1,
    this.maxLines = 1,
    this.maxLength,
    super.key,
  });

  final String label;
  final String hintText;
  final String iconAsset;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final bool obscureText;
  final String? Function(String?)? validator;
  final TextInputAction? textInputAction;
  final Widget? trailing;
  final Widget? inputPrefix;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onFieldSubmitted;
  final int minLines;
  final int? maxLines;
  final int? maxLength;

  @override
  Widget build(BuildContext context) {
    return Sign2DigitalOutlinedContainer(
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
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.fieldLabel),
                const SizedBox(height: 5),
                Row(
                  children: [
                    if (inputPrefix != null) ...[
                      inputPrefix!,
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: TextFormField(
                        controller: controller,
                        minLines: obscureText ? 1 : minLines,
                        maxLines: obscureText ? 1 : maxLines,
                        maxLength: maxLength,
                        buildCounter: maxLength == null
                            ? null
                            : (
                                context, {
                                required currentLength,
                                required isFocused,
                                maxLength,
                              }) => null,
                        onTapOutside: (_) =>
                            FocusManager.instance.primaryFocus?.unfocus(),
                        keyboardType: keyboardType,
                        textCapitalization: textCapitalization,
                        obscureText: obscureText,
                        validator: validator,
                        textInputAction: textInputAction,
                        onFieldSubmitted: onFieldSubmitted,
                        autofillHints: autofillHints,
                        autocorrect: false,
                        enableSuggestions: !obscureText,
                        cursorColor: Theme.of(context).colorScheme.primary,
                        style: AppTextStyles.fieldInput,
                        textAlignVertical: TextAlignVertical.center,
                        scrollPadding: const EdgeInsets.all(80),
                        decoration: InputDecoration(
                          hintText: hintText,
                          hintStyle: AppTextStyles.fieldHint,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          focusedErrorBorder: InputBorder.none,
                          isCollapsed: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );
  }
}
