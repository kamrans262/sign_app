import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class Sign2DigitalRecordingControl extends StatelessWidget {
  const Sign2DigitalRecordingControl({
    super.key,
    required this.paused,
    required this.onPressed,
  });

  final bool paused;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 50,
      height: 50,
      child: Material(
        color: const Color(0xFFE3ECF0),
        borderRadius: BorderRadius.circular(25),
        child: InkWell(
          key: const Key('voice-pause-resume'),
          onTap: onPressed,
          borderRadius: BorderRadius.circular(25),
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: Container(
                key: ValueKey(paused),
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                  color: AppColors.white,
                  size: 22,
                  semanticLabel: paused
                      ? 'Resume recording'
                      : 'Pause recording',
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
