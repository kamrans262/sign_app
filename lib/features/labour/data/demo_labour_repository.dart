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

  static void clearLocalEntries() => _saved.clear();

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
        if (!_saved.containsKey(fixture.id)) fixture,
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
    _saved[entry.id] = entry;
  }
}
