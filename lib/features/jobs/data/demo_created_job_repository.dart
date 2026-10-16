import '../domain/create_job_draft.dart';
import '../domain/job_model.dart';

/// Jobs created in the current dashboard session. No Laravel write or
/// durable device persistence takes place in this repository.
class DemoCreatedJobRepository {
  final List<JobModel> _created = <JobModel>[];
  final Map<String, CreateJobDraft> _drafts = <String, CreateJobDraft>{};
  int _nextId = 1;

  List<JobModel> get jobs => List<JobModel>.unmodifiable(_created);

  List<JobModel> forClient(String clientId) => List<JobModel>.unmodifiable(
    _created.where((job) => job.clientId == clientId),
  );

  CreateJobDraft? draftFor(String jobId) => _drafts[jobId];

  JobModel create(CreateJobDraft draft) {
    if (draft.clientId.trim().isEmpty || draft.description.trim().isEmpty) {
      throw ArgumentError('Client and job description are required.');
    }
    if (draft.endDate.isBefore(draft.startDate)) {
      throw ArgumentError('End date must not precede start date.');
    }

    final number = _nextId++;
    final id = 'local-job-$number';
    // Create Job currently has a description field but no separate title.
    final firstLine = draft.description.trim().split(RegExp(r'\r?\n')).first;
    final title = firstLine.length > 65
        ? '${firstLine.substring(0, 65).trimRight()}…'
        : firstLine;
    final job = JobModel(
      id: id,
      title: title,
      clientId: draft.clientId,
      clientName: draft.clientName,
      description: draft.description,
      referenceNumber: 'JOB-L-${number.toString().padLeft(3, '0')}',
      imageAsset: 'assets/images/jobs_image.jpg',
      amountChf: draft.budgetChf?.round() ?? 0,
      progressPercentage: 0,
      dueDate: draft.endDate,
      stage: JobStage.planning,
      category: JobCategory.active,
    );
    _drafts[id] = draft;
    _created.insert(0, job);
    return job;
  }
}
