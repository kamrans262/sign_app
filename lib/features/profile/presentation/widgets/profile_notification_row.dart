import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Compact 25x16 notification toggle. The entire row handles taps and
/// semantics; the drawn switch doesn't claim OS notification permissions.
class ProfileNotificationRow extends StatelessWidget {
  const ProfileNotificationRow({
    super.key,
    required this.title,
    required this.enabled,
    required this.onChanged,
  });

  final String title;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Semantics(
    label: title,
    toggled: enabled,
    button: true,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onChanged(!enabled),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(children: [
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.3,
                  color: AppColors.dark,
                )),
                const SizedBox(height: 5),
                const Text('Receive important updates',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.3,
                    color: AppColors.placeholder,
                  )),
              ],
            )),
            const SizedBox(width: 10),
            ExcludeSemantics(child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: 25,
              height: 16,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: enabled ? AppColors.primary : AppColors.placeholder,
                  width: 1.5,
                ),
              ),
              child: Align(
                alignment: enabled
                    ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: enabled ? AppColors.primary : AppColors.placeholder,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            )),
          ]),
        ),
      ),
    ),
  );
}
