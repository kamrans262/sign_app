import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/sign2digital_modal_surface.dart';
import '../../../../core/widgets/sign2digital_outlined_button.dart';
import '../../../../core/widgets/sign2digital_primary_button.dart';

/// Shared explicit signing consent. No approval is inferred by navigation.
/// Keep the exact document terms visible and require an explicit checkbox.
Future<bool> showSign2DigitalSignatureConsent(
  BuildContext context,
  String termsText,
) async {
  bool accepted = false;
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => Sign2DigitalModalSurface(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Confirm agreement',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.dark,
              ),
            ),
            const SizedBox(height: 20),
            const Text('Terms & Conditions', style: AppTextStyles.fieldLabel),
            const SizedBox(height: 10),
            Container(
              key: const Key('signature-consent-terms'),
              width: double.infinity,
              constraints: const BoxConstraints(maxHeight: 160),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.lightBorder),
                borderRadius: BorderRadius.circular(10),
              ),
              child: SingleChildScrollView(
                child: Text(
                  termsText.isEmpty
                      ? 'The document has no terms to accept.'
                      : termsText,
                  textAlign: TextAlign.left,
                  style: AppTextStyles.fieldInput,
                ),
              ),
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              key: const Key('signature-consent-checkbox'),
              value: accepted,
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              activeColor: AppColors.primary,
              dense: true,
              title: const Text(
                'I have read and agree to these terms.',
                style: AppTextStyles.fieldInput,
              ),
              onChanged: (value) =>
                  setDialogState(() => accepted = value ?? false),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Sign2DigitalOutlinedButton(
                    label: 'Cancel',
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Sign2DigitalPrimaryButton(
                    key: const Key('signature-consent-continue'),
                    label: 'Continue',
                    enabled: accepted,
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  return result == true;
}
