import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'app_strings.dart';
import '../../features/profile/data/profile_preferences_repository.dart';

/// Display formatting only. Never use formatted output as an API value,
/// QR payload, document identifier, amount, or authoritative PDF source.
abstract final class AppDisplayFormats {
  static String longDate(BuildContext context, DateTime date) {
    final code = AppStrings.of(context).locale.languageCode;
    if (code == 'en') return DateFormat('MMMM d, y', 'en').format(date);
    return DateFormat.yMMMMd(code).format(date);
  }

  static String time(BuildContext context, TimeOfDay value,
      {required String english}) {
    final code = AppStrings.of(context).locale.languageCode;
    if (code == 'en') return english;
    return MaterialLocalizations.of(context).formatTimeOfDay(
      value, alwaysUse24HourFormat:
          ProfilePreferencesSession.current.value.timeFormat == '24 hours',
    );
  }

  static String money(BuildContext context, int? minorUnits, String currency,
      {required String english}) {
    final code = AppStrings.of(context).locale.languageCode;
    if (minorUnits == null || code == 'en') return english;
    // Split integer minor units instead of relabelling or converting currency.
    final absolute = minorUnits.abs();
    final whole = NumberFormat.decimalPattern(code).format(absolute ~/ 100);
    final decimal = NumberFormat.decimalPattern(code).symbols.DECIMAL_SEP;
    final fractional = (absolute % 100).toString().padLeft(2, '0');
    final sign = minorUnits < 0 ? '-' : '';
    return '$sign$whole$decimal$fractional\u00a0$currency';
  }
}
