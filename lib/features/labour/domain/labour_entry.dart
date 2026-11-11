import '../../jobs/domain/job_model.dart';
import '../../jobs/data/local_job_photo_source.dart';

enum LabourEntryKind { labour, timeSheet }
enum LabourEntryStatus { pending, approved, voided }

/// An actual event recorded by the local repository or a future API.
class LabourHistoryEvent {
  const LabourHistoryEvent({
    required this.id,
    required this.title,
    required this.occurredAt,
    this.actorName,
    this.description,
  });
  final String id;
  final String title;
  final DateTime occurredAt;
  final String? actorName;
  final String? description;
}

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
    this.workerId,
    this.lockVersion = 1,
    this.source = 'manual',
    this.photos = const [],
    this.approvedBy,
    this.approvedAt,
    this.history = const [],
    this.isDemo = false,
    this.canApprove = false,
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
  final int? workerId;
  final int lockVersion;
  final String source;
  final List<LocalJobPhotoSelection> photos;
  final String? approvedBy;
  final DateTime? approvedAt;
  final List<LabourHistoryEvent> history;
  double? get totalLabourCost => hourlyRate == null ? null : hours * hourlyRate!;
  final bool isDemo;
  /// Company reviewer capability verified by the server for this detail.
  final bool canApprove;

  /// Keeps the same record ID and protected approval status on edit.
  LabourEntry copyWith({
    String? workerName,
    String? role,
    String? jobId,
    String? jobName,
    DateTime? date,
    double? hours,
    String? task,
    int? startMinutes,
    int? endMinutes,
    double? hourlyRate,
    int? workerId,
    List<LocalJobPhotoSelection>? photos,
    List<LabourHistoryEvent>? history,
    bool? canApprove,
  }) => LabourEntry(
    id: id,
    kind: kind,
    workerName: workerName ?? this.workerName,
    role: role ?? this.role,
    jobId: jobId ?? this.jobId,
    jobName: jobName ?? this.jobName,
    date: date ?? this.date,
    hours: hours ?? this.hours,
    task: task ?? this.task,
    startMinutes: startMinutes ?? this.startMinutes,
    endMinutes: endMinutes ?? this.endMinutes,
    hourlyRate: hourlyRate ?? this.hourlyRate,
    workerId: workerId ?? this.workerId,
    lockVersion: lockVersion, source: source,
    photos: photos ?? this.photos,
    history: history ?? this.history,
    status: status,
    approvedBy: approvedBy,
    approvedAt: approvedAt,
    isDemo: isDemo,
    canApprove: canApprove ?? this.canApprove,
  );

  String get initials {
    final parts = workerName.trim().split(RegExp(r'\s+'));
    return parts.where((e) => e.isNotEmpty)
        .take(2).map((e) => e[0].toUpperCase()).join();
  }

  String get formattedHours => '${hours.toStringAsFixed(2)}h';
  String get statusLabel => switch (status) {
    LabourEntryStatus.pending => 'Pending',
    LabourEntryStatus.approved => 'Approved',
    LabourEntryStatus.voided => 'Void',
  };

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

  /// Older repositories remain compatible until their backend supports edits.
  Future<void> update(LabourEntry entry) async =>
      throw UnsupportedError('Labour editing is not available.');

  Future<void> delete(String id) async =>
      throw UnsupportedError('Labour deletion is not available.');
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
