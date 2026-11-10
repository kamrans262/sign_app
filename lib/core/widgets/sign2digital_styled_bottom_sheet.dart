import 'package:flutter/material.dart' as material;

import '../theme/app_colors.dart';

/// Standardized Sign2Digital sheet shell.
///
/// Preserves every caller's builder, result type, scrolling, drag and dismiss
/// behavior while applying the same approved Switch Company surface tokens.
/// Option-sheet contents can progressively adopt Sign2DigitalSelectionSheet
/// for its full titled icon/close header.
Future<T?> showSign2DigitalBottomSheet<T>({
  required material.BuildContext context,
  required material.WidgetBuilder builder,
  material.Color? backgroundColor,
  double? elevation,
  material.ShapeBorder? shape,
  material.Clip? clipBehavior,
  material.Color? barrierColor,
  bool isScrollControlled = false,
  double scrollControlDisabledMaxHeightRatio = 9 / 16,
  bool useRootNavigator = false,
  bool isDismissible = true,
  bool enableDrag = true,
  bool? showDragHandle,
  bool useSafeArea = false,
  material.RouteSettings? routeSettings,
  material.AnimationController? transitionAnimationController,
  material.Offset? anchorPoint,
  material.BoxConstraints? constraints,
  material.AnimationStyle? sheetAnimationStyle,
  bool? requestFocus,
}) {
  final appTheme = material.Theme.of(context);
  return material.showModalBottomSheet<T>(
    context: context,
    builder: (sheetContext) => material.Theme(
      data: appTheme.copyWith(
        listTileTheme: appTheme.listTileTheme.copyWith(
          selectedColor: AppColors.primary,
          selectedTileColor: const material.Color(0xFFE3ECF0),
          contentPadding: const material.EdgeInsets.symmetric(
            horizontal: 16, vertical: 4,
          ),
          shape: material.RoundedRectangleBorder(
            borderRadius: material.BorderRadius.circular(10),
          ),
        ),
      ),
      child: builder(sheetContext),
    ),
    isScrollControlled: isScrollControlled,
    scrollControlDisabledMaxHeightRatio: scrollControlDisabledMaxHeightRatio,
    useRootNavigator: useRootNavigator,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    useSafeArea: useSafeArea,
    routeSettings: routeSettings,
    transitionAnimationController: transitionAnimationController,
    anchorPoint: anchorPoint,
    constraints: constraints,
    sheetAnimationStyle: sheetAnimationStyle,
    requestFocus: requestFocus,
    // Approved Switch Company sheet visuals. The native handle uses the
    // app's BottomSheetThemeData: 36×4, placeholder color and rounded ends.
    backgroundColor: AppColors.white,
    elevation: 0,
    barrierColor: const material.Color(0x66000000),
    shape: const material.RoundedRectangleBorder(
      borderRadius: material.BorderRadius.vertical(
        top: material.Radius.circular(20),
      ),
    ),
    clipBehavior: material.Clip.antiAlias,
    showDragHandle: true,
  );
}
