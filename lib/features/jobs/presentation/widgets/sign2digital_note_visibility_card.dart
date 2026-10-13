import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/job_note_model.dart';

/// An accessible and reusable frontend visibility preference control.
/// Real access enforcement must be done by the future backend.
class Sign2DigitalNoteVisibilityCard extends StatelessWidget {
  const Sign2DigitalNoteVisibilityCard({
    super.key,
    required this.visibility,
    required this.selected,
    required this.onTap,
  });

  final JobNoteVisibility visibility;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isPrivate = visibility == JobNoteVisibility.privateNote;
    final label = isPrivate ? 'Private Note' : 'Costumer Facing';
    final description = isPrivate
        ? 'Only visible to your team'
        : 'Visible to your costumers';
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: const Color(0xFFE3ECF0),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          key: Key(
            isPrivate ? 'note-visibility-private' : 'note-visibility-customer',
          ),
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            constraints: const BoxConstraints(minHeight: 72),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? const Color(0x33166282) : Colors.transparent,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: isPrivate
                      ? const Icon(
                          Icons.mic_none_rounded,
                          color: AppColors.primary,
                          size: 24,
                        )
                      : SvgPicture.asset(
                          'assets/icons/team_members.svg',
                          width: 24,
                          height: 24,
                        ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        softWrap: true,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 15,
                          letterSpacing: -0.3,
                          fontWeight: FontWeight.w500,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        description,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.placeholder,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
