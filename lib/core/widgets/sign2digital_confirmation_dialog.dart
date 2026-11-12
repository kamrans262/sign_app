import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'sign2digital_modal_surface.dart';
import 'sign2digital_outlined_button.dart';
import 'sign2digital_primary_button.dart';

/// Shared Sign2Digital confirmation appearance. Does not execute mutations;
/// callers confirm first and then run their existing repository operations.
abstract final class Sign2DigitalConfirmationDialog {
  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
    IconData icon = Icons.fact_check_outlined,
    String cancelLabel = 'Cancel',
    Key? confirmKey,
    Key? cancelKey,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: const Color(0x80000000),
      builder: (dialog) => Sign2DigitalModalSurface(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: const Color(0xFFE3ECF0),
              child: Icon(icon, size: 26, color: AppColors.primary),
            ),
            const SizedBox(height: 15),
            Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Inter', fontSize: 18,
                fontWeight: FontWeight.w600, color: AppColors.dark,
                decoration: TextDecoration.none)),
            const SizedBox(height: 5),
            Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Inter', fontSize: 14,
                fontWeight: FontWeight.w500, color: AppColors.placeholder,
                decoration: TextDecoration.none)),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: Sign2DigitalOutlinedButton(
                key: cancelKey,
                label: cancelLabel,
                primaryOutline: true,
                onPressed: () => Navigator.of(dialog).pop(false),
              )),
              const SizedBox(width: 15),
              Expanded(child: Sign2DigitalPrimaryButton(
                key: confirmKey,
                label: confirmLabel,
                compactLabel: true,
                onPressed: () => Navigator.of(dialog).pop(true),
              )),
            ]),
          ],
        ),
      ),
    );
    return confirmed == true;
  }
}
