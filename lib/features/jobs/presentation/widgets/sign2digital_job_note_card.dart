import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sign2digital_outlined_container.dart';
import '../../../clients/presentation/widgets/sign2digital_status_badge.dart';
import '../../domain/job_note_model.dart';

class Sign2DigitalJobNoteCard extends StatelessWidget {
  const Sign2DigitalJobNoteCard({
    super.key,
    required this.note,
    required this.onTap,
    this.now,
    this.selectedDetail = false,
  });

  final JobNoteModel note;
  final VoidCallback onTap;
  final DateTime? now;
  /// Display the selected note for document conversion; list cards unchanged.
  final bool selectedDetail;

  Widget _selectedNote() => Sign2DigitalOutlinedContainer(
    padding: const EdgeInsets.all(20),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30, height: 30,
          decoration: const BoxDecoration(
            color: Color(0xFFE3ECF0), shape: BoxShape.circle,
          ),
          child: Center(child: SvgPicture.asset(
            'assets/icons/description.svg', width: 20, height: 20,
          )),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(note.title, style: const TextStyle(
              fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w600,
              letterSpacing: -0.3, color: AppColors.dark,
            )),
            const SizedBox(height: 5),
            Wrap(spacing: 14, runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Sign2DigitalStatusBadge(status: note.visibility ==
                    JobNoteVisibility.customerFacing ? 'Customer-facing' : 'Private'),
                Text('At ${note.createdAt.hour.toString().padLeft(2, '0')}:${note.createdAt.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 14,
                    color: AppColors.placeholder)),
              ],
            ),
            if (note.body.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(note.body, style: const TextStyle(
                fontFamily: 'Inter', fontSize: 14,
                color: AppColors.placeholder,
              )),
            ],
          ],
        )),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (selectedDetail) return _selectedNote();
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
                      const SizedBox(height: 5),
                      Text(
                        note.visibility == JobNoteVisibility.privateNote
                            ? 'Private Note' : 'Customer-facing (local only)',
                        style: const TextStyle(
                          fontFamily: 'Inter', fontSize: 12,
                          color: AppColors.primary,
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
