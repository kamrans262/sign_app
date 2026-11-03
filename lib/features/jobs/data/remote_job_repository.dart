import '../../../core/services/active_company_session.dart';
import '../../../core/services/sign_api_client.dart';
import '../../auth/data/mobile_auth_repository.dart';
import '../domain/create_job_draft.dart';
import '../domain/job_details_model.dart';
import '../domain/job_model.dart';

/// Authenticated M5 repository. Never mix demo jobs or another company's data
/// into responses. The Laravel server independently enforces membership/RBAC.
class RemoteJobRepository {
  RemoteJobRepository({SignApiClient? api})
      : _api = api ?? MobileAuthRepository.shared.api;

  static final RemoteJobRepository shared = RemoteJobRepository();
  final SignApiClient _api;

  static int _id(Object? value) =>
      value is int ? value : int.tryParse('$value') ?? 0;

  static Map<String, dynamic> _data(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw const SignApiException('Invalid job server response.');
    }
    return data;
  }

  int _company() {
    final id = ActiveCompanySession.companyId;
    if (id == null || id <= 0) {
      throw const SignApiException('Select a company before managing jobs.');
    }
    return id;
  }

  JobModel _parse(Map<String, dynamic> raw, int company) {
    final id = _id(raw['id']);
    if (id <= 0 || _id(raw['company_id']) != company ||
        _id(raw['client_id']) <= 0) {
      throw const SignApiException('Invalid or cross-company job response.');
    }
    final budget = raw['budget_chf'];
    final category = switch (raw['category']) {
      'active' => JobCategory.active,
      'completed' => JobCategory.completed,
      'archived' => JobCategory.archived,
      _ => throw const SignApiException('Invalid job category.'),
    };
    final stage = switch (raw['stage']) {
      'planning' => JobStage.planning,
      'in_progress' => JobStage.inProgress,
      'completed' => JobStage.completed,
      'overdue' => JobStage.overdue,
      _ => throw const SignApiException('Invalid job stage.'),
    };
    final date = DateTime.tryParse((raw['due_date'] ?? '').toString());
    if (date == null) {
      throw const SignApiException('Invalid job due date.');
    }
    final progress = num.tryParse('${raw['progress_percentage']}');
    if (progress == null || progress < 0 || progress > 100) {
      throw const SignApiException('Invalid job progress.');
    }
    final parsedBudget = budget == null ? null : num.tryParse('$budget');
    if (budget != null && (parsedBudget == null || parsedBudget < 0)) {
      throw const SignApiException('Invalid job budget.');
    }
    return JobModel(
      id: '$id',
      title: (raw['title'] ?? '').toString(),
      clientId: '${_id(raw['client_id'])}',
      clientName: (raw['client_name'] ?? '').toString(),
      description: (raw['description'] ?? '').toString(),
      referenceNumber: (raw['reference_number'] ?? '').toString(),
      imageAsset: 'assets/images/jobs_image.jpg',
      amountChf: parsedBudget?.round() ?? 0,
      hasBudget: parsedBudget != null,
      progressPercentage: progress.toDouble(),
      dueDate: date,
      startDate: DateTime.tryParse((raw['start_date'] ?? '').toString()),
      address: (raw['address'] ?? '').toString(),
      budgetChfExact: parsedBudget?.toDouble(),
      teamMemberIds: (raw['team_member_ids'] is List)
          ? (raw['team_member_ids'] as List).map((item) => '$item').toList()
          : const [],
      stage: stage,
      category: category,
    );
  }

  void _ensureCompany(int initial) {
    if (ActiveCompanySession.companyId != initial) {
      throw const SignApiException('Company changed while loading jobs.');
    }
  }

  Future<List<JobModel>> listJobs() async {
    final company = _company();
    final result = <JobModel>[];
    for (final category in JobCategory.values) {
      var page = 1;
      while (true) {
        final data = _data(await _api.get('/api/v1/jobs',
          companyScoped: true,
          queryParameters: {
            'category': category.name,
            'page': '$page',
            'per_page': '100',
          },
        ));
        _ensureCompany(company);
        final raw = data['jobs'];
        if (raw is! List || raw.any((item) => item is! Map<String, dynamic>)) {
          throw const SignApiException('Invalid jobs list.');
        }
        result.addAll(raw.cast<Map<String, dynamic>>()
            .map((item) => _parse(item, company)));
        final pagination = data['pagination'];
        if (pagination is! Map<String, dynamic>) {
          throw const SignApiException('Missing job pagination.');
        }
        final last = _id(pagination['last_page']);
        if (last < page || last > 10000) {
          throw const SignApiException('Invalid job pagination.');
        }
        if (page == last) break;
        page++;
      }
    }
    _ensureCompany(company);
    return List<JobModel>.unmodifiable(result);
  }

  static String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  Future<JobModel> createJob(CreateJobDraft draft) async {
    final company = _company();
    final client = int.tryParse(draft.clientId);
    if (client == null || client <= 0) {
      throw const SignApiException('Choose a saved client in this company.');
    }
    if (draft.description.trim().isEmpty ||
        draft.endDate.isBefore(draft.startDate)) {
      throw const SignApiException('Provide a description and valid job dates.');
    }
    final members = <int>[];
    for (final id in draft.teamMemberIds) {
      final memberId = int.tryParse(id);
      if (memberId == null || memberId <= 0) {
        throw const SignApiException('Choose real company team members.');
      }
      members.add(memberId);
    }
    final data = _data(await _api.post('/api/v1/jobs',
      companyScoped: true,
      data: {
        'client_id': client,
        'description': draft.description,
        'address': draft.address,
        'start_date': _date(draft.startDate),
        'due_date': _date(draft.endDate),
        'budget_chf': draft.budgetChf,
        'team_member_ids': members,
      },
    ));
    _ensureCompany(company);
    final raw = data['job'];
    if (raw is! Map<String, dynamic>) {
      throw const SignApiException('Invalid saved job response.');
    }
    return _parse(raw, company);
  }

  Future<JobDetailsModel> loadDetails(JobModel job) async {
    final company = _company();
    final id = int.tryParse(job.id);
    if (id == null || id <= 0) {
      throw const SignApiException('This is not a saved job.');
    }
    final data = _data(await _api.get('/api/v1/jobs/$id',
      companyScoped: true));
    _ensureCompany(company);
    final raw = data['job'];
    if (raw is! Map<String, dynamic> || _id(raw['id']) != id) {
      throw const SignApiException('Invalid job details response.');
    }
    final saved = _parse(raw, company);
    // Quote/expense/labour/invoice modules are not yet persistent. Their
    // figures must show unavailable, not fictional screenshot amounts.
    final financials = data['financials'];
    if (financials is! Map<String, dynamic> ||
        financials.values.any((value) => value != null)) {
      throw const SignApiException('Unexpected job financial data.');
    }
    return JobDetailsModel.liveUnconnected(saved);
  }

  Future<JobModel> updateDraft(JobModel job, CreateJobDraft draft) async {
    final id = int.tryParse(job.id);
    final client = int.tryParse(draft.clientId);
    if (id == null || id <= 0 || client == null || client <= 0) {
      throw const SignApiException('Select a saved job and client.');
    }
    if (draft.description.trim().isEmpty ||
        draft.endDate.isBefore(draft.startDate)) {
      throw const SignApiException('Provide a description and valid dates.');
    }
    final members = <int>[];
    for (final raw in draft.teamMemberIds) {
      final parsed = int.tryParse(raw);
      if (parsed == null || parsed <= 0) {
        throw const SignApiException('Select real company team members.');
      }
      members.add(parsed);
    }
    final description = draft.description.trim();
    final firstLine = description.split(RegExp(r'\r?\n')).first.trim();
    return updateJob(id, {
      'client_id': client,
      'title': firstLine.length > 255 ? firstLine.substring(0, 255) : firstLine,
      'description': description,
      'address': draft.address.trim(),
      'start_date': _date(draft.startDate),
      'due_date': _date(draft.endDate),
      'budget_chf': draft.budgetChf,
      'team_member_ids': members,
    });
  }

  Future<JobModel> updateJob(int id, Map<String, dynamic> changes) async {
    final company = _company();
    final data = _data(await _api.request('PATCH', '/api/v1/jobs/$id',
      data: changes, companyScoped: true));
    _ensureCompany(company);
    final raw = data['job'];
    if (raw is! Map<String, dynamic> || _id(raw['id']) != id) {
      throw const SignApiException('Invalid updated job response.');
    }
    return _parse(raw, company);
  }

  Future<void> archiveJob(int id) async {
    final company = _company();
    await _api.delete('/api/v1/jobs/$id', companyScoped: true);
    _ensureCompany(company);
  }

  Future<JobModel> restoreJob(int id) async {
    final company = _company();
    final data = _data(await _api.post('/api/v1/jobs/$id/restore',
      companyScoped: true));
    _ensureCompany(company);
    final raw = data['job'];
    if (raw is! Map<String, dynamic> || _id(raw['id']) != id) {
      throw const SignApiException('Invalid restored job response.');
    }
    return _parse(raw, company);
  }
}
