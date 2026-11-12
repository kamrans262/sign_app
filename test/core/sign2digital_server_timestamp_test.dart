import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/core/utils/sign2digital_server_timestamp.dart';

void main() {
  test('Laravel UTC datetimes without timezone become correct instants', () {
    final expected = DateTime.utc(2026, 11, 12, 16, 45, 9);
    for (final wire in [
      '2026-11-12 16:45:09',
      '2026-11-12T16:45:09',
      '2026-11-12T16:45:09Z',
      '2026-11-12T16:45:09+00:00',
      '2026-11-12T21:45:09+05:00',
    ]) {
      final parsed = Sign2DigitalServerTimestamp.tryParse(wire);
      expect(parsed?.microsecondsSinceEpoch, expected.microsecondsSinceEpoch,
          reason: 'Unexpected instant from $wire');
      expect(parsed?.isUtc, isFalse,
          reason: 'UI dates must be converted to device-local time');
    }
  });

  test('Never invent times for date-only or invalid records', () {
    for (final value in [
      null, '', ' ', '2026-11-12', 'not-a-timestamp',
    ]) {
      expect(Sign2DigitalServerTimestamp.tryParse(value), isNull);
    }
  });

  test('UTC midnight crosses date boundaries only when it is a timestamp', () {
    final actual = Sign2DigitalServerTimestamp.tryParse(
      '2026-11-12 23:45:00',
    );
    expect(actual?.microsecondsSinceEpoch,
        DateTime.utc(2026, 11, 12, 23, 45).microsecondsSinceEpoch);
  });
}
