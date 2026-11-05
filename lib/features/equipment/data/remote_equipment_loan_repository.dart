import 'dart:io';

import '../../../core/services/active_company_session.dart';
import '../../../core/services/sign_api_client.dart';
import '../../auth/data/mobile_auth_repository.dart';
import '../../clients/data/remote_client_repository.dart';
import '../../clients/domain/client_profile.dart';
import '../domain/equipment_loan_record.dart';

/// M19 company-authoritative lending ledger; no client-side overdue authority.
class RemoteEquipmentLoanRepository extends EquipmentLoanRepository {
  RemoteEquipmentLoanRepository({SignApiClient? api}):
      _api=api??MobileAuthRepository.shared.api;
  static final shared=RemoteEquipmentLoanRepository();
  final SignApiClient _api;

  static int _int(Object? value)=>value is num?value.toInt():
      int.tryParse(value.toString())??0;
  static Map<String,dynamic> _map(Object? raw){
    if(raw is! Map)throw const SignApiException('Invalid loan data.');
    return Map<String,dynamic>.from(raw);
  }
  static Map<String,dynamic> _data(Map<String,dynamic> response)=>
      _map(response['data']);
  static DateTime _date(Object? raw){
    final date=DateTime.tryParse(raw.toString());
    if(date==null||date.year<2000||date.year>2100){
      throw const SignApiException('Invalid loan date.');
    }
    return date;
  }
  static String _day(DateTime d)=>[
    d.year.toString().padLeft(4,'0'),d.month.toString().padLeft(2,'0'),
    d.day.toString().padLeft(2,'0'),
  ].join('-');
  static String _path(int id)=>'/api/v1/equipment-loans/'+id.toString();
  int _company(){
    final company=ActiveCompanySession.companyId;
    if(company==null||company<1){
      throw const SignApiException('Select an equipment company.');
    }
    return company;
  }
  void _check(int expected){
    if(ActiveCompanySession.companyId!=expected){
      throw const SignApiException('Company changed during loan request.');
    }
  }

  EquipmentLoanRecord _parse(Object? raw,int company,{
    List<EquipmentLoanEvent> history=const [],
  }){
    final r=_map(raw);
    final id=_int(r['id']),assetId=_int(r['equipment_asset_id']);
    final version=_int(r['lock_version']),rowCompany=_int(r['company_id']);
    if(id<1||assetId<1||version<1||rowCompany!=company){
      throw const SignApiException('Invalid or cross-company equipment loan.');
    }
    final status=switch(r['status']){
      'active'=>EquipmentLoanStatus.active,
      'returned'=>EquipmentLoanStatus.returned,
      'overdue'=>EquipmentLoanStatus.overdue,
      _=>throw const SignApiException('Unrecognized loan lifecycle.'),
    };
    final borrowerType=(r['borrower_type']??'').toString();
    if(!const ['client','external'].contains(borrowerType)){
      throw const SignApiException('Invalid borrower type.');
    }
    final borrower=(r['borrower_name']??'').toString();
    if(borrower.isEmpty)throw const SignApiException('Missing borrower.');
    final actual=r['actual_return_date'];
    return EquipmentLoanRecord(
      id:id,companyId:company,assetId:assetId,
      equipmentCode:(r['equipment_code']??'').toString(),
      equipmentName:(r['equipment_name']??'').toString(),
      borrowerName:borrower,
      borrowerType:borrowerType,
      borrowerEmail:(r['borrower_email']??'').toString(),
      clientId:r['client_id']==null?null:_int(r['client_id']),
      jobId:r['job_id']==null?null:_int(r['job_id']),
      loanDate:_date(r['loan_date']),
      expectedReturnDate:_date(r['expected_return_date']),
      actualReturnDate:actual==null?null:_date(actual),
      status:status,
      lockVersion:version,notes:(r['notes']??'').toString(),
      events:history,
    );
  }

  Future<Map<String,dynamic>> prepareVoice(String audioPath) async{
    final company=_company();
    final file=File(audioPath);
    final bytes=await file.readAsBytes();
    if(bytes.length<16||bytes.length>25*1024*1024){
      throw const SignApiException('Invalid equipment recording.');
    }
    final mp4=String.fromCharCodes(bytes.sublist(4,8))=='ftyp';
    final wav=String.fromCharCodes(bytes.sublist(0,4))=='RIFF'&&
      String.fromCharCodes(bytes.sublist(8,12))=='WAVE';
    final aac=bytes[0]==255&&(bytes[1]&240)==240;
    if(!mp4&&!wav&&!aac){
      throw const SignApiException('Unsupported voice recording.');
    }
    final response=_data(await _api.postMultipart(
      '/api/v1/equipment-loans/voice/prepare',
      filename:mp4?'loan.m4a':(wav?'loan.wav':'loan.aac'),
      bytes:bytes,companyScoped:true,maxBytes:25*1024*1024));
    _check(company);
    if(response['saved']!=false||response['requires_user_review']!=true){
      throw const SignApiException('AI loan suggestion requires confirmation.');
    }
    final raw=_map(response['suggestion']);
    final normalized=<String,dynamic>{};
    for(final field in [
      'equipment_code','borrower_name','borrower_email','loan_date',
      'expected_return_date','notes'
    ]){
      final value=raw[field];
      if(value!=null&&value is! String){
        throw const SignApiException('Invalid AI voice suggestion.');
      }
      normalized[field]=value;
    }
    return normalized;
  }

