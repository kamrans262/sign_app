import 'dart:typed_data';
import 'dart:io';
import 'package:crypto/crypto.dart';

import '../../../core/services/active_company_session.dart';
import '../../../core/services/sign_api_client.dart';
import '../../auth/data/mobile_auth_repository.dart';
import '../../jobs/data/local_job_photo_source.dart';
import '../../jobs/data/remote_job_media_repository.dart';
import '../../jobs/domain/job_photo_model.dart';
import '../domain/document_record.dart';

/// Authenticated M12 report lifecycle; approved PDFs come from the M9 catalog.
class RemoteSiteReportRepository implements DocumentRepository {
  RemoteSiteReportRepository({SignApiClient? api})
      : _api = api ?? MobileAuthRepository.shared.api;
  static final shared = RemoteSiteReportRepository();
  final SignApiClient _api;

  int _company() {
    final id = ActiveCompanySession.companyId;
    if (id == null || id <= 0) {
      throw const SignApiException('Select a company before managing reports.');
    }
    return id;
  }

  void _check(int id) {
    if (ActiveCompanySession.companyId != id) {
      throw const SignApiException('Company changed while loading reports.');
    }
  }

  static Map<String, dynamic> _object(Object? value) {
    if (value is! Map) throw const SignApiException('Invalid report record.');
    return Map<String, dynamic>.from(value);
  }

  static Map<String, dynamic> _data(Map<String, dynamic> value) =>
      _object(value['data']);

  static int _id(Object? value) =>
      value is int ? value : int.tryParse(value?.toString() ?? '') ?? 0;

  static DateTime _date(Object? value) {
    final result = DateTime.tryParse((value ?? '').toString());
    if (result == null) throw const SignApiException('Invalid report date.');
    return result;
  }

  static String dateValue(DateTime date) => [
    date.year.toString().padLeft(4, '0'),
    date.month.toString().padLeft(2, '0'),
    date.day.toString().padLeft(2, '0'),
  ].join('-');

  static List<String> _strings(Object? value) {
    if (value == null) return const [];
    if (value is! List || value.any((entry) => entry is! String)) {
      throw const SignApiException('Invalid report list values.');
    }
    return List.unmodifiable(value.cast<String>());
  }

  DocumentRecord _parse(Object? value, int company) {
    final raw = _object(value);
    final id = _id(raw['id']), job = _id(raw['job_id']);
    final kind = switch (raw['kind']) {
      'site_report' => ReportKind.siteReport,
      'meeting_minutes' => ReportKind.meetingMinutes,
      _ => throw const SignApiException('Invalid report kind.'),
    };
    final status = (raw['status'] ?? '').toString();
    if (id < 1 || job < 1 || _id(raw['company_id']) != company ||
        _id(raw['client_id']) < 1 || _id(raw['revision']) < 1 ||
        !['draft', 'approved', 'sent', 'archived'].contains(status)) {
      throw const SignApiException('Invalid or cross-company report.');
    }
    final content = _object(raw['content']);
    final sections = _object(content['sections'] ?? <String, dynamic>{});
    final reportDate = _date(raw['report_date']);
    final documentId = raw['managed_document_id'] == null
        ? null : _id(raw['managed_document_id']);
    if (['approved', 'sent'].contains(status) &&
        (documentId == null || documentId <= 0)) {
      throw const SignApiException('Approved report has no verified PDF.');
    }
    final actions = content['action_items'] is List
        ? (content['action_items'] as List).map((value) {
            final item = _object(value);
            return MeetingActionItem(
              description: (item['description'] ?? '').toString(),
              assignee: (item['assignee'] ?? '').toString(),
              dueDate: item['due_date'] == null
                  ? null : _date(item['due_date']),
            );
          }).toList()
        : <MeetingActionItem>[];
    return DocumentRecord(
      id: 'report-$id',
      category: DocumentCategory.reports,
      number: (raw['number'] ?? '').toString(),
      title: (raw['title'] ?? '').toString(),
      project: (raw['project'] ?? '').toString(),
      customer: (raw['customer'] ?? '').toString(),
      timestamp: reportDate,
      status: status,
      jobId: job.toString(),
      createdBy: (raw['prepared_by'] ?? '').toString(),
      createdAt: _date(raw['created_at']),
      updatedAt: DateTime.tryParse((raw['updated_at'] ?? '').toString()),
      version: _id(raw['revision']),
      demoOnly: false,
      reportKind: kind,
      reportManagedDocumentId: documentId,
      siteReportDetails: kind == ReportKind.siteReport ? SiteReportDetails(
        reportDate: reportDate,
        preparedBy: (raw['prepared_by'] ?? '').toString(),
        weatherCondition: (raw['weather'] ?? '').toString(),
        location: (raw['location'] ?? '').toString(),
        attendees: _strings(content['attendees']),
        absentees: _strings(content['absentees']),
        decisions: _strings(content['decisions']),
        outstandingPoints: _strings(content['outstanding_points']),
        nextSteps: _strings(content['next_steps']),
        actionItems: actions,
        selectedSections: SiteReportSection.values.where(
            (section) => sections.containsKey(section.name)).toList(),
        sectionContent: {
          for (final section in SiteReportSection.values)
            if (sections[section.name] is String)
              section: sections[section.name].toString(),
        },
      ) : null,
      meetingMinutesDetails: kind == ReportKind.meetingMinutes
          ? MeetingMinutesDetails(
              location: (raw['location'] ?? '').toString(),
              preparedBy: (raw['prepared_by'] ?? '').toString(),
              summary: (sections['summary'] ?? '').toString(),
              attendees: _strings(content['attendees']),
              absentees: _strings(content['absentees']),
              decisions: _strings(content['decisions']),
              nextSteps: _strings(content['next_steps']),
              outstandingPoints: _strings(content['outstanding_points']),
              actionItems: actions.map((item) => item.description).toList(),
              actionDetails: actions,
            )
          : null,
    );
  }

