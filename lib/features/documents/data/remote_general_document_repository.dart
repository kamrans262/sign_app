import 'dart:typed_data';
import '../../../core/services/active_company_session.dart';
import '../../../core/services/sign_api_client.dart';
import '../../auth/data/mobile_auth_repository.dart';
import '../domain/document_record.dart';
import '../domain/general_document_draft.dart';

/// M18 company-scoped authoring. No demo rows or client-generated approvals.
class RemoteGeneralDocumentRepository extends DocumentRepository {
  RemoteGeneralDocumentRepository({SignApiClient? api})
      : _api=api??MobileAuthRepository.shared.api;
  static final shared=RemoteGeneralDocumentRepository();

  final SignApiClient _api;

  static Map<String,dynamic> _map(Object? raw){
    if(raw is! Map)throw const SignApiException('Invalid document API response.');
    return Map<String,dynamic>.from(raw);
  }
  static Map<String,dynamic> _data(Map<String,dynamic> response)=>
      _map(response['data']);
  static int _int(Object? n)=>n is int?n:int.tryParse('$n')??0;
  int _company(){
    final id=ActiveCompanySession.companyId;
    if(id==null||id<1)throw const SignApiException('Select a company first.');
    return id;
  }
  void _check(int company){
    if(ActiveCompanySession.companyId!=company){
      throw const SignApiException('Company changed during document request.');
    }
  }

  GeneralDocumentDraft _parse(Object? value,int company,{
    List<GeneralTextBlock> blocks=const [],
    String source='manual',
  }){
    final row=_map(value);
    final id=_int(row['id']),version=_int(row['revision']);
    final lock=_int(row['lock_version']);
    final type=(row['type']??'').toString();
    final status=(row['status']??'').toString();
    if(id<1||_int(row['company_id'])!=company||version<1||lock<1||
        !const ['letter','statement','power_of_attorney','acceptance','custom']
          .contains(type)||
        !const ['draft','reviewed','approved','archived'].contains(status)||
        (row['number']??'').toString().isEmpty){
      throw const SignApiException('Invalid or cross-company general document.');
    }
    return GeneralDocumentDraft(
      id:id,companyId:company,number:row['number'].toString(),
      type:type,title:(row['title']??'').toString(),
      locale:(row['locale']??'en').toString(),
      clientId:row['client_id']==null?null:_int(row['client_id']),
      jobId:row['job_id']==null?null:_int(row['job_id']),
      status:status,revision:version,lockVersion:lock,
      blocks:blocks,source:source,
      clientName:(row['client_name']??'').toString(),
      jobTitle:(row['job']??'').toString(),
      createdAt:DateTime.tryParse((row['created_at']??'').toString()));
  }

  Future<List<GeneralDocumentDraft>> list() async {
    final company=_company(),result=<GeneralDocumentDraft>[];
    for(var page=1;page<=100;page++){
      final data=_data(await _api.get('/api/v1/general-documents',
        companyScoped:true,queryParameters:{'page':'$page','per_page':'100'}));
      _check(company);
      final rows=data['records'];
      if(rows is! List)throw const SignApiException('Missing general document rows.');
      for(final row in rows){
        result.add(_parse(row,company));
      }
      final last=_int(data['last_page']);
      if(last<page||last>100)throw const SignApiException('Invalid document pagination.');
      if(page==last)return result;
    }
    throw const SignApiException('Document listing exceeded page limit.');
  }

  @override
  Future<List<DocumentRecord>> listDocuments() async=>
      (await list()).map((r)=>r.toDocumentRecord()).toList();

  Future<GeneralDocumentDraft> detail(int id) async {
    final company=_company();
    if(id<1)throw const SignApiException('Invalid document identifier.');
    final data=_data(await _api.get('/api/v1/general-documents/$id',
      companyScoped:true));
    _check(company);
    final revision=_map(data['content']);
    final raw=revision['blocks'];
    if(raw is! List||raw.isEmpty||raw.length>100){
      throw const SignApiException('Missing document revision.');
    }
    final blocks=<GeneralTextBlock>[];
    try{
      for(final value in raw){
        blocks.add(GeneralTextBlock.fromJson(_map(value)));
      }
    }catch(_){
      throw const SignApiException('Invalid document paragraph.');
    }
    final result=_parse(data['document'],company,
      blocks:List.unmodifiable(blocks),
      source:(revision['source']??'manual').toString());
    if(result.revision!=_int(revision['revision'])){
      throw const SignApiException('Document revision mismatch.');
    }
    return result;
  }



  /// Authenticated dictation: byte stream goes only to Laravel, never to a
  /// mobile-stored OpenAI key. Transcription is not an approved document.
  Future<String> transcribe(Uint8List bytes,String filename) async {
    final company=_company();
    final data=_data(await _api.postMultipart(
      '/api/v1/general-documents/voice/transcribe',
      filename:filename,bytes:bytes,maxBytes:25*1024*1024,
      companyScoped:true));
    _check(company);
    final text=data['transcript'];
    if(text is! String||text.trim().isEmpty||text.length>20000||
        data['saved']!=false||data['approved']!=false){
      throw const SignApiException('Document voice transcript was not verified.');
    }
    return text.trim();
  }

