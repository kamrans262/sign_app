import 'dart:io';
import 'package:crypto/crypto.dart';

import '../../../core/services/active_company_session.dart';
import '../../../core/services/sign_api_client.dart';
import '../../auth/data/mobile_auth_repository.dart';
import '../../jobs/data/local_job_photo_source.dart';
import '../domain/equipment_record.dart';
import '../services/equipment_voice_extraction_service.dart';

/// Company-scoped real equipment inventory. Never include demo rows once signed in.
class RemoteEquipmentRepository extends EquipmentRepository {
  RemoteEquipmentRepository({SignApiClient? api})
      : _api=api??MobileAuthRepository.shared.api;
  static final shared=RemoteEquipmentRepository();
  final SignApiClient _api;

  int _company(){
    final id=ActiveCompanySession.companyId;
    if(id==null||id<1)throw const SignApiException(
      'Select a company to manage equipment.');
    return id;
  }
  void _check(int expected){
    if(ActiveCompanySession.companyId!=expected){
      throw const SignApiException('Company changed during equipment request.');
    }
  }
  static Map<String,dynamic> _map(Object? raw){
    if(raw is! Map)throw const SignApiException('Invalid equipment server data.');
    return Map<String,dynamic>.from(raw);
  }
  static Map<String,dynamic> _data(Map<String,dynamic> raw)=>_map(raw['data']);
  static int _int(Object? raw)=>raw is num?raw.toInt():int.tryParse(raw.toString())??0;
  static double _real(Object? raw)=>raw is num?raw.toDouble():
      double.tryParse(raw.toString())??double.nan;
  static DateTime _date(Object? raw){
    final date=DateTime.tryParse(raw.toString());
    if(date==null||date.year<2000||date.year>2100){
      throw const SignApiException('Invalid equipment date.');
    }
    return date;
  }
  static String _day(DateTime date)=>[
    date.year.toString().padLeft(4,'0'),
    date.month.toString().padLeft(2,'0'),
    date.day.toString().padLeft(2,'0'),
  ].join('-');
  static String _path(int id)=>'/api/v1/equipment/'+id.toString();

  EquipmentRecord _record(Object? raw,int company,{
    List<LocalJobPhotoSelection> photos=const [],
  }){
    final row=_map(raw);
    final id=_int(row['id']),version=_int(row['lock_version']);
    if(id<1||version<1||_int(row['company_id'])!=company){
      throw const SignApiException('Invalid company-scoped equipment record.');
    }
    final status=switch(row['status']){
      'available'=>EquipmentStatus.available,
      'in_use'=>EquipmentStatus.inUse,
      'maintenance'=>EquipmentStatus.maintenance,
      _=>throw const SignApiException('Invalid equipment status.'),
    };
    final usage=<EquipmentUsage>[],maintenance=<EquipmentMaintenance>[],
        history=<EquipmentEvent>[];
    if(row['usage'] is! List||row['maintenance'] is! List||
        row['history'] is! List||row['photos'] is! List){
      throw const SignApiException('Missing equipment history or photos.');
    }
    for(final raw in row['usage'] as List){
      final u=_map(raw),amount=_real(u['hours']);
      if(!amount.isFinite||amount<=0){
        throw const SignApiException('Invalid usage hours.');
      }
      usage.add(EquipmentUsage(
        id:u['id'].toString(),date:_date(u['date']),
        hours:amount,
        job:u['job_id']==null?'':u['job_id'].toString(),
        notes:(u['notes']??'').toString()));
    }
    for(final raw in row['maintenance'] as List){
      final m=_map(raw);
      maintenance.add(EquipmentMaintenance(
        id:m['id'].toString(),date:_date(m['date']),
        description:(m['description']??'').toString(),
        completed:m['completed']==true||m['completed']==1));
    }
    for(final raw in row['history'] as List){
      final h=_map(raw);
      history.add(EquipmentEvent(
        id:h['id'].toString(),
        title:(h['type']??'').toString().replaceAll('_',' '),
        date:_date(h['created_at'])));
    }
    final origin=_real(row['initial_hours']);
    if(!origin.isFinite||origin<0){
      throw const SignApiException('Invalid equipment meter.');
    }
    final code=(row['code']??'').toString().trim();
    if(code.isEmpty)throw const SignApiException('Missing equipment code.');
    return EquipmentRecord(
      id:code,name:(row['name']??'').toString(),
      category:(row['category']??'').toString(),
      brand:(row['brand']??'').toString(),
      model:(row['model']??'').toString(),
      purchaseDate:_date(row['purchase_date']),
      status:status,location:(row['location']??'').toString(),
      notes:(row['notes']??'').toString(),
      initialHours:origin,photos:photos,usage:usage,
      maintenance:maintenance,history:history,
      createdAt:row['created_at']==null?null:_date(row['created_at']),
      serverId:id,lockVersion:version,
      currentLoanId:row['current_loan_id']==null
        ?null:_int(row['current_loan_id']),
      demoOnly:false,
    );
  }

