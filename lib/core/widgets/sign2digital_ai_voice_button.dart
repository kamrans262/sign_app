import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'sign2digital_primary_button.dart';

/// Shared Create Job / Create Addendum voice CTA with centered label and badge.
class Sign2DigitalAiVoiceButton extends StatelessWidget {
  const Sign2DigitalAiVoiceButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 48,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Sign2DigitalPrimaryButton(
          key: const Key('create-with-ai-voice-button'),
          label: '', onPressed: onPressed,
        ),
        const IgnorePointer(child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 75),
            child: FittedBox(fit: BoxFit.scaleDown,
              child: Text('Create with AI Voice',
                style: AppTextStyles.primaryButton)),
          ),
        )),
        const Positioned(
          right: 15,
          child: IgnorePointer(child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.all(Radius.circular(5)),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              child: Text('New', style: TextStyle(
                color: AppColors.primary, fontFamily: 'Inter',
                fontSize: 12, fontWeight: FontWeight.w500)),
            ),
          )),
        ),
      ],
    ),
  );
}
