import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sign2digital/core/services/active_company_session.dart';
import 'package:sign2digital/core/services/sign_api_client.dart';
import 'package:sign2digital/features/deposits/data/remote_deposit_repository.dart';
import 'package:sign2digital/features/deposits/domain/deposit_record.dart';

Map<String,dynamic> deposit({int company=7,String status='pending',
    int version=1})=>{
  'id':31,'company_id':company,'job_id':34,'quote_id':null,
  'job':'Kitchen','job_reference':'J-34','client_name':'Jean Dupont',
  'amount_minor':12345,'deposit_date':'2026-11-05',
  'payment_method':'bank_transfer','reference_number':'WIRE-123',
  'notes':'Original','currency':'CHF','status':status,
  'lock_version':version,'received_at':null,'received_by':null,
  'refunded_at':null,
};

void main(){
  setUp(()=>ActiveCompanySession.set(7));
  tearDown(()=>ActiveCompanySession.clear());
  SignApiClient api(Future<http.Response> Function(http.Request) cb)=>
      SignApiClient(baseUrl:Uri.parse('https://example.test'),
        tokenProvider:() async=>'deposit-test',
        activeCompanyId:()=>ActiveCompanySession.companyId,
        httpClient:MockClient(cb));

  test('list parses exact CHF, status and company with no demo records',() async {
    final client=api((r) async{
      expect(r.headers['Authorization'],'Bearer deposit-test');
      expect(r.headers['X-Company-Id'],'7');
      expect(r.url.path,'/api/v1/deposits');
      return http.Response(jsonEncode({'data':{
        'records':[deposit()],'page':1,'last_page':1,
      }}),200);
    });
    final rows=await RemoteDepositRepository(api:client).listDeposits();
    expect(rows.length,1);
    expect(rows.single.id,'deposit-31');
    expect(rows.single.amount,123.45);
    expect(rows.single.lockVersion,1);
    expect(rows.single.status,DepositStatus.pending);
    expect(rows.single.demoOnly,false);
    client.dispose();
  });

  test('remote create sends manual confirmation fields without fake payment',() async{
    final client=api((r) async{
      expect(r.method,'POST');
      expect(r.url.path,'/api/v1/deposits');
      final body=jsonDecode(r.body) as Map<String,dynamic>;
      expect(body['job_id'],34);
      expect(body['amount'],'123.45');
      expect(body['payment_method'],'bank_transfer');
      expect(body['request_key'],'local-deposit-1');
      expect(body.containsKey('status'),false);
      expect(body.containsKey('paid'),false);
      return http.Response(jsonEncode({'data':{'deposit':deposit()}}),201);
    });
    await RemoteDepositRepository(api:client).saveDeposit(DepositRecord(
      id:'local-deposit-1',title:'Kitchen',clientName:'Jean Dupont',
      amount:123.45,date:DateTime(2026,11,5),
      status:DepositStatus.pending,jobId:'34',
      paymentMethod:'Bank Transfer',referenceNumber:'WIRE-123',
    ));
    client.dispose();
  });

  test('retry after a lost create response keeps the same key and amount',
      () async {
    final keys=<String>[];
    var attempts=0;
    final client=api((request) async {
      attempts++;
      final body=jsonDecode(request.body) as Map<String,dynamic>;
      keys.add(body['request_key'] as String);
      expect(body['amount'],'123.45');
      expect(body['job_id'],34);
      if(attempts==1){
        // The server may already have committed when a 503/timeout arrives.
        return http.Response(jsonEncode({'message':'Temporary connection failure'}),503);
      }
      return http.Response(jsonEncode({'data':{'deposit':deposit()}}),201);
    });
    final draft=DepositRecord(
      id:'local-deposit-9918',title:'Kitchen',
      clientName:'Jean Dupont',amount:123.45,date:DateTime(2026,11,5),
      status:DepositStatus.pending,jobId:'34',
      paymentMethod:'Bank Transfer',referenceNumber:'WIRE-123',
    );
    final repo=RemoteDepositRepository(api:client);
    await expectLater(repo.saveDeposit(draft),throwsA(isA<SignApiException>()));
    await repo.saveDeposit(draft);
    expect(attempts,2);
    expect(keys,['local-deposit-9918','local-deposit-9918']);
    client.dispose();
  });

  test('different draft identifiers create different request keys',
      () async {
    final keys=<String>[];
    final client=api((request) async {
      keys.add((jsonDecode(request.body) as Map<String,dynamic>)['request_key']
          as String);
      return http.Response(jsonEncode({'data':{'deposit':deposit()}}),201);
    });
    final repo=RemoteDepositRepository(api:client);
    DepositRecord draft(String id)=>DepositRecord(
      id:id,title:'Kitchen',clientName:'Jean Dupont',amount:123.45,
      date:DateTime(2026,11,5),status:DepositStatus.pending,jobId:'34',
      paymentMethod:'Bank Transfer',
    );
    await repo.saveDeposit(draft('local-deposit-100'));
    await repo.saveDeposit(draft('local-deposit-101'));
    expect(keys,['local-deposit-100','local-deposit-101']);
    client.dispose();
  });

  test('reject cross-company deposit records',() async{
    final client=api((r) async=>http.Response(jsonEncode({'data':{
      'records':[deposit(company:9)],'page':1,'last_page':1,
    }}),200));
    await expectLater(RemoteDepositRepository(api:client).listDeposits(),
      throwsA(isA<SignApiException>()));
    client.dispose();
  });

  test('company switch invalidates in-flight deposit list',() async{
    final pending=Completer<http.Response>();
    final client=api((r)=>pending.future);
    final reading=RemoteDepositRepository(api:client).listDeposits();
    await Future<void>.delayed(Duration.zero);
    ActiveCompanySession.set(8);
    pending.complete(http.Response(jsonEncode({'data':{
      'records':[deposit()],'page':1,'last_page':1,
    }}),200));
    await expectLater(reading,throwsA(isA<SignApiException>()));
    client.dispose();
  });

  test('manual receiving asks for confirmation and refreshes status',() async{
    var received=false;
    var reads=0;
    final client=api((r) async{
      if(r.url.path=='/api/v1/deposits/31'&&r.method=='GET'){
        reads++;
        return http.Response(jsonEncode({'data':{
          'deposit':deposit(status:received?'received':'pending',
            version:received?2:1),
          'receipts':[],'history':[],
        }}),200);
      }
      expect(r.url.path,'/api/v1/deposits/31/receive');
      final payload=jsonDecode(r.body) as Map<String,dynamic>;
      expect(payload['confirm'],true);
      expect(payload['lock_version'],1);
      received=true;
      return http.Response(jsonEncode({'data':{
        'deposit':deposit(status:'received',version:2),
      }}),200);
    });
    final actual=await RemoteDepositRepository(api:client)
        .receiveDeposit('deposit-31');
    expect(actual.status,DepositStatus.received);
    expect(reads,2);
    client.dispose();
  });

  test('summary requires server job identity and CHF',() async{
    final client=api((r) async{
      expect(r.url.path,'/api/v1/jobs/34/deposit-summary');
      return http.Response(jsonEncode({'data':{
        'job_id':34,'currency':'CHF','pending_minor':1000,
        'received_minor':2000,'refunded_minor':0,
        'invoice_application_status':'not_yet_integrated',
      }}),200);
    });
    final data=await RemoteDepositRepository(api:client).jobSummary(34);
    expect(data['received_minor'],2000);
    client.dispose();
  });
}
