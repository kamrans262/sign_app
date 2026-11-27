import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/core/localization/app_strings.dart';
import 'package:sign2digital/core/localization/stage2_workflow_strings.dart';

void main() {
  test('workflow keys and placeholders match in every locale', () {
    final french = stage2WorkflowStrings['fr']!;
    final pattern = RegExp(r'\{([A-Za-z][A-Za-z0-9_]*)\}');
    Set<String> placeholders(String text) =>
        pattern.allMatches(text).map((m) => m[1]!).toSet();
    for (final code in ['fr', 'de', 'it']) {
      final entries = stage2WorkflowStrings[code]!;
      expect(entries.keys.toSet(), french.keys.toSet());
      for (final entry in entries.entries) {
        expect(placeholders(entry.value), placeholders(entry.key));
        expect(AppStrings(Locale(code)).tr(entry.key), entry.value);
      }
    }
  });

  test('dynamic invoice and worker data are preserved verbatim', () {
    const key = 'Send the verified issued invoice PDF to {email}?';
    const email = 'client+{number}@example.com';
    for (final code in ['en', 'fr', 'de', 'it']) {
      expect(AppStrings(Locale(code)).format(key, {'email': email}),
          contains(email));
      expect(AppStrings(Locale(code)).format(
        'Confirm approval for {worker}. This locks the entry.',
        {'worker': 'Jean Müller {amount}'}), contains('Jean Müller {amount}'));
    }
  });
}
