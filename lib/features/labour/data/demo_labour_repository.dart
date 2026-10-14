import '../../jobs/data/mock_jobs.dart';
import '../../jobs/domain/job_model.dart';
import '../domain/labour_entry.dart';

/// A local-only job for the Riverside Villa Figma fixture.
/// Other job choices are sourced from the existing app's demo job list.
abstract final class LabourDemoJobs {
  static final riverside = JobModel(
    id: 'labour-demo-riverside',
    title: 'Riverside Villa',
    clientId: 'labour-demo-client',
    clientName: 'Demo Customer',
    description: 'Riverside Villa renovation (demo)',
    referenceNumber: 'JOB-L-001',
    imageAsset: 'assets/images/jobs_image.jpg',
    amountChf: 0,
    progressPercentage: 0,
    dueDate: DateTime(2026, 8, 23),
    stage: JobStage.inProgress,
    category: JobCategory.active,
  );

  static List<JobModel> get all => [riverside, ...MockJobsData.jobs];
}

class DemoLabourRepository implements LabourRepository {
  const DemoLabourRepository();
  static final Map<String, LabourEntry> _saved = {};
  static final Set<String> _deleted = {};

  static void clearLocalEntries() {
    _saved.clear();
    _deleted.clear();
  }

  static final List<LabourEntry> _fixtures = List<LabourEntry>.unmodifiable([
    for (var i = 0; i < 4; i++)
      LabourEntry(
        id: 'labour-demo-${i + 1}',
        kind: LabourEntryKind.labour,
        workerName: 'Alex Martin',
        role: 'electrician',
        jobId: LabourDemoJobs.riverside.id,
        jobName: LabourDemoJobs.riverside.title,
        date: DateTime(2026, 8, 23, 10, 0),
        hours: i == 1 ? 9 : 6,
        status: i == 1 ? LabourEntryStatus.pending
            : LabourEntryStatus.approved,
        isDemo: true,
      ),
    LabourEntry(
      id: 'timesheet-demo-1',
      kind: LabourEntryKind.timeSheet,
      workerName: 'Sophie Laurent',
      role: 'carpenter',
      jobId: LabourDemoJobs.riverside.id,
      jobName: LabourDemoJobs.riverside.title,
      date: DateTime(2026, 8, 22),
      hours: 7.5,
      status: LabourEntryStatus.pending,
      task: 'Joinery work',
      isDemo: true,
    ),
    LabourEntry(
      id: 'timesheet-demo-2',
      kind: LabourEntryKind.timeSheet,
      workerName: 'Marc Dupont',
      role: 'site supervisor',
      jobId: LabourDemoJobs.riverside.id,
      jobName: LabourDemoJobs.riverside.title,
      date: DateTime(2026, 8, 21),
      hours: 8,
      status: LabourEntryStatus.approved,
      task: 'Site supervision',
      isDemo: true,
    ),
  ]);

  @override
  Future<List<LabourEntry>> list() async {
    return [
      for (final fixture in _fixtures)
        if (!_saved.containsKey(fixture.id) && !_deleted.contains(fixture.id)) fixture,
      ..._saved.values,
    ];
  }

  @override
  Future<List<JobModel>> jobs() async => LabourDemoJobs.all;

  @override
  Future<void> save(LabourEntry entry) async {
    if (entry.id.trim().isEmpty || entry.workerName.trim().isEmpty ||
        entry.jobId.trim().isEmpty || entry.role.trim().isEmpty ||
        !entry.hours.isFinite || entry.hours <= 0 || entry.hours > 24 ||
        entry.status != LabourEntryStatus.pending) {
      throw ArgumentError('Invalid local time entry');
    }
    if (_saved.containsKey(entry.id) ||
        _fixtures.any((fixture) => fixture.id == entry.id)) {
      throw StateError('Entry already exists');
    }
    final now = DateTime.now();
    _saved[entry.id] = entry.copyWith(history: [
      ...entry.history,
      LabourHistoryEvent(
        id: 'created-${entry.id}-${now.microsecondsSinceEpoch}',
        title: 'Labour entry created',
        occurredAt: now,
      ),
    ]);
  }

  LabourEntry? _find(String id) {
    if (_deleted.contains(id)) { return null; }
    final saved = _saved[id];
    if (saved != null) { return saved; }
    for (final fixture in _fixtures) {
      if (fixture.id == id) { return fixture; }
    }
    return null;
  }

  @override
  Future<void> update(LabourEntry entry) async {
    final previous = _find(entry.id);
    if (previous == null) {
      throw StateError('Time entry no longer exists.');
    }
    if (previous.status != LabourEntryStatus.pending ||
        entry.status != previous.status || entry.kind != previous.kind ||
        entry.workerName.trim().isEmpty || entry.role.trim().isEmpty ||
        entry.jobId.trim().isEmpty || !entry.hours.isFinite ||
        entry.hours <= 0 || entry.hours > 24) {
      throw StateError('Only valid pending time entries can be edited.');
    }
    final now = DateTime.now();
    _saved[entry.id] = entry.copyWith(history: [
      ...previous.history,
      LabourHistoryEvent(
        id: 'updated-${entry.id}-${now.microsecondsSinceEpoch}',
        title: 'Labour entry updated',
        occurredAt: now,
      ),
    ]);
  }

  @override
  Future<void> delete(String id) async {
    final record = _find(id);
    if (record == null) {
      throw StateError('Time entry no longer exists.');
    }
    if (record.status != LabourEntryStatus.pending) {
      throw StateError('Approved time entries cannot be deleted.');
    }
    _saved.remove(id);
    _deleted.add(id);
  }
}
