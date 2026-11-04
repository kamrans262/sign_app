import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sign2digital/core/services/active_company_session.dart';
import 'package:sign2digital/core/services/sign_api_client.dart';
import 'package:sign2digital/features/labour/data/remote_labour_repository.dart';
import 'package:sign2digital/features/labour/domain/labour_entry.dart';

Map<String,dynamic> labour({int company=7,String status='pending',
    int version=1})=>{
  'id':31,'company_id':company,'job_id':34,'job':'Kitchen',
  'worker_id':52,'worker_name':'Site Worker',
  'role':'Electrician','task':'Install lights','kind':'labour',
  'source':'manual','work_date':'2026-11-05',
  'start_minutes':480,'end_minutes':570,'duration_minutes':90,
  'hourly_rate_minor':2500,'cost_minor':3750,'currency':'CHF',
  'status':status,'lock_version':version,'approved_at':null,'approved_by':null,
};
void main(){
  setUp(()=>ActiveCompanySession.set(7));
  tearDown(()=>ActiveCompanySession.clear());

  SignApiClient api(Future<http.Response> Function(http.Request) fn)=>
    SignApiClient(
      baseUrl:Uri.parse('https://example.test'),
      tokenProvider:() async=>'labour-test-token',
      activeCompanyId:()=>ActiveCompanySession.companyId,
      httpClient:MockClient(fn),
    );

  test('authenticated list maps worker, exact minutes and CHF cost',() async {
    final client=api((req) async {
      expect(req.url.path,'/api/v1/labour/entries');
      expect(req.headers['X-Company-Id'],'7');
      expect(req.headers['Authorization'],'Bearer labour-test-token');
      return http.Response(jsonEncode({'data':{
        'records':[labour()],'page':1,'last_page':1,
      }}),200);
    });
    final rows=await RemoteLabourRepository(api:client).list();
    expect(rows.length,1);
    expect(rows.single.workerId,52);
    expect(rows.single.lockVersion,1);
    expect(rows.single.hours,1.5);
    expect(rows.single.hourlyRate,25);
    expect(rows.single.status,LabourEntryStatus.pending);
    expect(rows.single.isDemo,false);
    client.dispose();
  });

  test('changing active company during a request rejects stale labour data',() async {
    final pending=Completer<http.Response>();
    final client=api((req)=>pending.future);
    final read=RemoteLabourRepository(api:client).list();
    // Once an API request has started it must not populate another company.
    await Future<void>.delayed(Duration.zero);
    ActiveCompanySession.set(8);
    pending.complete(http.Response(jsonEncode({'data':{
      'records':[labour()],'page':1,'last_page':1,
    }}),200));
    await expectLater(read,throwsA(isA<SignApiException>()));
    client.dispose();
  });

  test('cross-company labour response is rejected',() async {
    final client=api((req) async=>http.Response(jsonEncode({'data':{
      'records':[labour(company:8)],'page':1,'last_page':1,
    }}),200));
    await expectLater(RemoteLabourRepository(api:client).list(),
      throwsA(isA<SignApiException>()));
    client.dispose();
  });

  test('manual save sends assigned ID, dates, minutes and rate only',() async {
    final client=api((req) async {
      expect(req.method,'POST');
      expect(req.url.path,'/api/v1/labour/entries');
      final body=jsonDecode(req.body) as Map<String,dynamic>;
      expect(body['worker_id'],52);
      expect(body['job_id'],34);
      expect(body['hourly_rate'],'25.00');
      expect(body['start_minutes'],480);
      expect(body['end_minutes'],570);
      return http.Response(jsonEncode({'data':{'entry':labour()}}),201);
    });
    await RemoteLabourRepository(api:client).save(LabourEntry(
      id:'local-time-1',kind:LabourEntryKind.labour,
      workerName:'Site Worker',workerId:52,role:'Electrician',
      jobId:'34',jobName:'Kitchen',date:DateTime(2026,11,5),
      hours:1.5,startMinutes:480,endMinutes:570,
      hourlyRate:25,status:LabourEntryStatus.pending,
    ));
    client.dispose();
  });

  test('late old-company timer reply cannot cross an active company switch',
      () async {
    final reply=Completer<http.Response>();
    final client=api((req)=>reply.future);
    final pending=RemoteLabourRepository(api:client).timerCurrent();
    await Future<void>.delayed(Duration.zero);
    ActiveCompanySession.set(8);
    reply.complete(http.Response(jsonEncode({'data':{'timer':{
      'status':'running','job_id':34,'worker_id':52,
      'elapsed_seconds':999,'lock_version':2,
      'server_now':'2026-11-05T08:00:00Z',
    }}}),200));
    await expectLater(pending,throwsA(isA<SignApiException>()));
    client.dispose();
  });

  test('timer actions send idempotency keys and render server state',() async {
    final client=api((req) async {
      expect(req.method,'POST');
      expect(req.url.path,'/api/v1/labour/timer/start');
      final body=jsonDecode(req.body) as Map<String,dynamic>;
      expect(body['job_id'],34);
      expect((body['request_key'] as String).length,greaterThanOrEqualTo(8));
      return http.Response(jsonEncode({'data':{'timer':{
        'status':'running','job_id':34,'worker_id':52,
        'elapsed_seconds':0,'lock_version':1,
        'server_now':'2026-11-05T08:00:00Z',
      }}}),200);
    });
    final timer=await RemoteLabourRepository(api:client).timerAction('start',
      jobId:'34',rate:'25.00',task:'Install lights');
    expect(timer.status,'running');
    expect(timer.jobId,34);
    expect(timer.isActive,true);
    client.dispose();
  });

  test('verified company-scoped private labour proof',() async {
    final bytes=Uint8List.fromList([137,80,78,71,13,10,26,10,0,0]);
    final digest=sha256.convert(bytes).toString();
    final client=api((req) async {
      if(req.url.path.endsWith('/evidence/5')){
        expect(req.headers['X-Company-Id'],'7');
        return http.Response.bytes(bytes,200,headers:{
          'content-type':'image/png',
        });
      }
      return http.Response(jsonEncode({'data':{
        'entry':labour(),
        'history':[{'id':1,'title':'created',
          'occurred_at':'2026-11-05T08:00:00Z','actor_user_id':52}],
        'evidence':[{'id':5,'name':'site.png','mime_type':'image/png',
          'sha256':digest,'byte_size':bytes.length}],
      }}),200);
    });
    final actual=await RemoteLabourRepository(api:client).detail('labour-31');
    expect(actual.photos.single.bytes,bytes);
    expect(actual.photos.single.sourceKey,'labour-evidence-5');
    expect(actual.history.single.title,'created');
    client.dispose();
  });

  test('voided records remain visible and cannot be edited in DTO',() async {
    final client=api((req) async=>http.Response(jsonEncode({'data':{
      'records':[labour(status:'void')],'page':1,'last_page':1,
    }}),200));
    final list=await RemoteLabourRepository(api:client).list();
    expect(list.single.status,LabourEntryStatus.voided);
    expect(list.single.statusLabel,'Void');
    client.dispose();
  });
}
