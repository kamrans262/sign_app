import 'dart:math';

import 'package:crypto/crypto.dart';

import '../../../core/services/active_company_session.dart';
import '../../../core/services/sign_api_client.dart';
import '../../auth/data/mobile_auth_repository.dart';
import '../../jobs/data/local_job_photo_source.dart';
import '../../jobs/data/remote_job_repository.dart';
import '../../jobs/domain/job_model.dart';
import '../domain/labour_entry.dart';

class LabourWorker {
  const LabourWorker({required this.id,required this.name});
  final int id;
  final String name;
}

class LabourTimerSnapshot {
  const LabourTimerSnapshot({
    required this.status,required this.elapsedSeconds,
    required this.version,required this.serverNow,
    this.jobId,this.workerId,this.task,this.hourlyRateMinor,
  });
  final String status;
  final int elapsedSeconds;
  final int version;
  final DateTime serverNow;
  final int? jobId;
  final int? workerId;
  final int? hourlyRateMinor;
  final String? task;
  bool get isActive => status == 'running' || status == 'paused';

  factory LabourTimerSnapshot.fromJson(Object? raw) {
    if (raw is! Map) {
      throw const SignApiException('Invalid server timer response.');
    }
    final data=Map<String,dynamic>.from(raw);
    final status=data['status'];
    if (!const ['running','paused','stopped'].contains(status)) {
      throw const SignApiException('Invalid timer status.');
    }
    final elapsed=int.tryParse('${data['elapsed_seconds']}');
    final version=int.tryParse('${data['lock_version']}');
    final server=DateTime.tryParse('${data['server_now'] ?? ''}');
    if(elapsed==null||elapsed<0||version==null||version<0||server==null) {
      throw const SignApiException('Invalid timer values.');
    }
    return LabourTimerSnapshot(
      status:status as String,elapsedSeconds:elapsed,
      version:version,serverNow:server,
      jobId:int.tryParse('${data['job_id']}'),
      workerId:int.tryParse('${data['worker_id']}'),
      task:data['task'] is String?data['task'] as String:null,
      hourlyRateMinor:data['hourly_rate_minor']==null?null:
          int.tryParse('${data['hourly_rate_minor']}'),
    );
  }
}

/// Real time entries belong only to the authenticated active company.
/// Never merge local UI demonstration data into server results.
class RemoteLabourRepository implements LabourRepository {
  RemoteLabourRepository({SignApiClient? api})
      : _api=api??MobileAuthRepository.shared.api;

  static final shared=RemoteLabourRepository();
  final SignApiClient _api;
  static final Random _secure=Random.secure();

  static String newRequestKey() {
    const alphabet='abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(32,(_)=>alphabet[_secure.nextInt(alphabet.length)]).join();
  }

  int _company() {
    final id=ActiveCompanySession.companyId;
    if(id==null||id<1) {
      throw const SignApiException('Select a company before tracking work.');
    }
    return id;
  }

  void _ensureCompany(int id) {
    if(ActiveCompanySession.companyId!=id) {
      throw const SignApiException('Company changed while tracking labour.');
    }
  }

  static Map<String,dynamic> _map(Object? data) {
    if(data is! Map)throw const SignApiException('Invalid labour API response.');
    return Map<String,dynamic>.from(data);
  }
  static Map<String,dynamic> _data(Map<String,dynamic> response) =>
      _map(response['data']);
  static int _int(Object? raw) => raw is int?raw:int.tryParse('$raw')??0;
  static DateTime _date(Object? raw) {
    final date=DateTime.tryParse('${raw ?? ''}');
    if(date==null)throw const SignApiException('Invalid labour date.');
    return date;
  }
  static int _id(String raw) {
    final m=RegExp(r'^labour-([1-9]\d*)$').firstMatch(raw);
    if(m==null)throw const SignApiException('Invalid labour entry ID.');
    return int.parse(m.group(1)!);
  }
  static int? _receiptId(String key) {
    final m=RegExp(r'^labour-evidence-([1-9]\d*)$').firstMatch(key);
    return m==null?null:int.parse(m.group(1)!);
  }

