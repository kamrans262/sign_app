import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../../../core/services/active_company_session.dart';
import '../../../core/services/sign_api_client.dart';
import '../../auth/data/mobile_auth_repository.dart';
import '../domain/document_record.dart';
import '../domain/work_acceptance_data.dart';

/// M13 acceptance drafts are not M12 site reports or local demo documents.
class WorkAcceptanceDraft {
  const WorkAcceptanceDraft({
    required this.jobId,
    required this.completedWork,
    required this.completionDate,
    required this.cleaningStatus,
    this.id, this.revision = 1, this.outstandingIssues = '',
    this.remedialWork = '', this.photoIds = const [],
  });

  final int? id;
  final int revision;
  final String jobId;
  final String completedWork;
  final DateTime completionDate;
  final String cleaningStatus;
  final String outstandingIssues;
  final String remedialWork;
  final List<int> photoIds;

  static WorkAcceptanceDraft fromJson(Map<String, dynamic> raw) =>
      WorkAcceptanceDraft(
        id: raw['id'] as int,
        revision: raw['revision'] as int,
        jobId: raw['job_id'].toString(),
        completedWork: (raw['completed_work'] ?? '').toString(),
        completionDate: DateTime.parse(raw['completion_date'].toString()),
        cleaningStatus: raw['cleaning_status'].toString(),
        outstandingIssues: (raw['outstanding_issues'] ?? '').toString(),
        remedialWork: (raw['remedial_work'] ?? '').toString(),
        photoIds: (raw['photo_ids'] as List<dynamic>? ?? const [])
            .map((value) => int.parse(value.toString())).toList(),
      );

  Map<String, dynamic> toJson() => {
    'job_id': int.parse(jobId),
    if (id != null) 'revision': revision,
    'completed_work': completedWork.trim(),
    'completion_date': [
      completionDate.year.toString().padLeft(4,'0'),
      completionDate.month.toString().padLeft(2,'0'),
      completionDate.day.toString().padLeft(2,'0'),
    ].join('-'),
    'cleaning_status': cleaningStatus,
    'outstanding_issues': outstandingIssues.trim(),
    'remedial_work': remedialWork.trim(),
    'photo_ids': photoIds,
  };
}

/// Company-scoped repository. Signed bytes always undergo SHA256 readback.
class RemoteWorkAcceptanceRepository implements DocumentRepository {
  RemoteWorkAcceptanceRepository({SignApiClient? api})
      : _api = api ?? MobileAuthRepository.shared.api;

  static final shared = RemoteWorkAcceptanceRepository();
  final SignApiClient _api;

  int _company() {
    final id=ActiveCompanySession.companyId;
    if(id==null||id<=0) {
      throw const SignApiException('Select a company before managing work acceptance.');
    }
    return id;
  }

  void _check(int id) {
    if(ActiveCompanySession.companyId!=id) {
      throw const SignApiException('Company changed during acceptance request.');
    }
  }

  static Map<String,dynamic> _map(Object? data) {
    if(data is! Map)throw const SignApiException('Invalid acceptance response.');
    return Map<String,dynamic>.from(data);
  }
  static Map<String,dynamic> _data(Map<String,dynamic> response) =>
      _map(response['data']);
  static int _id(Object? data) =>
      data is int? data:int.tryParse('$data')??0;
  static DateTime _date(Object? data) {
    final d=DateTime.tryParse((data??'').toString());
    if(d==null)throw const SignApiException('Invalid acceptance timestamp.');
    return d;
  }
  static bool _signed(String s) =>
      ['accepted','accepted_with_reservations'].contains(s);
  static bool _approved(String s) =>
      ['approved','sent','viewed'].contains(s);
  static int idOf(String id) {
    final m=RegExp(r'^acceptance-([1-9]\d*)$').firstMatch(id);
    if(m==null)throw const SignApiException('Invalid acceptance ID.');
    return int.parse(m.group(1)!);
  }
  static String _path(String id)=>'/api/v1/work-acceptances/${idOf(id)}';

