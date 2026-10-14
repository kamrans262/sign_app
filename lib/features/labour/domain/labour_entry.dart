import '../../jobs/domain/job_model.dart';
import '../../jobs/data/local_job_photo_source.dart';

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
    this.startMinutes,
    this.endMinutes,
    this.hourlyRate,
    this.photos = const [],
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
  /// Minutes after midnight, in the device's local time.
  final int? startMinutes;
  final int? endMinutes;
  final double? hourlyRate;
  final List<LocalJobPhotoSelection> photos;
  double? get totalLabourCost => hourlyRate == null ? null : hours * hourlyRate!;
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


/// Local wall-clock duration; an end earlier than start is the next day.
/// Equal times are ambiguous, so they represent zero hours and cannot save.
abstract final class LabourTimeRange {
  static int durationMinutes(int start, int end) {
    if (start < 0 || start >= 1440 || end < 0 || end >= 1440) {
      throw RangeError('Time must be within one calendar day.');
    }
    if (start == end) { return 0; }
    return (end - start + 1440) % 1440;
  }

  static String display(int minutes) =>
      '${minutes ~/ 60}:${(minutes % 60).toString().padLeft(2, '0')} hours';
}
