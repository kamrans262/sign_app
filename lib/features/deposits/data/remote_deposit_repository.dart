import 'package:crypto/crypto.dart';

import '../../../core/services/active_company_session.dart';
import '../../../core/services/sign_api_client.dart';
import '../../auth/data/mobile_auth_repository.dart';
import '../../jobs/data/local_job_photo_source.dart';
import '../../jobs/data/remote_job_repository.dart';
import '../../jobs/domain/job_model.dart';
import '../domain/deposit_record.dart';

/// Tenant-scoped M16 deposits, with server-authenticated private receipts.
class RemoteDepositRepository extends DepositRepository {
  RemoteDepositRepository({SignApiClient? api})
      : _api=api??MobileAuthRepository.shared.api;
  static final shared=RemoteDepositRepository();
  final SignApiClient _api;

  int _company(){
    final c=ActiveCompanySession.companyId;
    if(c==null||c<=0)throw const SignApiException('Select a company first.');
    return c;
  }
  void _check(int c){
    if(ActiveCompanySession.companyId!=c){
      throw const SignApiException('Company changed during deposit request.');
    }
  }
  static Map<String,dynamic> _map(Object? raw){
    if(raw is! Map)throw const SignApiException('Invalid deposit server data.');
    return Map<String,dynamic>.from(raw);
  }
  static Map<String,dynamic> _data(Map<String,dynamic> raw)=>_map(raw['data']);
  static int _int(Object? raw)=>raw is int?raw:int.tryParse('$raw')??0;
  static DateTime _date(Object? raw){
    final d=DateTime.tryParse('$raw');
    if(d==null)throw const SignApiException('Invalid deposit date.');
    return d;
  }
  static int _id(String raw){
    final m=RegExp(r'^deposit-([1-9]\d*)$').firstMatch(raw);
    if(m==null)throw const SignApiException('Invalid deposit ID.');
    return int.parse(m.group(1)!);
  }
  static int? _receiptId(String raw){
    final m=RegExp(r'^deposit-receipt-([1-9]\d*)$').firstMatch(raw);
    return m==null?null:int.parse(m.group(1)!);
  }
  DepositRecord _record(Object? raw,int company,{
    List<LocalJobPhotoSelection> photos=const [],
    List<DepositHistoryEvent> history=const [],
  }){
    final r=_map(raw);
    final id=_int(r['id']),job=_int(r['job_id']);
    final minor=_int(r['amount_minor']),version=_int(r['lock_version']);
    final status=switch(r['status']){
      'pending'=>DepositStatus.pending,
      'received'=>DepositStatus.received,
      'refunded'=>DepositStatus.refunded,
      _=>throw const SignApiException('Invalid deposit status.'),
    };
    if(id<1||job<1||minor<1||version<1||
        _int(r['company_id'])!=company||r['currency']!='CHF'){
      throw const SignApiException('Invalid or cross-company deposit.');
    }
    return DepositRecord(
      id:'deposit-$id',title:(r['job']??'').toString(),
      clientName:(r['client_name']??'').toString(),
      amount:minor/100.0,date:_date(r['deposit_date']),
      status:status,jobId:'$job',
      jobReference:(r['job_reference']??'').toString(),
      quoteId:r['quote_id']==null?null:_int(r['quote_id']),
      lockVersion:version,
      paymentMethod:(r['payment_method']??'').toString(),
      referenceNumber:(r['reference_number']??'').toString(),
      notes:(r['notes']??'').toString(),photos:photos,history:history,
      receivedBy:r['received_by']==null?null:'User #${r['received_by']}',
      receivedAt:r['received_at']==null?null:_date(r['received_at']),
      refundedAt:r['refunded_at']==null?null:_date(r['refunded_at']),
      demoOnly:false,
    );
  }

