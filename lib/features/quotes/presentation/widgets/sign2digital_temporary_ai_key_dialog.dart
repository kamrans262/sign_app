import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Reusable temporary-key prompt for development-time direct OpenAI calls.
/// A key never leaves this dialog except as the caller's in-memory return value.
abstract final class Sign2DigitalTemporaryAiKeyDialog {
  static Future<String?> request(
    BuildContext context, {
    String title = 'Connect Quote AI',
    String message = 'For private development testing: enter your OpenAI API key '
      'to analyze this quote input. The key is kept in memory only. '
      'Do not use this method in a published app.',
  }) {
    String draft = '';
    bool visible = false;
    String? error;
    return showDialog<String>(
      context: context,
      // The approved popup stays white even when iOS/system theme is dark.
      // Apply matching light input and icon colors inside that surface.
      builder: (dialogContext) => Theme(
        data: AppTheme.light,
        child: StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text(title),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(message),
                  const SizedBox(height: 15),
                  TextFormField(
                    key: const Key('quote-openai-api-key'),
                    obscureText: !visible,
                    enableSuggestions: false,
                    autocorrect: false,
                    keyboardType: TextInputType.visiblePassword,
                    onChanged: (value) => draft = value,
                    decoration: InputDecoration(
                      labelText: 'OpenAI API key',
                      border: const OutlineInputBorder(),
                      errorText: error,
                      suffixIcon: IconButton(
                        tooltip: visible ? 'Hide API key' : 'Show API key',
                        icon: Icon(visible
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined),
                        onPressed: () => update(() => visible = !visible),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const Key('quote-connect-ai'),
              onPressed: () {
                final key = draft.trim();
                if (key.isEmpty ||
                    RegExp(r'[\x00-\x20\x7F]').hasMatch(key)) {
                  update(() => error = 'Paste a valid API key.');
                  return;
                }
                Navigator.of(dialogContext).pop(key);
              },
              child: const Text('Generate with AI'),
            ),
          ],
        ),
        ),
      ),
    );
  }
}
