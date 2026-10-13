// Sign2Digital Theme Compatibility Regression
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/core/theme/app_colors.dart';

void main() {
  test('Login widgets use the canonical Sign2Digital theme constants', () {
    expect(AppColors.primary, const Color(0xFF166282));
    expect(AppColors.dark, const Color(0xFF122536));
    expect(AppColors.secondaryText, const Color(0xFF667085));
    expect(AppColors.placeholder, const Color(0xFF8A9AA8));
    expect(AppColors.white, const Color(0xFFFFFFFF));
    expect(AppColors.lightBorder, const Color(0x4DD9E2EA));
    expect(AppColors.divider, const Color(0x218A9AA8));
  });
}