  @override
  Future<List<DepositRecord>> listDeposits() async {
    final company=_company(),out=<DepositRecord>[];
    var page=1;
    while(true){
      final data=_data(await _api.get('/api/v1/deposits',
        companyScoped:true,
        queryParameters:{'page':'$page','per_page':'100'}));
      _check(company);
      final list=data['records'];
      if(list is! List)throw const SignApiException('Invalid deposit listing.');
      out.addAll(list.map((x)=>_record(x,company)));
      final last=_int(data['last_page']);
      if(last<1||last>100||page>last){
        throw const SignApiException('Invalid deposit pagination.');
      }
      if(page==last)break;
      page++;
    }
    return out;
  }

  Future<List<JobModel>> jobs() async {
    final company=_company();
    final result=await RemoteJobRepository.shared.listJobs();
    _check(company);
    return result.where((x)=>x.category!=JobCategory.archived).toList();
  }

  Future<DepositRecord> detail(String raw) async {
    final company=_company(),id=_id(raw);
    final data=_data(await _api.get('/api/v1/deposits/$id',companyScoped:true));
    _check(company);
    final receipts=data['receipts'],history=data['history'];
    if(receipts is! List||history is! List){
      throw const SignApiException('Missing deposit receipts or history.');
    }
    final photos=<LocalJobPhotoSelection>[];
    for(final item in receipts){
      final row=_map(item);
      final n=_int(row['id']),mime=(row['mime_type']??'').toString();
      if(n<1||!const ['image/png','image/jpeg','application/pdf'].contains(mime)){
        throw const SignApiException('Invalid deposit receipt type.');
      }
      final bytes=await _api.getPrivateAttachment(
        '/api/v1/deposits/$id/receipts/$n',
        mimeType:mime,maxBytes:10*1024*1024);
      _check(company);
      if(bytes.length!=_int(row['byte_size'])||
          sha256.convert(bytes).toString()!=row['sha256']){
        throw const SignApiException('Deposit receipt integrity mismatch.');
      }
      photos.add(LocalJobPhotoSelection(
        name:(row['name']??'receipt').toString(),bytes:bytes,
        sourceKey:'deposit-receipt-$n'));
    }
    return _record(data['deposit'],company,photos:photos,history:[
      for(final raw in history)
        DepositHistoryEvent(
          id:_map(raw)['id'].toString(),
          title:_map(raw)['type'].toString().replaceAll('_',' '),
          occurredAt:_date(_map(raw)['created_at']),
          description:_map(raw)['actor_user_id']==null?null:
              'User #${_map(raw)['actor_user_id']}',
        ),
    ]);
  }

  static Map<String,dynamic> _fields(DepositRecord r){
    final job=int.tryParse(r.jobId??'');
    if(job==null||job<1||!r.amount.isFinite||r.amount<=0||
        (r.amount*100-(r.amount*100).round()).abs()>0.001){
      throw const SignApiException('Select a valid job and CHF amount.');
    }
    final method=r.paymentMethod.toLowerCase().trim();
    final normalized=method=='cash'?'cash':
      const ['bank transfer','bank_transfer','bank'].contains(method)
          ?'bank_transfer':'other';
    return {
      'job_id':job,'quote_id':r.quoteId,
      'client_name':r.clientName.trim(),
      'amount':r.amount.toStringAsFixed(2),
      'deposit_date':[
        r.date.year.toString().padLeft(4,'0'),
        r.date.month.toString().padLeft(2,'0'),
        r.date.day.toString().padLeft(2,'0'),
      ].join('-'),
      'payment_method':normalized,
      'reference_number':r.referenceNumber.trim(),
      'notes':r.notes.trim(),
      if(r.id.startsWith('deposit-'))'lock_version':r.lockVersion,
    };
  }

  static void _validate(LocalJobPhotoSelection p){
    if(p.bytes.isEmpty||p.bytes.length>10*1024*1024){
      throw const SignApiException('Receipt must not exceed 10 MB.');
    }
  }
  Future<void> _upload(int id,LocalJobPhotoSelection p) async {
    _validate(p);
    await _api.postMultipart('/api/v1/deposits/$id/receipts',
      filename:p.name,bytes:p.bytes,companyScoped:true,
      maxBytes:10*1024*1024);
  }