  /// Authenticated voice suggestion only; OpenAI credentials remain in Laravel.
  Future<EquipmentVoiceSuggestion> prepareVoice(String audioPath) async{
    final company=_company();
    final bytes=await File(audioPath).readAsBytes();
    if(bytes.length<16||bytes.length>25*1024*1024){
      throw const SignApiException('Invalid equipment voice recording size.');
    }
    final mp4=String.fromCharCodes(bytes.sublist(4,8))=='ftyp';
    final wav=String.fromCharCodes(bytes.sublist(0,4))=='RIFF'&&
      String.fromCharCodes(bytes.sublist(8,12))=='WAVE';
    final aac=bytes[0]==255&&(bytes[1]&240)==240;
    if(!mp4&&!wav&&!aac){
      throw const SignApiException('Unsupported equipment voice recording.');
    }
    final result=_data(await _api.postMultipart('/api/v1/equipment/voice/prepare',
      filename:mp4?'equipment.m4a':(wav?'equipment.wav':'equipment.aac'),
      bytes:bytes,companyScoped:true,maxBytes:25*1024*1024));
    _check(company);
    if(result['saved']!=false||result['requires_user_review']!=true){
      throw const SignApiException('Equipment voice needs human confirmation.');
    }
    final suggestion=EquipmentVoiceSuggestion.fromJson(_map(result['suggestion']));
    if(!suggestion.hasData){
      throw const SignApiException('Voice recording contained no equipment details.');
    }
    return suggestion;
  }

  @override
  Future<List<EquipmentRecord>> listEquipment() async{
    final company=_company(),items=<EquipmentRecord>[];
    for(var page=1;page<=100;page++){
      final data=_data(await _api.get('/api/v1/equipment',
        companyScoped:true,
        queryParameters:{'page':page.toString(),'per_page':'100'}));
      _check(company);
      final raw=data['records'],last=_int(data['last_page']);
      if(raw is! List||last<page||last>100){
        throw const SignApiException('Equipment listing pagination is invalid.');
      }
      for(final item in raw)items.add(_record(item,company));
      if(page==last)return items;
    }
    throw const SignApiException('Equipment listing exceeded page limit.');
  }

  Future<EquipmentRecord> getByServerId(int id) async {
    if (id <= 0) throw const SignApiException('Invalid equipment ID.');
    final company = _company();
    final data = _data(await _api.get(_path(id), companyScoped: true));
    _check(company);
    final raw = _map(data['asset']);
    if (_int(raw['id']) != id) {
      throw const SignApiException('Equipment identity mismatch.');
    }
    return _record(raw, company);
  }

  Future<EquipmentRecord> detail(EquipmentRecord item) async{
    final id=item.serverId;
    if(id==null||id<1){
      throw const SignApiException('Not a synchronized equipment asset.');
    }
    final company=_company();
    final data=_data(await _api.get(_path(id),companyScoped:true));
    _check(company);
    final raw=_map(data['asset']);
    if(raw['photos'] is! List){
      throw const SignApiException('Equipment private photos unavailable.');
    }
    final photos=<LocalJobPhotoSelection>[];
    for(final entry in raw['photos'] as List){
      final p=_map(entry);
      final photoId=_int(p['id']),mime=(p['mime_type']??'').toString();
      if(photoId<1||!const ['image/jpeg','image/png'].contains(mime)){
        throw const SignApiException('Invalid equipment photo metadata.');
      }
      final bytes=await _api.getPrivateAttachment(
        _path(id)+'/photos/'+photoId.toString(),mimeType:mime,
        maxBytes:5*1024*1024);
      _check(company);
      if(bytes.length!=_int(p['byte_size'])||
          sha256.convert(bytes).toString()!=p['sha256']){
        throw const SignApiException('Equipment photo SHA-256 mismatch.');
      }
      photos.add(LocalJobPhotoSelection(
        name:(p['name']??'equipment-photo').toString(),
        bytes:bytes,sourceKey:'equipment-photo-'+photoId.toString()));
    }
    return _record(raw,company,photos:photos);
  }

  static Map<String,dynamic> _fields(EquipmentRecord r)=>{
    'code':r.id.trim(),'name':r.name.trim(),
    'category':r.category.trim(),'brand':r.brand.trim(),
    'model':r.model.trim(),'purchase_date':_day(r.purchaseDate),
    'status':switch(r.status){
      EquipmentStatus.available=>'available',
      EquipmentStatus.inUse=>'in_use',
      EquipmentStatus.maintenance=>'maintenance',
    },
    'location':r.location.trim(),'notes':r.notes.trim(),
    'initial_hours':r.initialHours,
    if(r.serverId!=null)'lock_version':r.lockVersion,
  };

