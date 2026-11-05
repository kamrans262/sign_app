import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sign2digital/core/services/active_company_session.dart';
import 'package:sign2digital/core/services/sign_api_client.dart';
import 'package:sign2digital/features/documents/data/remote_general_document_repository.dart';
import 'package:sign2digital/features/documents/domain/general_document_draft.dart';

Map<String,dynamic> document({int company=7,String status='draft',
    int revision=1,int version=1})=> {
  'id':41,'company_id':company,'number':'GD-2026-ABCDEF',
  'type':'letter','title':'Customer Letter','locale':'en',
  'client_id':11,'job_id':32,'status':status,
  'revision':revision,'lock_version':version,
  'created_at':'2026-11-05T14:00:00Z',
  'job':'Office Repair','client_name':'Marie Dubois',
};
Map<String,dynamic> detail({String status='draft',int version=1,
    int revision=1})=>{
  'data':{
    'document':document(status:status,version:version,revision:revision),
    'content':{
      'revision':revision,'source':'manual',
      'blocks':[{'type':'paragraph','text':'Hello customer.',
        'bold':false,'italic':false}],
    },
    'revisions':[],'history':[],'attachments':[],
  },
};
GeneralDocumentDraft draft()=>const GeneralDocumentDraft(
  title:'Customer Letter',type:'letter',locale:'en',clientId:11,jobId:32,
  blocks:[GeneralTextBlock(type:'paragraph',text:'Hello customer.')]);

void main(){
  setUp(()=>ActiveCompanySession.set(7));
  tearDown(()=>ActiveCompanySession.clear());

  SignApiClient api(Future<http.Response> Function(http.Request) responder)=>
    SignApiClient(baseUrl:Uri.parse('https://example.test'),
      tokenProvider:() async=>'m18-token',
      activeCompanyId:()=>ActiveCompanySession.companyId,
      httpClient:MockClient(responder));

  test('company-scoped general documents appear once without demo PDFs',() async{
    final c=api((request) async{
      expect(request.headers['Authorization'],'Bearer m18-token');
      expect(request.headers['X-Company-Id'],'7');
      expect(request.url.path,'/api/v1/general-documents');
      return http.Response(jsonEncode({'data':{
        'records':[document()],'page':1,'last_page':1,
      }}),200);
    });
    final records=await RemoteGeneralDocumentRepository(api:c).listDocuments();
    expect(records.single.id,'general-41');
    expect(records.single.title,'Customer Letter');
    expect(records.single.verifiedSignedPdfAvailable,false);
    expect(records.single.demoOnly,false);
    c.dispose();
  });

  test('manual create sends canonical blocks and preserves retry key',() async{
    final paths=<String>[];
    final c=api((request) async{
      paths.add(request.url.path);
      if(request.method=='POST'){
        final payload=jsonDecode(request.body) as Map;
        expect(payload['request_key'],'m18-client-request-abc123');
        expect(payload['source'],'manual');
        expect(payload['blocks'],[{
          'type':'paragraph','text':'Hello customer.',
          'bold':false,'italic':false,
        }]);
        return http.Response(jsonEncode({'data':{'document':document()}}),201);
      }
      return http.Response(jsonEncode(detail()),200);
    });
    final result=await RemoteGeneralDocumentRepository(api:c).save(
      draft(),createRequestKey:'m18-client-request-abc123');
    expect(result.id,41);
    expect(result.blocks.single.text,'Hello customer.');
    expect(paths,['/api/v1/general-documents','/api/v1/general-documents/41']);
    c.dispose();
  });

  test('server revision and company identity are always checked',() async{
    final c=api((request) async{
      final changed=detail();
      (changed['data'] as Map)['document']=document(company:8);
      return http.Response(jsonEncode(changed),200);
    });
    await expectLater(RemoteGeneralDocumentRepository(api:c).detail(41),
      throwsA(isA<SignApiException>()));
    c.dispose();
  });

  test('company switch invalidates a pending document response',() async{
    final pending=Completer<http.Response>();
    final c=api((request)=>pending.future);
    final future=RemoteGeneralDocumentRepository(api:c).list();
    await Future<void>.delayed(Duration.zero);
    ActiveCompanySession.set(8);
    pending.complete(http.Response(jsonEncode({'data':{
      'records':[document()],'page':1,'last_page':1,
    }}),200));
    await expectLater(future,throwsA(isA<SignApiException>()));
    c.dispose();
  });

  test('review transition is verified by reloading exact document',() async{
    final paths=<String>[];
    final c=api((request) async{
      paths.add(request.url.path);
      if(request.method=='POST'){
        expect(jsonDecode(request.body),{'confirm':true,'lock_version':1});
        return http.Response(jsonEncode({'data':{
          'document':document(status:'reviewed',version:2),
        }}),200);
      }
      return http.Response(jsonEncode(detail(status:'reviewed',version:2)),200);
    });
    final doc=await RemoteGeneralDocumentRepository(api:c).transition(
      41,'review',lockVersion:1);
    expect(doc.status,'reviewed');
    expect(paths,['/api/v1/general-documents/41/review',
      '/api/v1/general-documents/41']);
    c.dispose();
  });

  test('AI suggestion is unsaved and requires explicit review',() async{
    final c=api((request) async{
      expect(request.url.path,'/api/v1/general-documents/ai/prepare');
      return http.Response(jsonEncode({'data':{
        'suggestion':{
          'title':'Draft Update','saved':false,
          'requires_user_review':true,
          'blocks':[{'type':'paragraph','text':'Needs review.',
            'bold':false,'italic':false}],
        },
      }}),200);
    });
    final doc=await RemoteGeneralDocumentRepository(api:c).suggest(
      type:'letter',locale:'en',instructions:'Draft an update.');
    expect(doc.id,isNull);
    expect(doc.source,'ai_draft');
    expect(doc.blocks.single.text,'Needs review.');
    c.dispose();
  });

  test('AI errors never fabricate a saved document',() async{
    final c=api((request) async=>http.Response(
      jsonEncode({'message':'OpenAI quota exhausted'}),503));
    await expectLater(RemoteGeneralDocumentRepository(api:c).suggest(
      type:'letter',locale:'en',instructions:'Draft a letter'),
      throwsA(isA<SignApiException>()));
    c.dispose();
  });
}
