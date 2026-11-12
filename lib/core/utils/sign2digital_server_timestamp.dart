/// Parses a server timestamp as an instant and converts it for device display.
///
/// Laravel stores database timestamps in UTC. Query Builder often serializes
/// them as 'yyyy-MM-dd HH:mm:ss' *without* a timezone suffix. Dart otherwise
/// assumes the device's timezone and displays the UTC clock unconverted.
///
/// Do not use for date-only business fields (quote date, report date, invoice
/// date, due date). Those calendar dates must never shift between timezones.
abstract final class Sign2DigitalServerTimestamp {
  static DateTime? tryParse(Object? raw) {
    if (raw == null) return null;
    final text = raw.toString().trim();
    if (text.isEmpty ||
        RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text)) {
      return null;
    }
    final iso = text.replaceFirst(' ', 'T');
    // Explicit Z or offsets already define an instant. Unsuffixed database
    // datetimes are UTC because Laravel's configured timezone is UTC.
    final hasTimezone = RegExp(r'(?:[zZ]|[+-]\d{2}(?::?\d{2})?)$')
        .hasMatch(iso);
    final date = DateTime.tryParse(hasTimezone ? iso : '${iso}Z');
    return date?.toLocal();
  }
}