  LabourEntry _entry(Object? data,int company,{
    List<LocalJobPhotoSelection> photos=const [],
    List<LabourHistoryEvent> events=const [],
    bool canApprove=false,
  }) {
    final row=_map(data);
    final id=_int(row['id']);
    final job=_int(row['job_id']);
    final worker=_int(row['worker_id']);
    final mins=_int(row['duration_minutes']);
    final ver=_int(row['lock_version']);
    final rate=row['hourly_rate_minor']==null
        ?null:_int(row['hourly_rate_minor']);
    final cost=row['cost_minor']==null?null:_int(row['cost_minor']);
    final kind=switch(row['kind']){
      'labour'=>LabourEntryKind.labour,
      'time_sheet'=>LabourEntryKind.timeSheet,
      _=>throw const SignApiException('Invalid time entry type.'),
    };
    final status=switch(row['status']){
      'pending'=>LabourEntryStatus.pending,
      'approved'=>LabourEntryStatus.approved,
      'void'=>LabourEntryStatus.voided,
      _=>throw const SignApiException('Invalid time approval status.'),
    };
    if(id<1||job<1||worker<1||mins<1||mins>1440||ver<1||
        company!=_int(row['company_id'])||row['currency']!='CHF'||
        (rate!=null&&rate<0)||(cost!=null&&cost<0)) {
      throw const SignApiException('Invalid or cross-company labour record.');
    }
    return LabourEntry(
      id:'labour-$id',kind:kind,
      workerName:'${row['worker_name'] ?? ''}',
      workerId:worker,role:'${row['role'] ?? ''}',
      jobId:'$job',jobName:'${row['job'] ?? ''}',
      date:_date(row['work_date']),
      hours:mins/60.0,
      startMinutes:_int(row['start_minutes']),
      endMinutes:_int(row['end_minutes']),
      hourlyRate:rate==null?null:rate/100.0,
      task:'${row['task'] ?? ''}',
      photos:photos,history:events,canApprove:canApprove,
      status:status,source:'${row['source']}',
      lockVersion:ver,isDemo:false,
      approvedAt:row['approved_at']==null?null:_date(row['approved_at']),
      approvedBy:row['approved_by']==null?null:'User #${row['approved_by']}',
    );
  }

  @override
  Future<List<LabourEntry>> list() async {
    final company=_company();
    final result=<LabourEntry>[];
    var page=1;
    do {
      final response=_data(await _api.get('/api/v1/labour/entries',
        companyScoped:true,queryParameters:{
          'page':'$page','per_page':'100',
        }));
      _ensureCompany(company);
      final raw=response['records'];
      if(raw is! List||raw.any((e)=>e is! Map)) {
        throw const SignApiException('Invalid labour list.');
      }
      result.addAll(raw.map((e)=>_entry(e,company)));
      final last=_int(response['last_page']);
      if(last<1||last>100||page>last) {
        throw const SignApiException('Invalid labour pagination.');
      }
      if(page==last)break;
      page++;
    } while(page<=100);
    return result;
  }

  @override
  Future<List<JobModel>> jobs() async {
    final company=_company();
    final records=await RemoteJobRepository.shared.listJobs();
    _ensureCompany(company);
    return records.where((job)=>job.category!=JobCategory.archived).toList();
  }

  Future<List<LabourWorker>> workers(String jobId) async {
    final id=int.tryParse(jobId);
    if(id==null||id<1)throw const SignApiException('Select a saved job.');
    final company=_company();
    final data=_data(await _api.get('/api/v1/jobs/$id/labour-workers',
      companyScoped:true));
    _ensureCompany(company);
    final list=data['workers'];
    if(list is! List)throw const SignApiException('Invalid assigned workers.');
    return [
      for(final item in list)
        if(_int(_map(item)['id'])>0)
          LabourWorker(id:_int(_map(item)['id']),
              name:'${_map(item)['name']}'),
    ];
  }

  Future<int> currentWorkerId() async {
    final data=_map((await _api.currentAccount())['data']);
    final user=_map(data['user']);
    final id=_int(user['id']);
    if(id<1)throw const SignApiException('Unable to resolve signed-in worker.');
    return id;
  }

