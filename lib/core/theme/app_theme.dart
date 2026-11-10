// Sign2Digital Login UI Package — single app-wide light theme.
import 'package:flutter/material.dart';

import 'app_colors.dart';
export 'app_spacing.dart'; // Existing splash imports AppSpacing via app_theme.dart.

abstract final class AppTheme {
  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Inter',
      // Default Flutter bottom sheets use the same chrome as Switch Company.
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.white,
        modalBackgroundColor: AppColors.white,
        modalBarrierColor: Color(0x66000000),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        clipBehavior: Clip.antiAlias,
        showDragHandle: true,
        dragHandleColor: AppColors.placeholder,
        dragHandleSize: Size(36, 4),
      ),

      scaffoldBackgroundColor: AppColors.white,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        brightness: Brightness.light,
        surface: AppColors.white,
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColors.primary,
        selectionHandleColor: AppColors.primary,
      ),
      splashColor: AppColors.primary.withAlpha(20),
      highlightColor: AppColors.primary.withAlpha(10),
    );
  }
  /// Material-level dark colors. Legacy screen-specific fixed colors will
  /// migrate independently; the theme choice already updates MaterialApp.
  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    fontFamily: 'Inter',
    brightness: Brightness.dark,
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.white,
      modalBackgroundColor: AppColors.white,
      modalBarrierColor: Color(0x66000000),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      modalElevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      clipBehavior: Clip.antiAlias,
      showDragHandle: true,
      dragHandleColor: AppColors.placeholder,
      dragHandleSize: Size(36, 4),
    ),
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.dark,
    ),
    scaffoldBackgroundColor: const Color(0xFF122536),
  );
}