  DocumentRecord _record(Object? raw,int company,
      {WorkAcceptanceEvidence? evidence}) {
    final row=_map(raw),id=_id(row['id']),job=_id(row['job_id']);
    final status=(row['status']??'').toString();
    if(id<1||job<1||_id(row['company_id'])!=company||
       _id(row['client_id'])<1||_id(row['revision'])<1||
       !['draft','approved','sent','viewed','accepted',
          'accepted_with_reservations'].contains(status)) {
      throw const SignApiException('Invalid or cross-company acceptance record.');
    }
    if(_signed(status)&&(row['has_signed_pdf']!=true ||
        _id(row['managed_document_id'])<=0)) {
      throw const SignApiException('Signed acceptance PDF unavailable.');
    }
    final project=(row['project']??'').toString();
    return DocumentRecord(
      id:'acceptance-$id',
      category:DocumentCategory.reports,
      number:(row['number']??'').toString(),
      title:'Work Acceptance · $project',
      project:project,customer:(row['customer']??'').toString(),
      timestamp:_date(row['completion_date']),
      status:status,version:_id(row['revision']),demoOnly:false,
      verifiedSignedPdfAvailable:_signed(status),
      jobId:job.toString(),createdAt:_date(row['created_at']),
      updatedAt:DateTime.tryParse((row['updated_at']??'').toString()),
      reportKind:ReportKind.workAcceptance,
      reportManagedDocumentId:row['managed_document_id']==null
          ?null:_id(row['managed_document_id']),
      workAcceptance:evidence,
    );
  }

  @override
  Future<List<DocumentRecord>> listDocuments() => listForJob(null);

  Future<List<DocumentRecord>> listForJob(String? jobId) async {
    final company=_company();
    final records=<DocumentRecord>[];
    for(var page=1;page<=100;page++) {
      final data=_data(await _api.get('/api/v1/work-acceptances',
        companyScoped:true,queryParameters:{
          'page':'$page','per_page':'100',
          'job_id':?jobId,
        }));
      _check(company);
      final list=data['records'],last=_id(data['last_page']);
      if(list is! List || last<page || last>100) {
        throw const SignApiException('Invalid acceptance pagination.');
      }
      records.addAll(list.map((item)=>_record(item,company)));
      if(jobId!=null && records.any((item)=>item.jobId!=jobId)) {
        throw const SignApiException('Foreign job acceptance response.');
      }
      if(page==last)return List.unmodifiable(records);
    }
    throw const SignApiException('Acceptance list limit exceeded.');
  }

  Future<WorkAcceptanceDraft> loadDraft(String id) async {
    final company=_company();
    final data=_data(await _api.get(_path(id),companyScoped:true));
    _check(company);
    final row=_map(data['acceptance']);
    if(_id(row['company_id'])!=company||row['status']!='draft') {
      throw const SignApiException('Only live drafts can be edited.');
    }
    return WorkAcceptanceDraft.fromJson(row);
  }

  Future<DocumentRecord> saveDraft(WorkAcceptanceDraft draft) async {
    final company=_company();
    if(int.tryParse(draft.jobId)==null||draft.completedWork.trim().isEmpty||
       !['cleaned','pending','not_applicable'].contains(draft.cleaningStatus)||
       draft.photoIds.length>8) {
      throw const SignApiException('Complete the acceptance report first.');
    }
    final path=draft.id==null?'/api/v1/work-acceptances':
        '/api/v1/work-acceptances/${draft.id}';
    final data=_data(await _api.request(draft.id==null?'POST':'PATCH',
        path,companyScoped:true,data:draft.toJson()));
    _check(company);
    return _record(data['acceptance'],company);
  }

  Future<DocumentRecord> approve(DocumentRecord report) async {
    final company=_company();
    final data=_data(await _api.post('${_path(report.id)}/approve',
        companyScoped:true,data:{'revision':report.version,'confirm':true}));
    _check(company);
    return _record(data['acceptance'],company);
  }

