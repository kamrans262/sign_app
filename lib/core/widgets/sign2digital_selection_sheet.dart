import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/sign2digital_motion.dart';
import '../theme/dashboard_colors.dart';
import 'sign2digital_modal_guard.dart';

/// Shared Switch Company sheet appearance for every field-based option picker.
/// This only owns the sheet chrome; callers still own their data and callbacks.
class Sign2DigitalSelectionSheet {
  const Sign2DigitalSelectionSheet._();

  static Future<T?> showCustom<T>({
    required BuildContext context,
    required String title,
    required IconData icon,
    required WidgetBuilder builder,
    String? subtitle,
    bool isScrollControlled = true,
    bool useSafeArea = true,
  }) => Sign2DigitalModalGuard.run<T>(
    context,
    () => showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    useSafeArea: useSafeArea,
    sheetAnimationStyle: Sign2DigitalMotion.bottomSheet,
    // Every picker renders the same custom drag handle.
    showDragHandle: false,
    backgroundColor: AppColors.white,
    barrierColor: const Color(0x66000000),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    clipBehavior: Clip.antiAlias,
    // The modal Material sits above this builder. Re-establish both the
    // approved light Theme and a matching DefaultTextStyle for custom content,
    // otherwise plain labels can render white on white in iOS dark mode.
    builder: (sheet) => Theme(
      data: AppTheme.light,
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheet).height * 0.88,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: AppColors.placeholder,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Row(children: [
                Container(
                  width: 40, height: 40,
                  decoration: const BoxDecoration(
                    color: DashboardColors.paleBlue,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 24, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(
                      fontFamily: 'Inter', fontSize: 18,
                      fontWeight: FontWeight.w600, letterSpacing: -0.3,
                      color: AppColors.dark,
                    )),
                    const SizedBox(height: 4),
                    Text(subtitle ?? 'Select an option', style: const TextStyle(
                      fontFamily: 'Inter', fontSize: 12,
                      fontWeight: FontWeight.w400, letterSpacing: -0.3,
                      color: AppColors.dark,
                    )),
                  ],
                )),
                const SizedBox(width: 8),
                Material(
                  color: DashboardColors.paleBlue,
                  shape: const CircleBorder(),
                  child: IconButton(
                    key: const Key('selection-sheet-close'),
                    tooltip: 'Close',
                    icon: const Icon(Icons.close_rounded, size: 18,
                      color: AppColors.primary),
                    constraints: const BoxConstraints(
                      minWidth: 36, minHeight: 36),
                    onPressed: () => Navigator.of(sheet).pop(),
                  ),
                ),
              ]),
            ),
            const Divider(height: 1, thickness: 1,
              color: AppColors.divider),
            Flexible(
              child: Theme(
                data: AppTheme.light,
                child: ListTileTheme(
                selectedColor: AppColors.dark,
                textColor: AppColors.dark,
                iconColor: AppColors.dark,
                selectedTileColor: DashboardColors.paleBlue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 4),
                child: builder(sheet),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
      ),
    ),
    ),
  );

  static Future<String?> show(
    BuildContext context, {
    required String title,
    required List<String> options,
    String? selected,
    IconData icon = Icons.tune_rounded,
    String? subtitle,
    String Function(String)? labelForOption,
    IconData? Function(String)? iconForOption,
    Key Function(String)? keyForOption,
  }) => showCustom<String>(
    context: context,
    title: title,
    icon: icon,
    subtitle: subtitle ?? 'Select an option',
    builder: (sheet) => ListView.separated(
      key: const Key('selection-sheet-options'),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      shrinkWrap: true,
      itemCount: options.length,
      separatorBuilder: (context, index) => const Divider(
        height: 1, thickness: 1,
        indent: 16, endIndent: 16, color: AppColors.divider,
      ),
      itemBuilder: (context, index) {
        final option = options[index];
        final isSelected = option == selected;
        final optionIcon = iconForOption?.call(option);
        return Semantics(
          selected: isSelected,
          button: true,
          child: Material(
            color: isSelected
                ? DashboardColors.paleBlue : AppColors.white,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              key: keyForOption?.call(option),
              borderRadius: BorderRadius.circular(10),
              onTap: () => Navigator.of(sheet).pop(option),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 14),
                child: Row(children: [
                  if (optionIcon != null) ...[
                    Icon(optionIcon, size: 20,
                      color: isSelected ? AppColors.primary : AppColors.dark,
                      semanticLabel: '${labelForOption?.call(option) ?? option} icon'),
                    const SizedBox(width: 12),
                  ],
                  Expanded(child: Text(
                    labelForOption?.call(option) ?? option,
                    style: TextStyle(
                      fontFamily: 'Inter', fontSize: 14,
                      fontWeight: isSelected
                          ? FontWeight.w600 : FontWeight.w500,
                      letterSpacing: -0.3,
                      color: AppColors.dark,
                    ),
                  )),
                  if (isSelected)
                    const Icon(Icons.check_circle_rounded,
                      size: 22, color: AppColors.primary),
                ]),
              ),
            ),
          ),
        );
      },
    ),
  );
}
