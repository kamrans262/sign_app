// Sign2Digital Login UI Package — typographic primitives (Inter).
import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class AppTextStyles {
  static const TextStyle heading = TextStyle(
    fontFamily: 'Inter',
    fontSize: 24,
    height: 1.0,
    fontWeight: FontWeight.w700,
    color: AppColors.dark,
  );

  static const TextStyle subtitle = TextStyle(
    fontFamily: 'Inter',
    fontSize: 14,
    height: 1.0,
    fontWeight: FontWeight.w500,
    color: AppColors.secondaryText,
  );

  static const TextStyle fieldLabel = TextStyle(
    fontFamily: 'Inter',
    fontSize: 16,
    height: 1.0,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
    color: AppColors.dark,
  );

  static const TextStyle fieldInput = TextStyle(
    fontFamily: 'Inter',
    fontSize: 14,
    height: 1.28,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.3,
    color: AppColors.dark,
  );

  static const TextStyle fieldHint = TextStyle(
    fontFamily: 'Inter',
    fontSize: 14,
    height: 1.28,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.3,
    color: AppColors.placeholder,
  );

  static const TextStyle outlinedButton = TextStyle(
    fontFamily: 'Inter',
    fontSize: 16,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.3,
    color: AppColors.dark,
  );

  static const TextStyle primaryButton = TextStyle(
    fontFamily: 'Inter',
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: AppColors.white,
  );

  static const TextStyle small = TextStyle(
    fontFamily: 'Inter',
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.secondaryText,
  );

  static const TextStyle smallLink = TextStyle(
    fontFamily: 'Inter',
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.primary,
  );

  static const TextStyle footer = TextStyle(
    fontFamily: 'Inter',
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.secondaryText,
  );

  static const TextStyle footerLink = TextStyle(
    fontFamily: 'Inter',
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.primary,
  );
}
