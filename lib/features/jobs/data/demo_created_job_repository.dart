import '../domain/create_job_draft.dart';
import '../domain/job_model.dart';

/// Session-only jobs created from the existing Create Job form.
/// No Laravel writes or durable persistence are implied.
class DemoCreatedJobRepository {
  final List<JobModel> _jobs = <JobModel>[];
  final Map<String, CreateJobDraft> _drafts = <String, CreateJobDraft>{};
  int _nextId = 1;

  List<JobModel> get jobs => List<JobModel>.unmodifiable(_jobs);

  List<JobModel> forClient(String clientId) => List<JobModel>.unmodifiable(
        _jobs.where((job) => job.clientId == clientId),
      );

  CreateJobDraft? originalDraft(String jobId) => _drafts[jobId];

  JobModel create(CreateJobDraft draft) {
    if (draft.clientId.trim().isEmpty || draft.description.trim().isEmpty) {
      throw ArgumentError('A client and job description are required.');
    }
    if (draft.endDate.isBefore(draft.startDate)) {
      throw ArgumentError('Job end date cannot precede the start date.');
    }
    final sequence = _nextId++;
    final id = 'local-job-$sequence';
    final firstLine = draft.description.trim().split(RegExp(r'\r?\n')).first.trim();
    final title = firstLine.length > 65
        ? '${firstLine.substring(0, 65).trimRight()}…'
        : firstLine;
    final job = JobModel(
      id: id,
      title: title,
      clientId: draft.clientId,
      clientName: draft.clientName,
      description: draft.description,
      referenceNumber: 'JOB-L-${sequence.toString().padLeft(3, '0')}',
      imageAsset: 'assets/images/jobs_image.jpg',
      amountChf: draft.budgetChf?.round() ?? 0,
      progressPercentage: 0,
      dueDate: draft.endDate,
      stage: JobStage.planning,
      category: JobCategory.active,
    );
    _drafts[id] = draft;
    _jobs.insert(0, job);
    return job;
  }
}