  Future<LabourEntry> detail(String entryId) async {
    final company=_company();
    final id=_id(entryId);
    final res=_data(await _api.get('/api/v1/labour/entries/$id',
      companyScoped:true));
    _ensureCompany(company);
    final proofs=res['evidence'];
    if(proofs is! List)throw const SignApiException('Missing labour evidence.');
    final files=<LocalJobPhotoSelection>[];
    for(final obj in proofs) {
      final proof=_map(obj);
      final proofId=_int(proof['id']);
      final mime='${proof['mime_type']}';
      if(proofId<1||!const ['image/png','image/jpeg','application/pdf']
          .contains(mime)) {
        throw const SignApiException('Invalid labour evidence type.');
      }
      final bytes=await _api.getPrivateAttachment(
        '/api/v1/labour/entries/$id/evidence/$proofId',
        mimeType:mime,maxBytes:10*1024*1024,
      );
      _ensureCompany(company);
      if(sha256.convert(bytes).toString()!='${proof['sha256']}'||
          bytes.length!=_int(proof['byte_size'])) {
        throw const SignApiException('Labour evidence failed integrity check.');
      }
      files.add(LocalJobPhotoSelection(
        name:'${proof['name']}',bytes:bytes,
        sourceKey:'labour-evidence-$proofId',
      ));
    }
    final history=res['history'];
    if(history is! List)throw const SignApiException('Missing labour audit.');
    return _entry(res['entry'],company,photos:files,
      canApprove:res['can_approve']==true,events:[
      for(final obj in history)
        LabourHistoryEvent(
          id:'${_map(obj)['id']}',
          title:'${_map(obj)['title']}',
          actorName:_map(obj)['actor_user_id']==null?null:
              'User #${_map(obj)['actor_user_id']}',
          occurredAt:_date(_map(obj)['occurred_at']),
        ),
    ]);
  }

  static Map<String,dynamic> _fields(LabourEntry entry) {
    final job=int.tryParse(entry.jobId);
    final worker=entry.workerId;
    if(job==null||job<1||worker==null||worker<1||
        entry.startMinutes==null||entry.endMinutes==null) {
      throw const SignApiException('Select a saved job and assigned worker.');
    }
    final rate=entry.hourlyRate;
    if(rate!=null&&(!rate.isFinite||rate<0||
        (rate*100-(rate*100).round()).abs()>0.001)) {
      throw const SignApiException('Hourly rate must have two CHF decimals.');
    }
    return {
      'job_id':job,'worker_id':worker,
      'kind':entry.kind==LabourEntryKind.labour?'labour':'time_sheet',
      'worker_role':entry.role,'task':entry.task,
      'work_date':[
        entry.date.year.toString().padLeft(4,'0'),
        entry.date.month.toString().padLeft(2,'0'),
        entry.date.day.toString().padLeft(2,'0'),
      ].join('-'),
      'start_minutes':entry.startMinutes,
      'end_minutes':entry.endMinutes,
      'hourly_rate':rate?.toStringAsFixed(2),
      if(entry.id.startsWith('labour-'))
        'lock_version':entry.lockVersion,
    };
  }

  static void _checkProof(LocalJobPhotoSelection item) {
    if(item.bytes.isEmpty||item.bytes.length>10*1024*1024) {
      throw const SignApiException('Evidence cannot exceed 10 MB.');
    }
  }

  Future<void> _upload(int id,LocalJobPhotoSelection item) async {
    _checkProof(item);
    await _api.postMultipart('/api/v1/labour/entries/$id/evidence',
      filename:item.name,bytes:item.bytes,
      companyScoped:true,maxBytes:10*1024*1024);
  }

  @override
  Future<void> save(LabourEntry entry) async {
    final company=_company();
    if(entry.photos.length>10)throw const SignApiException('Maximum 10 files.');
    for(final proof in entry.photos) {
      _checkProof(proof);
    }
    final res=_data(await _api.post('/api/v1/labour/entries',
      companyScoped:true,data:_fields(entry)));
    _ensureCompany(company);
    final id=_id(_entry(res['entry'],company).id);
    try {
      for(final file in entry.photos) {
        await _upload(id,file);
        _ensureCompany(company);
      }
    } catch (_) {
      throw SignApiException('Time entry #$id was saved, but evidence upload '
        'failed. Reopen it instead of creating a duplicate.');
    }
  }

