import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'sign2digital_modal_surface.dart';
import 'sign2digital_outlined_button.dart';
import 'sign2digital_primary_button.dart';

/// Approved Sign2Digital surface for editable forms, previews and information.
/// Keeps the caller's fields, callbacks, validation, result and widget keys.
class Sign2DigitalFormDialog extends StatelessWidget {
  const Sign2DigitalFormDialog({
    super.key,
    this.title,
    this.content,
    this.actions = const [],
    this.backgroundColor,
    this.shape,
  });

  final Widget? title;
  final Widget? content;
  final List<Widget> actions;
  // Accepted for compatibility with legacy AlertDialog usages.
  final Color? backgroundColor;
  final ShapeBorder? shape;

  static final InputDecorationTheme _inputTheme = InputDecorationTheme(
    filled: true,
    fillColor: AppColors.white,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 16),
    labelStyle: const TextStyle(
      fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w500,
      color: AppColors.secondaryText,
    ),
    floatingLabelStyle: const TextStyle(
      fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w500,
      color: AppColors.primary,
    ),
    hintStyle: const TextStyle(
      fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w400,
      color: AppColors.placeholder,
    ),
    prefixIconColor: AppColors.dark,
    suffixIconColor: AppColors.dark,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.lightBorder),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.lightBorder),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.primary),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFFB42318)),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFFB42318)),
    ),
  );

  Widget _action(Widget widget, {required bool primary}) {
    if (widget is TextButton && widget.child is Text) {
      final child = widget.child! as Text;
      final label = child.data ?? child.textSpan?.toPlainText();
      if (label != null) {
        if (primary) {
          return Sign2DigitalPrimaryButton(
            key: widget.key,
            label: label,
            compactLabel: true,
            enabled: widget.onPressed != null,
            onPressed: widget.onPressed ?? () {},
          );
        }
        return Sign2DigitalOutlinedButton(
          key: widget.key,
          label: label,
          primaryOutline: true,
          enabled: widget.onPressed != null,
          onPressed: widget.onPressed ?? () {},
        );
      }
    }
    return widget;
  }

  @override
  Widget build(BuildContext context) {
    final localTheme = AppTheme.light.copyWith(
      inputDecorationTheme: _inputTheme,
      textTheme: AppTheme.light.textTheme.apply(
        fontFamily: 'Inter',
        bodyColor: AppColors.dark,
        displayColor: AppColors.dark,
      ),
    );
    return Sign2DigitalModalSurface(
      child: Theme(
        data: localTheme,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null) ...[
              DefaultTextStyle(
                style: const TextStyle(
                  fontFamily: 'Inter', fontSize: 18,
                  fontWeight: FontWeight.w600, color: AppColors.dark,
                  decoration: TextDecoration.none,
                ),
                textAlign: TextAlign.center,
                child: title!,
              ),
              const SizedBox(height: 15),
            ],
            if (content != null)
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.50,
                ),
                child: SingleChildScrollView(
                  child: DefaultTextStyle(
                    style: const TextStyle(
                      fontFamily: 'Inter', fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.secondaryText,
                      decoration: TextDecoration.none,
                    ),
                    child: content!,
                  ),
                ),
              ),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 20),
              if (actions.length == 2)
                Row(children: [
                  Expanded(child: _action(actions.first, primary: false)),
                  const SizedBox(width: 15),
                  Expanded(child: _action(actions.last, primary: true)),
                ])
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var index = 0; index < actions.length; index++) ...[
                      if (index > 0) const SizedBox(height: 10),
                      _action(actions[index],
                          primary: index == actions.length - 1),
                    ],
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }
}
