// Sign2Digital Login UI Package — shared project palette.
import 'package:flutter/material.dart';

abstract final class AppColors {
  static const Color primary = Color(0xFF166282);
  static const Color dark = Color(0xFF122536);
  static const Color secondaryText = Color(0xFF667085);
  static const Color placeholder = Color(0xFF8A9AA8);
  static const Color white = Color(0xFFFFFFFF);
  // #D9E2EA at 30% and #8A9AA8 at 13%, respectively.
  static const Color lightBorder = Color(0x4DD9E2EA);
  static const Color divider = Color(0x218A9AA8);

  // Retain prior splash-screen color names so the previous UI keeps working.
  static const Color deepBlue = dark;
  static const Color ink = dark;
  static const Color gradientStart = Color(0xFFF8FBFF);
  static const Color gradientEnd = Color(0xFFEAF5F9);
  static const Color border = lightBorder;
}
