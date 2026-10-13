import '../domain/job_model.dart';

/// All entries are demo-only; none are read from the device or Laravel.
abstract final class MockJobsData {
  static final List<JobModel> jobs = List<JobModel>.unmodifiable([
    for (var i = 0; i < 12; i++)
      JobModel(
        id: 'demo-active-${i + 1}',
        title: 'Terrace Renovation',
        clientId: 'dupont-construction',
        clientName: 'Dupont Construction SA',
        description: 'Glass terrace and interior renovation',
        referenceNumber: 'JOB-A-${(i + 1).toString().padLeft(3, '0')}',
        imageAsset: 'assets/images/jobs_image.jpg',
        amountChf: 24500,
        progressPercentage: 60,
        dueDate: DateTime(2026, 8, 12),
        stage: JobStage.values[i % JobStage.values.length],
        category: JobCategory.active,
      ),
    for (var i = 0; i < 8; i++)
      JobModel(
        id: 'demo-completed-${i + 1}',
        title: 'Terrace Renovation',
        clientId: 'dupont-construction',
        clientName: 'Dupont Construction SA',
        description: 'Finished terrace renovation',
        referenceNumber: 'JOB-C-${(i + 1).toString().padLeft(3, '0')}',
        imageAsset: 'assets/images/jobs_image.jpg',
        amountChf: 24500,
        progressPercentage: 100,
        dueDate: DateTime(2026, 8, 12),
        stage: JobStage.completed,
        category: JobCategory.completed,
      ),
    for (var i = 0; i < 2; i++)
      JobModel(
        id: 'demo-archived-${i + 1}',
        title: 'Terrace Renovation',
        clientId: 'dupont-construction',
        clientName: 'Dupont Construction SA',
        description: 'Archived renovation project',
        referenceNumber: 'JOB-R-${(i + 1).toString().padLeft(3, '0')}',
        imageAsset: 'assets/images/jobs_image.jpg',
        amountChf: 24500,
        progressPercentage: 100,
        dueDate: DateTime(2026, 8, 12),
        stage: JobStage.completed,
        category: JobCategory.archived,
      ),
  ]);

  static int count(JobCategory category) =>
      jobs.where((job) => job.category == category).length;

  static List<JobModel> search({
    required JobCategory category,
    required String query,
  }) => List<JobModel>.unmodifiable(
    jobs.where((job) => job.category == category && job.matches(query)),
  );
}
