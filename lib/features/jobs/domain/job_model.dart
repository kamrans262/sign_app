/// The Jobs UI uses local models. API DTOs can be mapped into these later.
enum JobCategory { active, completed, archived }

enum JobStage { inProgress, planning, completed, overdue }

class JobModel {
  const JobModel({
    required this.id,
    required this.title,
    required this.clientId,
    required this.clientName,
    required this.description,
    required this.referenceNumber,
    required this.imageAsset,
    required this.amountChf,
    required this.progressPercentage,
    required this.dueDate,
    required this.stage,
    required this.category,
  });

  final String id;
  final String title;
  final String clientId;
  final String clientName;
  final String description;
  final String referenceNumber;
  final String imageAsset;
  final int amountChf;
  final double progressPercentage;
  final DateTime dueDate;
  final JobStage stage;
  final JobCategory category;

  String get statusLabel => switch (stage) {
    JobStage.inProgress => 'In progress',
    JobStage.planning => 'Planning',
    JobStage.completed => 'Completed',
    JobStage.overdue => 'Over due',
  };

  String get formattedAmount {
    final value = amountChf.toString();
    final grouped = value.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => ',',
    );
    return 'CHF $grouped';
  }

  String get formattedDueDate {
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
    return 'Due ${dueDate.day} ${months[dueDate.month - 1]}, ${dueDate.year}';
  }

  bool matches(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return true;
    }
    return title.toLowerCase().contains(normalized) ||
        clientName.toLowerCase().contains(normalized) ||
        referenceNumber.toLowerCase().contains(normalized) ||
        description.toLowerCase().contains(normalized);
  }
}