  Future<DocumentRecord> send(DocumentRecord report) async {
    final company=_company();
    final data=_data(await _api.post('${_path(report.id)}/send',
        companyScoped:true,data:{'confirm':true}));
    _check(company);
    return _record(data['report'],company);
  }

  Future<DocumentRecord> revokeActive(DocumentRecord report) async {
    final company=_company();
    final data=_data(await _api.get('${_path(report.id)}/requests',
        companyScoped:true));
    _check(company);
    final entries=data['requests'];
    if(entries is! List)throw const SignApiException('Invalid signing requests.');
    final active=entries.map(_map).where((item)=>
        ['ready','sent','viewed'].contains(item['status'])).toList();
    if(active.length!=1) {
      throw const SignApiException('No unique active signing request to revoke.');
    }
    final id=_id(active.single['id']);
    if(id<1)throw const SignApiException('Invalid signing request.');
    final result=_data(await _api.post(
        '${_path(report.id)}/requests/$id/revoke',
        companyScoped:true));
    _check(company);
    return _record(result['acceptance'],company);
  }

  Future<Uint8List> _pdf(Map<String,dynamic> row,String kind,int company) async {
    final digest=(row[kind=='signed'?'signed_pdf_sha256':
        'approved_pdf_sha256']??'').toString().toLowerCase();
    if(!RegExp(r'^[a-f0-9]{64}$').hasMatch(digest)) {
      throw const SignApiException('Missing PDF integrity metadata.');
    }
    final bytes=await _api.getPdf(
      '/api/v1/work-acceptances/${row['id']}/pdf/$kind',
      companyScoped:true,maxBytes:12*1024*1024);
    _check(company);
    if(sha256.convert(bytes).toString()!=digest) {
      throw const SignApiException('Acceptance PDF integrity check failed.');
    }
    return bytes;
  }

  Future<DocumentRecord> details(String id) async {
    final company=_company();
    final data=_data(await _api.get(_path(id),companyScoped:true));
    _check(company);
    final row=_map(data['acceptance']);
    final history=data['events'];
    if(history is! List)throw const SignApiException('Missing acceptance history.');
    final events=<WorkAcceptanceEvent>[];
    for(final value in history) {
      final item=_map(value);
      final type=(item['type']??'').toString();
      final stages=switch(type) {
        'created'=>[WorkAcceptanceStage.workCompleted],
        'sent'=>[WorkAcceptanceStage.clientNotified],
        'client_viewed'=>[WorkAcceptanceStage.clientViewed],
        'customer_signed'=>[
          WorkAcceptanceStage.clientSigned,WorkAcceptanceStage.completed],
        _=><WorkAcceptanceStage>[],
      };
      for(final stage in stages) {
        events.add(WorkAcceptanceEvent(
          id:'${item['id']}-${stage.name}',
          documentId:id,stage:stage,
          occurredAt:_date(item['created_at']),
          actorName:item['actor_id']==null?'Customer':'Sign2Digital User',
        ));
      }
    }
    final status=(row['status']??'').toString();
    Uint8List? pdf,signature;
    if(_signed(status)) {
      pdf=await _pdf(row,'signed',company);
      signature=await _api.getPrivateMedia('${_path(id)}/signature',
          mimeType:'image/png',maxBytes:300*1024);
      _check(company);
    }else if(_approved(status)) {
      pdf=await _pdf(row,'approved',company);
    }
    final evidence=WorkAcceptanceEvidence(
      events:List.unmodifiable(events),
      verifiedSignaturePng:signature,
      verifiedReportPdf:pdf,
      acceptanceResult:row['acceptance_result']?.toString(),
      reservation:(row['customer_reservation']??'').toString(),
      outstandingIssues:(row['customer_outstanding_issues']??'').toString(),
      customerComment:(row['customer_comment']??'').toString(),
      customerRating:row['customer_rating']==null?null:_id(row['customer_rating']),
      signedAt:row['signed_at']==null?null:_date(row['signed_at']),
    );
    final result=_record(row,company,evidence:evidence);
    if(result.id!=id)throw const SignApiException('Acceptance ID changed.');
    return result;
  }
}
