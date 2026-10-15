import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/dashboard_colors.dart';

/// Shared Sign2Digital picker presentation for simple dropdown fields.
/// Preserves callers' values and keys; styles only the modal and option rows.
class Sign2DigitalSelectionSheet {
  const Sign2DigitalSelectionSheet._();

  static Future<String?> show(
    BuildContext context, {
    required String title,
    required List<String> options,
    String? selected,
    IconData icon = Icons.tune_rounded,
    String Function(String)? labelForOption,
    Key Function(String)? keyForOption,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.white,
      barrierColor: const Color(0x66000000),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      clipBehavior: Clip.antiAlias,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.70,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.placeholder,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                child: Row(children: [
                  Container(
                    width: 40,
                    height: 40,
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
                        fontFamily: 'Inter',
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.3,
                        color: AppColors.dark,
                      )),
                      const SizedBox(height: 4),
                      const Text('Select an option', style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        letterSpacing: -0.3,
                        color: AppColors.placeholder,
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
                      onPressed: () => Navigator.of(sheetContext).pop(),
                    ),
                  ),
                ]),
              ),
              const Divider(height: 1, thickness: 1,
                color: AppColors.divider),
              Flexible(
                child: ListView.separated(
                  key: const Key('selection-sheet-options'),
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                  shrinkWrap: true,
                  itemCount: options.length,
                  separatorBuilder: (context, index) => const Divider(
                    height: 1, thickness: 1,
                    indent: 16, endIndent: 16,
                    color: AppColors.divider,
                  ),
                  itemBuilder: (context, index) {
                    final option = options[index];
                    final isSelected = option == selected;
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
                          onTap: () =>
                              Navigator.of(sheetContext).pop(option),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 14),
                            child: Row(children: [
                              Expanded(child: Text(
                                labelForOption?.call(option) ?? option,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 14,
                                  fontWeight: isSelected
                                      ? FontWeight.w600 : FontWeight.w500,
                                  letterSpacing: -0.3,
                                  color: isSelected
                                      ? AppColors.primary : AppColors.dark,
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}
