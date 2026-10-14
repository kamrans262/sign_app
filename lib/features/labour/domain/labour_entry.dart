import '../../jobs/domain/job_model.dart';

enum LabourEntryKind { labour, timeSheet }
enum LabourEntryStatus { pending, approved }

class LabourEntry {
  const LabourEntry({
    required this.id,
    required this.kind,
    required this.workerName,
    required this.role,
    required this.jobId,
    required this.jobName,
    required this.date,
    required this.hours,
    required this.status,
    this.task = '',
    this.isDemo = false,
  });

  final String id;
  final LabourEntryKind kind;
  final String workerName;
  final String role;
  final String jobId;
  final String jobName;
  final DateTime date;
  final double hours;
  final LabourEntryStatus status;
  final String task;
  final bool isDemo;

  String get initials {
    final parts = workerName.trim().split(RegExp(r'\s+'));
    return parts.where((e) => e.isNotEmpty)
        .take(2).map((e) => e[0].toUpperCase()).join();
  }

  String get formattedHours => '${hours.toStringAsFixed(2)}h';
  String get statusLabel => status == LabourEntryStatus.approved
      ? 'Approved' : 'Pending';

  bool matches(String text) {
    final q = text.trim().toLowerCase();
    return q.isEmpty || [workerName, role, jobName, task, id, formattedHours]
        .any((value) => value.toLowerCase().contains(q));
  }
}

abstract class LabourRepository {
  Future<List<LabourEntry>> list();
  Future<void> save(LabourEntry entry);
  Future<List<JobModel>> jobs();
}

