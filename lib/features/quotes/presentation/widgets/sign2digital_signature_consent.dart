import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

/// Shared explicit signing consent. No approval is inferred by navigation.
Future<bool> showSign2DigitalSignatureConsent(
  BuildContext context,
  String termsText,
) async {
  bool accepted = false;
  final result = await showDialog<bool>(
    context: context,
    // Force readable brand text, checkbox labels and actions on the white
    // agreement popup even when iOS appearance or app theme is dark.
    builder: (dialogContext) => Theme(
      data: AppTheme.light,
      child: StatefulBuilder(
      builder: (dialogContext, setDialogState) => AlertDialog(
        scrollable: true,
        title: const Text('Confirm agreement'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 180),
              child: SingleChildScrollView(
                child: Text(termsText.isEmpty
                    ? 'The document has no terms to accept.'
                    : termsText),
              ),
            ),
            CheckboxListTile(
              key: const Key('signature-consent-checkbox'),
              contentPadding: EdgeInsets.zero,
              value: accepted,
              title: const Text('I have read and agree to these terms.'),
              onChanged: (value) =>
                  setDialogState(() => accepted = value ?? false),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            key: const Key('signature-consent-continue'),
            onPressed: accepted
                ? () => Navigator.of(dialogContext).pop(true)
                : null,
            child: const Text('Continue'),
          ),
        ],
      ),
      ),
    ),
  );
  return result == true;
}