  @override
  Future<List<DocumentRecord>> listDocuments() => listForJob(null);

  Future<List<DocumentRecord>> listForJob(String? jobId) async {
    final company = _company();
    final documents = <DocumentRecord>[];
    for (var page = 1; page <= 100; page++) {
      final data = _data(await _api.get('/api/v1/reports',
        companyScoped: true,
        queryParameters: {'page': page.toString(), 'per_page': '100',
          'job_id': ?jobId}));
      _check(company);
      final rows = data['reports'];
      final lastPage = _id(data['last_page']);
      if (rows is! List || lastPage < page || lastPage > 100) {
        throw const SignApiException('Invalid report pagination.');
      }
      documents.addAll(rows.map((row) => _parse(row, company)));
      if (jobId != null && documents.any((r) => r.jobId != jobId)) {
        throw const SignApiException('Received a report from another job.');
      }
      if (page == lastPage) return List.unmodifiable(documents);
    }
    throw const SignApiException('Report list exceeded safety limit.');
  }

  static int reportId(String id) {
    final match = RegExp(r'^report-([1-9][0-9]*)$').firstMatch(id);
    if (match == null) {
      throw const SignApiException('Invalid report ID.');
    }
    return int.parse(match.group(1)!);
  }

  Future<DocumentRecord> details(String reportIdValue) async {
    final company = _company();
    final id = reportId(reportIdValue);
    final data = _data(await _api.get('/api/v1/reports/$id',
      companyScoped: true));
    _check(company);
    final raw = _object(data['report']);
    final result = _parse(raw, company);
    if (result.id != reportIdValue) {
      throw const SignApiException('Report ID changed.');
    }
    if (result.reportKind != ReportKind.siteReport ||
        result.siteReportDetails == null) {
      return result;
    }
    final ids = raw['photo_ids'];
    if (ids is! List || ids.isEmpty) {
      return result;
    }
    final expected = ids.map(_id).toSet();
    final available = await RemoteJobMediaRepository.shared.listPhotos(
        result.jobId!);
    _check(company);
    if (!expected.every((id) => available.any((p) => p.id == id.toString()))) {
      throw const SignApiException('A referenced job photo is unavailable.');
    }
    final photos = available.where((p) => expected.contains(int.tryParse(p.id)))
        .map((p) => LocalJobPhotoSelection(
          name: 'job-photo-${p.id}${p.bytes![0] == 137 ? '.png' : '.jpg'}',
          bytes: p.bytes!,
          sourceKey: 'remote:${p.id}',
        )).toList();
    final site = result.siteReportDetails!;
    return DocumentRecord(
      id: result.id, category: result.category, number: result.number,
      title: result.title, project: result.project,
      customer: result.customer, timestamp: result.timestamp,
      status: result.status, demoOnly: false, jobId: result.jobId,
      version: result.version, createdBy: result.createdBy,
      createdAt: result.createdAt, updatedAt: result.updatedAt,
      reportKind: result.reportKind,
      reportManagedDocumentId: result.reportManagedDocumentId,
      siteReportDetails: SiteReportDetails(
        reportDate: site.reportDate, preparedBy: site.preparedBy,
        weatherCondition: site.weatherCondition,
        selectedSections: site.selectedSections,
        sectionContent: site.sectionContent, photos: photos,
        location: site.location, attendees: site.attendees,
        absentees: site.absentees, decisions: site.decisions,
        outstandingPoints: site.outstandingPoints, nextSteps: site.nextSteps,
        actionItems: site.actionItems,
      ),
    );
  }