  static void _photoCheck(LocalJobPhotoSelection file){
    DeviceJobPhotoSource.validate(file.name,file.bytes);
    if(file.bytes.length>5*1024*1024){
      throw const SignApiException('Maximum equipment image size is 5 MB.');
    }
  }

  Future<EquipmentRecord> _photos(EquipmentRecord initial,
      List<LocalJobPhotoSelection> desired,{bool removeOld=false}) async{
    final company=_company(),id=initial.serverId!;
    var current=initial;
    final existing=initial.photos.map((p)=>p.sourceKey).toSet();
    final selected=desired.map((p)=>p.sourceKey).toSet();
    if(removeOld){
      for(final p in initial.photos.where((p)=>!selected.contains(p.sourceKey))){
        final match=RegExp(r'^equipment-photo-(\d+)$').firstMatch(p.sourceKey);
        if(match==null)continue;
        final result=_data(await _api.request('DELETE',
          _path(id)+'/photos/'+match.group(1)!,
          companyScoped:true,data:{'lock_version':current.lockVersion}));
        _check(company);
        current=_record(result['asset'],company);
      }
    }
    for(final p in desired.where((p)=>!existing.contains(p.sourceKey))){
      _photoCheck(p);
      final response=_data(await _api.postMultipart(
        _path(id)+'/photos',filename:p.name,bytes:p.bytes,
        maxBytes:5*1024*1024,companyScoped:true,
        fields:{'lock_version':current.lockVersion.toString()}));
      _check(company);
      current=_record(response['asset'],company);
    }
    return current;
  }

  @override
  Future<EquipmentRecord> saveEquipment(EquipmentRecord item) async{
    final company=_company();
    if(item.serverId!=null)throw const SignApiException(
      'Existing equipment must be edited, not created.');
    for(final p in item.photos)_photoCheck(p);
    final response=_data(await _api.post('/api/v1/equipment',
      data:_fields(item),companyScoped:true));
    _check(company);
    var current=_record(response['asset'],company);
    try{
      current=await _photos(current,item.photos);
      return await detail(current);
    }catch(_){
      throw SignApiException('Equipment '+current.id+
        ' was saved but photo upload failed. Reopen it to retry.');
    }
  }

  @override
  Future<EquipmentRecord> updateEquipment(EquipmentRecord item) async{
    final company=_company(),id=item.serverId;
    if(id==null||id<1)throw const SignApiException(
      'Equipment is not synchronized.');
    final old=await detail(item);
    _check(company);
    if(old.lockVersion!=item.lockVersion){
      throw const SignApiException('Equipment changed on another device.',
        statusCode:409);
    }
    for(final p in item.photos)_photoCheck(p);
    final response=_data(await _api.request('PATCH',_path(id),
      data:_fields(item),companyScoped:true));
    _check(company);
    var updated=_record(response['asset'],company,photos:old.photos);
    updated=await _photos(updated,item.photos,removeOld:true);
    _check(company);
    return detail(updated);
  }

  Future<EquipmentRecord> _byCode(String code) async{
    final matches=(await listEquipment()).where((r)=>r.id==code).toList();
    if(matches.length!=1)throw const SignApiException(
      'Equipment does not exist in the selected company.');
    return detail(matches.single);
  }

  @override
  Future<EquipmentRecord> logUsage(String code,EquipmentUsage usage) async{
    final item=await _byCode(code),company=_company();
    final job=usage.job.trim();
    final jobId=job.isEmpty?null:int.tryParse(job);
    if(job.isNotEmpty&&(jobId==null||jobId<1)){
      throw const SignApiException('Enter a numeric Job ID or leave it blank.');
    }
    final response=_data(await _api.post(
      _path(item.serverId!)+'/usage',companyScoped:true,data:{
        'date':_day(usage.date),'hours':usage.hours,
        'notes':usage.notes,'lock_version':item.lockVersion,
        if(jobId!=null)'job_id':jobId,
      }));
    _check(company);
    return detail(_record(response['asset'],company));
  }

  @override
  Future<EquipmentRecord> scheduleMaintenance(String code,
      EquipmentMaintenance maintenance) async{
    final item=await _byCode(code),company=_company();
    final response=_data(await _api.post(
      _path(item.serverId!)+'/maintenance',companyScoped:true,data:{
        'date':_day(maintenance.date),'description':maintenance.description,
        'completed':maintenance.completed,'lock_version':item.lockVersion,
      }));
    _check(company);
    return detail(_record(response['asset'],company));
  }
}