  @override
  Future<List<EquipmentLoanRecord>> listLoans() async{
    final company=_company(),records=<EquipmentLoanRecord>[];
    for(var page=1;page<=100;page++){
      final data=_data(await _api.get('/api/v1/equipment-loans',
        companyScoped:true,queryParameters:{
          'page':page.toString(),'per_page':'100',
        }));
      _check(company);
      final rows=data['records'],last=_int(data['last_page']);
      if(rows is! List||last<page||last>100){
        throw const SignApiException('Invalid equipment loan listing.');
      }
      records.addAll(rows.map((r)=>_parse(r,company)));
      if(page==last)return records;
    }
    throw const SignApiException('Loan pagination limit exceeded.');
  }

  Future<List<ClientProfile>> clients() async{
    final company=_company();
    final result=await RemoteClientRepository.shared.listClients();
    _check(company);
    return result;
  }

  @override
  Future<EquipmentLoanRecord> createLoan(EquipmentLoanRecord item) async{
    final company=_company();
    if(item.id!=null||item.assetId<1||
        item.borrowerName.trim().length<2||
        item.expectedReturnDate.isBefore(item.loanDate)){
      throw const SignApiException('Complete valid loan details first.');
    }
    final key=item.requestKey.isEmpty
      ?'m19-loan-'+DateTime.now().microsecondsSinceEpoch.toString()
      :item.requestKey;
    final data=_data(await _api.post('/api/v1/equipment-loans',
      companyScoped:true,data:{
        'equipment_asset_id':item.assetId,
        'borrower_type':item.borrowerType,
        'borrower_name':item.borrowerName.trim(),
        if(item.borrowerEmail.trim().isNotEmpty)
          'borrower_email':item.borrowerEmail.trim(),
        if(item.clientId!=null)'client_id':item.clientId,
        if(item.jobId!=null)'job_id':item.jobId,
        'loan_date':_day(item.loanDate),
        'expected_return_date':_day(item.expectedReturnDate),
        'notes':item.notes,'request_key':key,
      }));
    _check(company);
    return _parse(data['loan'],company);
  }

  @override
  Future<EquipmentLoanRecord> detail(int id) async{
    if(id<1)throw const SignApiException('Invalid equipment loan identifier.');
    final company=_company();
    final data=_data(await _api.get(_path(id),companyScoped:true));
    _check(company);
    final raw=data['history'];
    if(raw is! List){
      throw const SignApiException('Missing audited loan history.');
    }
    final entries=<EquipmentLoanEvent>[];
    for(final row in raw){
      final h=_map(row);
      final meta=_map(h['metadata']);
      entries.add(EquipmentLoanEvent(
        id:_int(h['id']),type:(h['type']??'').toString(),
        actorId:h['actor_id']==null?null:_int(h['actor_id']),
        date:_date(h['created_at']),
        oldDate:meta['old_date']?.toString(),
        newDate:meta['new_date']?.toString(),
      ));
    }
    return _parse(data['loan'],company,history:entries);
  }

  @override
  Future<EquipmentLoanRecord> extend(int id,int version,DateTime date) async{
    final company=_company();
    if(id<1||version<1)throw const SignApiException('Invalid loan version.');
    final data=_data(await _api.post(_path(id)+'/extend',
      companyScoped:true,data:{
        'confirm':true,'lock_version':version,
        'expected_return_date':_day(date),
      }));
    _check(company);
    _parse(data['loan'],company);
    return detail(id);
  }

  @override
  Future<EquipmentLoanRecord> markReturned(
      int id,int version,DateTime date) async{
    final company=_company();
    if(id<1||version<1)throw const SignApiException('Invalid loan version.');
    final data=_data(await _api.post(_path(id)+'/return',
      companyScoped:true,data:{
        'confirm':true,'lock_version':version,
        'actual_return_date':_day(date),
      }));
    _check(company);
    _parse(data['loan'],company);
    return detail(id);
  }
}