  /// Optional M12 dictation: text is never inserted or saved without user review.
  Future<String> transcribeAudio(String jobId, String path) async {
    final company = _company();
    if (int.tryParse(jobId) == null) {
      throw const SignApiException('Select a real company job before dictating.');
    }
    final file = File(path);
    if (!await file.exists() || await file.length() == 0 ||
        await file.length() > 25 * 1024 * 1024) {
      throw const SignApiException('Recording is missing or exceeds 25 MB.');
    }
    final response = _data(await _api.postMultipart(
      '/api/v1/reports/voice/transcribe',
      filename: file.uri.pathSegments.last, bytes: await file.readAsBytes(),
      companyScoped: true, maxBytes: 25 * 1024 * 1024,
      fields: {'job_id': jobId},
    ));
    _check(company);
    if (response['job_id'].toString() != jobId ||
        response['applied'] != false || response['approved'] != false) {
      throw const SignApiException('Invalid dictation response.');
    }
    final transcript = response['transcript'];
    if (transcript is! String || transcript.trim().isEmpty ||
        transcript.length > 20000) {
      throw const SignApiException('Voice transcription was empty.');
    }
    return transcript.trim();
  }

  Future<DocumentRecord> saveDraft(DocumentRecord draft) async {
    final company = _company();
    final job = int.tryParse(draft.jobId ?? '');
    final kind = draft.reportKind == ReportKind.siteReport
        ? 'site_report' : 'meeting_minutes';
    final site = draft.siteReportDetails, minutes = draft.meetingMinutesDetails;
    if (job == null || job <= 0 || draft.title.trim().isEmpty ||
        draft.category != DocumentCategory.reports ||
        (site == null && minutes == null) ||
        draft.reportKind == ReportKind.workAcceptance) {
      throw const SignApiException('Choose a real job and complete the report.');
    }
    if ((site?.photos.length ?? 0) > 8) {
      throw const SignApiException('Choose up to eight photos per report.');
    }
    final photoIds = <int>[];
    if (site != null) {
      for (final photo in site.photos) {
        final int id;
        if (photo.sourceKey.startsWith('remote:')) {
          id = int.tryParse(photo.sourceKey.substring(7)) ?? 0;
        } else {
          final uploaded = await RemoteJobMediaRepository.shared.uploadPhoto(
            job.toString(), photo, JobPhotoCategory.during, '');
          id = int.tryParse(uploaded.id) ?? 0;
          _check(company);
        }
        if (id < 1) throw const SignApiException('Invalid attached job photo.');
        photoIds.add(id);
      }
    }
    final sections = <String, dynamic>{
      if (site != null)
        for (final entry in site.sectionContent.entries)
          if (entry.value.trim().isNotEmpty)
            entry.key.name: entry.value.trim(),
      if (minutes != null && minutes.summary.trim().isNotEmpty)
        'summary': minutes.summary.trim(),
    };
    final body = <String, dynamic>{
      'job_id': job, 'kind': kind, 'title': draft.title.trim(),
      if (draft.id.startsWith('report-')) 'revision': draft.version,
      'report_date': dateValue(site?.reportDate ?? draft.timestamp),
      'prepared_by': site?.preparedBy ?? minutes?.preparedBy ?? '',
      'weather': site?.weatherCondition,
      'location': site?.location ?? minutes?.location ?? '',
      'photo_ids': photoIds,
      'content': <String, dynamic>{
        'sections': sections,
        if (site != null) 'attendees': site.attendees,
        if (site != null) 'absentees': site.absentees,
        if (site != null) 'decisions': site.decisions,
        if (site != null) 'outstanding_points': site.outstandingPoints,
        if (site != null) 'next_steps': site.nextSteps,
        if (site != null) 'action_items': site.actionItems.map((item) => {
          'description': item.description,
          if (item.assignee.trim().isNotEmpty) 'assignee': item.assignee,
          if (item.dueDate != null) 'due_date': dateValue(item.dueDate!),
        }).toList(),
        if (minutes != null) 'attendees': minutes.attendees,
        if (minutes != null) 'absentees': minutes.absentees,
        if (minutes != null) 'decisions': minutes.decisions,
        if (minutes != null) 'next_steps': minutes.nextSteps,
        if (minutes != null) 'outstanding_points': minutes.outstandingPoints,
        if (minutes != null) 'action_items': minutes.actionDetails.isNotEmpty
          ? minutes.actionDetails.map((item) => {
              'description': item.description,
              if (item.assignee.trim().isNotEmpty) 'assignee': item.assignee.trim(),
              if (item.dueDate != null) 'due_date': dateValue(item.dueDate!),
            }).toList()
          : minutes.actionItems.map((line) => {'description': line}).toList(),
      },
    };
    final existing = draft.id.startsWith('report-') ? reportId(draft.id) : null;
    final response = _data(existing == null
        ? await _api.post('/api/v1/reports', companyScoped: true, data: body)
        : await _api.request('PATCH',
            '/api/v1/reports/$existing',
            companyScoped: true, data: body));
    _check(company);
    return _parse(response['report'], company);
  }