  @override
  Future<void> saveDeposit(DepositRecord deposit) async {
    final company=_company();
    if(deposit.photos.length>10)throw const SignApiException('Maximum 10 receipts.');
    for(final p in deposit.photos){_validate(p);}
    final fields=_fields(deposit);
    // The form-generated draft ID stays stable for a retry after a lost reply.
    // Never use a server record ID as a create idempotency key.
    if(RegExp(r'^[A-Za-z0-9._-]{8,100}
    _check(company);
    final id=_id(_record(res['deposit'],company).id);
    try{
      for(final p in deposit.photos){
        await _upload(id,p);
        _check(company);
      }
    }catch(_){
      throw SignApiException('Deposit #$id was saved but receipt upload failed. '
        'Reopen the existing deposit rather than creating a duplicate.');
    }
  }

  @override
  Future<DepositRecord> updateDeposit(DepositRecord updated) async {
    final company=_company(),id=_id(updated.id);
    final before=await detail(updated.id);
    _check(company);
    if(before.status!=DepositStatus.pending||
       updated.status!=DepositStatus.pending||
       before.lockVersion!=updated.lockVersion||
       before.jobId!=updated.jobId||before.quoteId!=updated.quoteId){
      throw const SignApiException('Deposit changed or already received.');
    }
    final previous=before.photos.map((p)=>_receiptId(p.sourceKey))
        .whereType<int>().toSet();
    final kept=<int>{};
    for(final p in updated.photos){
      _validate(p);
      final proof=_receiptId(p.sourceKey);
      if(proof!=null){
        if(!previous.contains(proof)){
          throw const SignApiException('Receipt belongs to another deposit.');
        }
        kept.add(proof);
      }
    }
    await _api.request('PATCH','/api/v1/deposits/$id',
      companyScoped:true,data:_fields(updated));
    _check(company);
    for(final p in updated.photos){
      if(_receiptId(p.sourceKey)==null)await _upload(id,p);
      _check(company);
    }
    for(final proof in previous.difference(kept)){
      await _api.delete('/api/v1/deposits/$id/receipts/$proof',
        companyScoped:true);
      _check(company);
    }
    return detail(updated.id);
  }

  @override
  Future<DepositRecord> receiveDeposit(String id) async {
    final company=_company(),r=await detail(id);
    if(r.status!=DepositStatus.pending){
      throw const SignApiException('Only pending deposits may be received.');
    }
    final data=_data(await _api.post(
      '/api/v1/deposits/${_id(id)}/receive',
      companyScoped:true,data:{
        'confirm':true,'lock_version':r.lockVersion,
      }));
    _check(company);
    if(_record(data['deposit'],company).status!=DepositStatus.received){
      throw const SignApiException('Manual receipt not confirmed.');
    }
    return detail(id);
  }

  @override
  Future<DepositRecord> refundDeposit(String id) async {
    final company=_company(),r=await detail(id);
    if(r.status!=DepositStatus.received){
      throw const SignApiException('Only received deposits may be refunded.');
    }
    final data=_data(await _api.post(
      '/api/v1/deposits/${_id(id)}/refund',
      companyScoped:true,data:{
        'confirm':true,'lock_version':r.lockVersion,
        'reason':'Manual refund already completed outside Sign2Digital.',
      }));
    _check(company);
    if(_record(data['deposit'],company).status!=DepositStatus.refunded){
      throw const SignApiException('Manual refund not confirmed.');
    }
    return detail(id);
  }

  @override
  Future<void> deleteDeposit(String id) async {
    final company=_company();
    await _api.delete('/api/v1/deposits/${_id(id)}',
      companyScoped:true);
    _check(company);
  }

  Future<Map<String,dynamic>> jobSummary(int job) async {
    final company=_company();
    final data=_data(await _api.get('/api/v1/jobs/$job/deposit-summary',
      companyScoped:true));
    _check(company);
    if(_int(data['job_id'])!=job||data['currency']!='CHF'){
      throw const SignApiException('Invalid job deposit summary.');
    }
    return data;
  }
}
).hasMatch(deposit.id) &&
        !deposit.id.startsWith('deposit-')){
      fields['request_key']=deposit.id;
    }
    final res=_data(await _api.post('/api/v1/deposits',
      companyScoped:true,data:fields));
    _check(company);
    final id=_id(_record(res['deposit'],company).id);
    try{
      for(final p in deposit.photos){
        await _upload(id,p);
        _check(company);
      }
    }catch(_){
      throw SignApiException('Deposit #$id was saved but receipt upload failed. '
        'Reopen the existing deposit rather than creating a duplicate.');
    }
  }

  @override
  Future<DepositRecord> updateDeposit(DepositRecord updated) async {
    final company=_company(),id=_id(updated.id);
    final before=await detail(updated.id);
    _check(company);
    if(before.status!=DepositStatus.pending||
       updated.status!=DepositStatus.pending||
       before.lockVersion!=updated.lockVersion||
       before.jobId!=updated.jobId||before.quoteId!=updated.quoteId){
      throw const SignApiException('Deposit changed or already received.');
    }
    final previous=before.photos.map((p)=>_receiptId(p.sourceKey))
        .whereType<int>().toSet();
    final kept=<int>{};
    for(final p in updated.photos){
      _validate(p);
      final proof=_receiptId(p.sourceKey);
      if(proof!=null){
        if(!previous.contains(proof)){
          throw const SignApiException('Receipt belongs to another deposit.');
        }
        kept.add(proof);
      }
    }
    await _api.request('PATCH','/api/v1/deposits/$id',
      companyScoped:true,data:_fields(updated));
    _check(company);
    for(final p in updated.photos){
      if(_receiptId(p.sourceKey)==null)await _upload(id,p);
      _check(company);
    }
    for(final proof in previous.difference(kept)){
      await _api.delete('/api/v1/deposits/$id/receipts/$proof',
        companyScoped:true);
      _check(company);
    }
    return detail(updated.id);
  }

  @override
  Future<DepositRecord> receiveDeposit(String id) async {
    final company=_company(),r=await detail(id);
    if(r.status!=DepositStatus.pending){
      throw const SignApiException('Only pending deposits may be received.');
    }
    final data=_data(await _api.post(
      '/api/v1/deposits/${_id(id)}/receive',
      companyScoped:true,data:{
        'confirm':true,'lock_version':r.lockVersion,
      }));
    _check(company);
    if(_record(data['deposit'],company).status!=DepositStatus.received){
      throw const SignApiException('Manual receipt not confirmed.');
    }
    return detail(id);
  }

  @override
  Future<DepositRecord> refundDeposit(String id) async {
    final company=_company(),r=await detail(id);
    if(r.status!=DepositStatus.received){
      throw const SignApiException('Only received deposits may be refunded.');
    }
    final data=_data(await _api.post(
      '/api/v1/deposits/${_id(id)}/refund',
      companyScoped:true,data:{
        'confirm':true,'lock_version':r.lockVersion,
        'reason':'Manual refund already completed outside Sign2Digital.',
      }));
    _check(company);
    if(_record(data['deposit'],company).status!=DepositStatus.refunded){
      throw const SignApiException('Manual refund not confirmed.');
    }
    return detail(id);
  }

  @override
  Future<void> deleteDeposit(String id) async {
    final company=_company();
    await _api.delete('/api/v1/deposits/${_id(id)}',
      companyScoped:true);
    _check(company);
  }

  Future<Map<String,dynamic>> jobSummary(int job) async {
    final company=_company();
    final data=_data(await _api.get('/api/v1/jobs/$job/deposit-summary',
      companyScoped:true));
    _check(company);
    if(_int(data['job_id'])!=job||data['currency']!='CHF'){
      throw const SignApiException('Invalid job deposit summary.');
    }
    return data;
  }
}
