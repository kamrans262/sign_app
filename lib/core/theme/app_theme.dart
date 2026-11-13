// Sign2Digital Login UI Package — single app-wide light theme.
import 'package:flutter/material.dart';

import 'app_colors.dart';
export 'app_spacing.dart'; // Existing splash imports AppSpacing via app_theme.dart.

abstract final class AppTheme {
  // All Material dialogs (including the 50 AlertDialogs in feature screens)
  // match the approved Sign2Digital modal surface. Flutter's actual
  // DialogThemeData also controls AlertDialog title/body typography and
  // action padding, while preserving every dialog's original callbacks.
  static const DialogThemeData _dialogTheme = DialogThemeData(
    backgroundColor: AppColors.white,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    shadowColor: Colors.transparent,
    barrierColor: Color(0x80000000),
    insetPadding: EdgeInsets.symmetric(horizontal: 40, vertical: 20),
    constraints: BoxConstraints(maxWidth: 350),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(20)),
    ),
    clipBehavior: Clip.antiAlias,
    actionsPadding: EdgeInsets.fromLTRB(20, 0, 20, 20),
    titleTextStyle: TextStyle(
      fontFamily: 'Inter', fontSize: 18, fontWeight: FontWeight.w600,
      letterSpacing: -0.3, height: 1.35, color: AppColors.dark,
    ),
    contentTextStyle: TextStyle(
      fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w400,
      height: 1.45, color: AppColors.secondaryText,
    ),
  );

  // Shared picker styling used by every date/time popup in the app.
  static const DatePickerThemeData _datePickerTheme = DatePickerThemeData(
    backgroundColor: AppColors.white,
    headerBackgroundColor: AppColors.primary,
    headerForegroundColor: AppColors.white,
    dividerColor: AppColors.lightBorder,
    todayBorder: BorderSide(color: AppColors.primary),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(20)),
    ),
  );
  static const TimePickerThemeData _timePickerTheme = TimePickerThemeData(
    backgroundColor: AppColors.white,
    dialBackgroundColor: Color(0xFFE3ECF0),
    dialHandColor: AppColors.primary,
    dialTextColor: AppColors.dark,
    hourMinuteColor: Color(0xFFE3ECF0),
    hourMinuteTextColor: AppColors.dark,
    dayPeriodColor: Color(0xFFE3ECF0),
    dayPeriodTextColor: AppColors.dark,
    entryModeIconColor: AppColors.primary,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(20)),
    ),
  );

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Inter',
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        shape: CircleBorder(),
      ),
      dialogTheme: _dialogTheme,
      datePickerTheme: _datePickerTheme,
      timePickerTheme: _timePickerTheme,
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
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      shape: CircleBorder(),
    ),
    dialogTheme: _dialogTheme,
      datePickerTheme: _datePickerTheme,
      timePickerTheme: _timePickerTheme,
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