  @override
  Future<void> update(LabourEntry entry) async {
    final company=_company();
    final id=_id(entry.id);
    final previous=await detail(entry.id);
    _ensureCompany(company);
    if(previous.lockVersion!=entry.lockVersion||
        previous.status!=LabourEntryStatus.pending||
        previous.source!='manual') {
      throw const SignApiException('Time record is locked or changed.');
    }
    final retained=<int>{};
    for(final file in entry.photos) {
      final remoteId=_receiptId(file.sourceKey);
      if(remoteId!=null)retained.add(remoteId);
    }
    final previousIds=previous.photos.map((f)=>_receiptId(f.sourceKey))
        .whereType<int>().toSet();
    if(!previousIds.containsAll(retained)) {
      throw const SignApiException('Evidence belongs to another entry.');
    }
    await _api.request('PATCH','/api/v1/labour/entries/$id',
      companyScoped:true,data:_fields(entry));
    _ensureCompany(company);
    for(final file in entry.photos) {
      if(_receiptId(file.sourceKey)==null)await _upload(id,file);
      _ensureCompany(company);
    }
    for(final remote in previousIds.difference(retained)) {
      await _api.delete('/api/v1/labour/entries/$id/evidence/$remote',
        companyScoped:true);
      _ensureCompany(company);
    }
  }

  Future<LabourEntry> approveEntry(LabourEntry entry) async {
    if (entry.status != LabourEntryStatus.pending || !entry.canApprove) {
      throw const SignApiException('Only a company reviewer may approve pending time.');
    }
    final company=_company();
    final id=_id(entry.id);
    final result=_data(await _api.post('/api/v1/labour/entries/$id/approve',
      companyScoped:true,data:{'confirm':true}));
    _ensureCompany(company);
    final approved=_entry(result['entry'],company);
    if(approved.id!=entry.id || approved.status!=LabourEntryStatus.approved) {
      throw const SignApiException('Labour approval response identity mismatch.');
    }
    return detail(entry.id);
  }

  @override
  Future<void> delete(String id) async {
    final company=_company();
    await _api.post('/api/v1/labour/entries/${_id(id)}/void',
      companyScoped:true,data:{
        'reason':'Voided by the worker in the Sign2Digital mobile app.',
      });
    _ensureCompany(company);
  }

  Future<LabourTimerSnapshot> timerCurrent() async {
    final company=_company();
    final data=_data(await _api.get('/api/v1/labour/timer/current',
      companyScoped:true));
    _ensureCompany(company);
    return LabourTimerSnapshot.fromJson(data['timer']);
  }

  Future<LabourTimerSnapshot> timerAction(String action,{
    String? jobId,String? rate,String? task,String? role,
    String? requestKey,
  }) async {
    if(!const ['start','pause','resume','stop'].contains(action)) {
      throw const SignApiException('Invalid timer action.');
    }
    final company=_company();
    final data=_data(await _api.post('/api/v1/labour/timer/$action',
      companyScoped:true,data:{
        'request_key':requestKey??newRequestKey(),
        if(action=='start')'job_id':int.tryParse(jobId??''),
        if(action=='start')'hourly_rate':rate,
        if(action=='start')'task':task,
        if(action=='start')'worker_role':role,
      }));
    _ensureCompany(company);
    return LabourTimerSnapshot.fromJson(data['timer']);
  }

  Future<Map<String,dynamic>> summary(String jobId) async {
    final id=int.tryParse(jobId);
    if(id==null||id<1)throw const SignApiException('Invalid job.');
    final company=_company();
    final data=_data(await _api.get('/api/v1/jobs/$id/cost-summary',
      companyScoped:true));
    _ensureCompany(company);
    if(_int(data['job_id'])!=id||data['currency']!='CHF') {
      throw const SignApiException('Invalid job labour summary.');
    }
    return data;
  }
}
