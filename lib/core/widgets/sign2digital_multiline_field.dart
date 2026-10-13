import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_text_styles.dart';
import 'sign2digital_outlined_container.dart';

/// Reuses the outlined field treatment for text without an upper label.
class Sign2DigitalMultilineField extends StatelessWidget {
  const Sign2DigitalMultilineField({
    super.key,
    required this.controller,
    required this.iconAsset,
    required this.hintText,
    this.validator,
  });

  final TextEditingController controller;
  final String iconAsset;
  final String hintText;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    return Sign2DigitalOutlinedContainer(
      constraints: const BoxConstraints(minHeight: 62),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: SvgPicture.asset(
              iconAsset,
              width: 20,
              height: 20,
              semanticsLabel: 'Notes icon',
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: TextFormField(
              key: Key('client-notes-input'),
              controller: controller,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              minLines: 2,
              maxLines: null,
              validator: validator,
              style: AppTextStyles.fieldInput,
              onTapOutside: (_) =>
                  FocusManager.instance.primaryFocus?.unfocus(),
              scrollPadding: const EdgeInsets.all(90),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: AppTextStyles.fieldHint,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isCollapsed: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
