/// In-memory Job Notes UI models. No backend permissions are implied.
enum JobNoteType { text, voice, textWithAudio }

enum JobNoteVisibility { privateNote, customerFacing }

class JobNoteModel {
  const JobNoteModel({
    required this.id,
    required this.jobId,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.type,
    required this.visibility,
    this.audioPath,
  });

  final String id;
  final String jobId;
  final String title;
  final String body;
  final DateTime createdAt;
  final JobNoteType type;
  final JobNoteVisibility visibility;
  final String? audioPath;

  bool get isVoiceOnly => type == JobNoteType.voice;

  String timestampLabel(DateTime now) {
    final time =
        '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';
    final sameDay =
        now.year == createdAt.year &&
        now.month == createdAt.month &&
        now.day == createdAt.day;
    if (sameDay) {
      return 'Today $time';
    }
    final yesterday = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 1));
    if (createdAt.year == yesterday.year &&
        createdAt.month == yesterday.month &&
        createdAt.day == yesterday.day) {
      return 'Yesterday $time';
    }
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${createdAt.day} ${months[createdAt.month - 1]} ${createdAt.year} $time';
  }
}