  Future<List<Map<String,dynamic>>> attachments(int id) async {
    final company=_company();
    final response=_data(await _api.get('/api/v1/general-documents/$id',
      companyScoped:true));
    _check(company);
    final document=_parse(response['document'],company);
    if(document.id!=id||response['attachments'] is! List){
      throw const SignApiException('Invalid general document attachments.');
    }
    return (response['attachments'] as List).map((raw){
      final row=_map(raw);
      if(_int(row['id'])<1||
          !const ['application/pdf','image/png','image/jpeg'].contains(
            (row['mime_type']??'').toString())){
        throw const SignApiException('Invalid attachment metadata.');
      }
      return row;
    }).toList();
  }

  Future<void> attach(int id,String filename,Uint8List bytes) async {
    final company=_company();
    final result=_data(await _api.postMultipart(
      '/api/v1/general-documents/$id/attachments',filename:filename,
      bytes:bytes,companyScoped:true,maxBytes:10*1024*1024));
    _check(company);
    if(_int(result['id'])<1){
      throw const SignApiException('Document attachment not confirmed.');
    }
  }

  Future<void> removeAttachment(int id,int attachment) async {
    final company=_company();
    await _api.delete('/api/v1/general-documents/$id/attachments/$attachment',
      companyScoped:true);
    _check(company);
  }

  static void _validate(GeneralDocumentDraft draft){
    if(!const ['letter','statement','power_of_attorney','acceptance','custom']
          .contains(draft.type)||
      !const ['en','fr','de','it'].contains(draft.locale)||
      draft.title.trim().length<2||draft.title.trim().length>255||
      draft.blocks.isEmpty||draft.blocks.length>100||
      !const ['manual','ai_draft','note_conversion'].contains(draft.source)){
      throw const SignApiException('Complete the document title and content.');
    }
    var size=0;
    for(final block in draft.blocks){
      if(!GeneralTextBlock.kinds.contains(block.type)||
          block.text.length>4000){
        throw const SignApiException('Invalid document paragraph.');
      }
      size+=block.text.length;
    }
    if(size>30000||draft.blocks.every((b)=>b.text.trim().isEmpty)){
      throw const SignApiException('Enter document content under 30,000 characters.');
    }
  }

  Future<GeneralDocumentDraft> save(GeneralDocumentDraft draft,{
    required String createRequestKey,
  }) async {
    _validate(draft);
    final company=_company();
    final payload=<String,dynamic>{
      'type':draft.type,'title':draft.title.trim(),'locale':draft.locale,
      'client_id':draft.clientId,'job_id':draft.jobId,
      'blocks':[for(final block in draft.blocks)block.toJson()],
      'source':draft.source,
      if(draft.id==null)'request_key':createRequestKey,
      if(draft.id!=null)'lock_version':draft.lockVersion,
    };
    final response=draft.id==null
      ? await _api.post('/api/v1/general-documents',
          companyScoped:true,data:payload)
      : await _api.request('PATCH',
          '/api/v1/general-documents/'+draft.id.toString(),
          companyScoped:true,data:payload);
    _check(company);
    final saved=_parse(_data(response)['document'],company);
    if(saved.status!='draft'||(draft.id!=null&&saved.id!=draft.id)){
      throw const SignApiException('Document save not confirmed.');
    }
    return detail(saved.id!);
  }

  Future<GeneralDocumentDraft> transition(int id,String action,{
    required int lockVersion,
  }) async {
    if(!const ['review','approve','archive'].contains(action)){
      throw const SignApiException('Invalid document workflow action.');
    }
    final company=_company();
    final data=_data(await _api.post(
      '/api/v1/general-documents/$id/$action',
      companyScoped:true,data:{'confirm':true,'lock_version':lockVersion}));
    _check(company);
    final record=_parse(data['document'],company);
    final expected=action=='review'?'reviewed':
        action=='approve'?'approved':'archived';
    if(record.id!=id||record.status!=expected){
      throw const SignApiException('Document workflow was not confirmed.');
    }
    return detail(id);
  }

  Future<GeneralDocumentDraft> suggest({
    required String type,required String locale,required String instructions,
    int? clientId,int? jobId,
  }) async {
    final company=_company();
    final data=_data(await _api.post('/api/v1/general-documents/ai/prepare',
      companyScoped:true,data:{
        'type':type,'locale':locale,'instructions':instructions,
        'client_id':clientId,'job_id':jobId,
      }));
    _check(company);
    final suggestion=_map(data['suggestion']);
    final raw=suggestion['blocks'];
    if(suggestion['saved']!=false||
        suggestion['requires_user_review']!=true||
        raw is! List||raw.isEmpty){
      throw const SignApiException('AI did not return a reviewable suggestion.');
    }
    final blocks=<GeneralTextBlock>[];
    try{
      for(final value in raw){
        blocks.add(GeneralTextBlock.fromJson(_map(value)));
      }
    }catch(_){
      throw const SignApiException('Invalid AI document paragraphs.');
    }
    final title=(suggestion['title']??'').toString();
    if(title.isEmpty||title.length>255){
      throw const SignApiException('AI returned invalid document title.');
    }
    return GeneralDocumentDraft(type:type,title:title,locale:locale,
      clientId:clientId,jobId:jobId,
      blocks:List.unmodifiable(blocks),source:'ai_draft');
  }
}