  Future<Map<String, dynamic>> suggestAi(DocumentRecord report) async {
    final company = _company();
    final data = _data(await _api.post(
      '/api/v1/reports/${reportId(report.id)}/prepare-ai',
      companyScoped: true, data: {'confirm': true, 'revision': report.version}));
    _check(company);
    final raw = _object(data['suggestion']);
    if (raw['applied'] != false || raw['approved'] != false ||
        _id(raw['revision']) != report.version ||
        raw['title'] is! String || raw['sections'] is! Map) {
      throw const SignApiException('Invalid AI suggestion.');
    }
    return raw;
  }

  Future<DocumentRecord> applyAi(DocumentRecord report,
      Map<String, dynamic> suggestion) async {
    final company = _company();
    final sections = _object(suggestion['sections']);
    final reportSections = <String, String>{};
    for (final entry in sections.entries) {
      if (entry.value is! String) {
        throw const SignApiException('Invalid AI section content.');
      }
      reportSections[entry.key] = entry.value.toString();
    }
    // Keep attendance, action owners and deadlines from verified source.
    final raw = _data(await _api.get(
      '/api/v1/reports/${reportId(report.id)}',
      companyScoped: true));
    _check(company);
    final fetchedReport = _object(raw['report']);
    if (_id(fetchedReport['revision']) != report.version) {
      throw const SignApiException('Draft changed. Reload before applying AI.');
    }
    if (_id(suggestion['revision']) != report.version) {
      throw const SignApiException('AI suggestion is stale. Prepare it again.');
    }
    final existing = _object(fetchedReport['content']);
    final updated = <String, dynamic>{...existing, 'sections': reportSections};
    final data = _data(await _api.request('PATCH',
      '/api/v1/reports/${reportId(report.id)}',
      companyScoped: true,
      data: {'title': suggestion['title'], 'content': updated,
        'revision': report.version}));
    _check(company);
    return _parse(data['report'], company);
  }

  Future<DocumentRecord> approve(DocumentRecord report) async {
    final company = _company();
    final response = _data(await _api.post(
      '/api/v1/reports/${reportId(report.id)}/approve',
      data: {'confirm': true, 'revision': report.version},
      companyScoped: true));
    _check(company);
    return _parse(response['report'], company);
  }

  Future<DocumentRecord> send(DocumentRecord report) async {
    final company = _company();
    final response = _data(await _api.post(
      '/api/v1/reports/${reportId(report.id)}/send',
      data: {'confirm': true}, companyScoped: true));
    _check(company);
    return _parse(response['report'], company);
  }

  Future<void> archive(DocumentRecord report) async {
    final company = _company();
    final data = _data(await _api.request(
      'DELETE', '/api/v1/reports/${reportId(report.id)}',
      companyScoped: true,
    ));
    _check(company);
    final response = _object(data['report']);
    if ((response['status'] ?? '').toString() != 'archived' ||
        _id(response['id']) != reportId(report.id)) {
      throw const SignApiException('Report archive could not be verified.');
    }
  }

  Future<Uint8List> verifiedPdf(DocumentRecord report) async {
    final company = _company();
    final documentId = report.reportManagedDocumentId;
    if (documentId == null || documentId <= 0) {
      throw const SignApiException('Approve report before downloading a PDF.');
    }
    final doc = _data(await _api.get(
      '/api/v1/documents/managed-$documentId',
      companyScoped: true));
    _check(company);
    final metadata = _object(doc['document']);
    final digest = (metadata['sha256'] ?? '').toString().toLowerCase();
    if (metadata['has_pdf'] != true ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(digest)) {
      throw const SignApiException('Verified PDF metadata is missing.');
    }
    final bytes = await _api.getPdf(
      '/api/v1/reports/${reportId(report.id)}/pdf',
      companyScoped: true, maxBytes: 12 * 1024 * 1024);
    _check(company);
    if (sha256.convert(bytes).toString() != digest) {
      throw const SignApiException('Report PDF integrity check failed.');
    }
    return bytes;
  }
}
