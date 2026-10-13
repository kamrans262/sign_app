import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';

/// A reusable, editable quote input with an explicit missing/invalid state.
class Sign2DigitalQuoteItemField extends StatelessWidget {
  const Sign2DigitalQuoteItemField({
    super.key, required this.label, required this.value, required this.onChanged,
    this.missing = false, this.readOnly = false, this.numeric = false,
    this.leadingIcon, this.hint = 'Not Specified',
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final bool missing;
  final bool readOnly;
  final bool numeric;
  final IconData? leadingIcon;
  final String hint;

  @override
  Widget build(BuildContext context) {
    const warning = Color(0xFFE6A23C);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontFamily: 'Inter', fontSize: 12,
        fontWeight: FontWeight.w500, letterSpacing: -0.3,
        color: AppColors.placeholder)),
      const SizedBox(height: 7),
      Container(
        decoration: BoxDecoration(
          color: missing ? warning.withAlpha(26) : AppColors.placeholder.withAlpha(13),
          border: Border.all(color: AppColors.lightBorder),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: [
          if (leadingIcon != null) ...[
            const SizedBox(width: 12),
            Icon(leadingIcon, size: 18, color: AppColors.dark),
          ],
          Expanded(child: TextFormField(
            key: ValueKey('quote-field-$label'),
            initialValue: value,
            readOnly: readOnly,
            onChanged: onChanged,
            keyboardType: numeric ? const TextInputType.numberWithOptions(decimal: true)
                : TextInputType.text,
            inputFormatters: numeric ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))] : null,
            onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
            textInputAction: TextInputAction.done,
            scrollPadding: const EdgeInsets.all(90),
            minLines: 1,
            maxLines: 1,
            style: TextStyle(fontFamily: 'Inter', fontSize: 14,
                fontWeight: FontWeight.w500, letterSpacing: -0.3,
                color: missing ? warning : AppColors.dark),
            decoration: InputDecoration(
              border: InputBorder.none, enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              hintText: hint,
              hintStyle: TextStyle(fontFamily: 'Inter', fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: missing ? warning : AppColors.placeholder),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          )),
        ]),
      ),
    ]);
  }
}
