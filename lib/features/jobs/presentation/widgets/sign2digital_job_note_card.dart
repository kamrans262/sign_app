import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sign2digital_outlined_container.dart';
import '../../domain/job_note_model.dart';

class Sign2DigitalJobNoteCard extends StatelessWidget {
  const Sign2DigitalJobNoteCard({
    super.key,
    required this.note,
    required this.onTap,
    this.now,
  });

  final JobNoteModel note;
  final VoidCallback onTap;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final microphone = note.type != JobNoteType.text;
    return Semantics(
      button: true,
      label: 'Open ${note.title}',
      child: Material(
        color: AppColors.white,
        child: InkWell(
          key: Key('job-note-${note.id}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Sign2DigitalOutlinedContainer(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE3ECF0),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: microphone
                      ? const Icon(
                          Icons.mic_none_rounded,
                          size: 24,
                          color: AppColors.primary,
                        )
                      : SvgPicture.asset(
                          'assets/icons/description.svg',
                          width: 24,
                          height: 24,
                        ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        note.title,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          letterSpacing: -0.3,
                          color: AppColors.dark,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        note.body,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.placeholder,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        note.timestampLabel(now ?? DateTime.now()),
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: AppColors.placeholder,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 22,
                  color: AppColors.secondaryText,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
