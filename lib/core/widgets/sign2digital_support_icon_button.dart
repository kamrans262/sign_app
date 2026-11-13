import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// One approved AI Support circle shared by Home and creation headers.
class Sign2DigitalSupportIconButton extends StatelessWidget {
  const Sign2DigitalSupportIconButton({
    super.key,
    required this.onPressed,
    this.buttonKey,
  });

  final VoidCallback? onPressed;
  final Key? buttonKey;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 48,
    height: 48,
    child: Material(
      color: AppColors.white,
      shape: const CircleBorder(
        side: BorderSide(color: AppColors.lightBorder),
      ),
      elevation: 1,
      shadowColor: const Color(0x05000000),
      child: InkWell(
        key: buttonKey,
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: const Center(
          child: Icon(Icons.support_agent_outlined,
            size: 24, color: AppColors.primary),
        ),
      ),
    ),
  );
}
