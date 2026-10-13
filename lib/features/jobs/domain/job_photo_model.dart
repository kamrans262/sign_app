import 'dart:typed_data';

enum JobPhotoCategory { before, during, after }

/// Frontend-only job photo. [bytes] are local, not sent to a server.
/// In a future backend, map this model to persisted attachment metadata.
class JobPhotoModel {
  const JobPhotoModel({
    required this.id,
    required this.jobId,
    required this.title,
    required this.createdAt,
    required this.category,
    this.assetPath,
    this.bytes,
    this.sourceKey,
    this.caption,
  }) : assert(assetPath != null || bytes != null);

  final String id;
  final String jobId;
  final String title;
  final String? assetPath;
  final Uint8List? bytes;
  final String? sourceKey;
  final String? caption;
  final DateTime createdAt;
  final JobPhotoCategory category;

  JobPhotoModel withCategory(JobPhotoCategory value) => JobPhotoModel(
    id: id,
    jobId: jobId,
    title: title,
    createdAt: createdAt,
    category: value,
    assetPath: assetPath,
    bytes: bytes,
    sourceKey: sourceKey,
    caption: caption,
  );

  static String formattedDate(DateTime date) {
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
    String two(int n) => n.toString().padLeft(2, '0');
    return '${date.day} ${months[date.month - 1]} ${date.year} '
        '${two(date.hour)}:${two(date.minute)}';
  }

  static List<JobPhotoModel> demoFor(String jobId) => [
    for (var i = 0; i < 4; i++)
      JobPhotoModel(
        id: 'demo-$jobId-$i',
        jobId: jobId,
        title: 'Front View',
        assetPath: i.isEven ? 'assets/images/jp1.jpg' : 'assets/images/jp2.jpg',
        createdAt: DateTime(2026, 3, 12, 10),
        category: switch (i) {
          0 => JobPhotoCategory.before,
          1 => JobPhotoCategory.during,
          2 => JobPhotoCategory.after,
          _ => JobPhotoCategory.during,
        },
      ),
  ];
}
