import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sign2digital/core/services/active_company_session.dart';
import 'package:sign2digital/core/services/sign_api_client.dart';
import 'package:sign2digital/features/invoices/data/remote_invoice_repository.dart';
import 'package:sign2digital/features/invoices/domain/invoice_record.dart';

Map<String,dynamic> serverInvoice({int company=7,String status='draft',
    int version=1,int deposit=0})=>{
  'id':31,'company_id':company,'job_id':34,'client_id':81,'quote_id':null,
  'number':'INV-C7-001','type':'final',
  'job':'Kitchen','job_reference':'J-34','client_name':'Jean Dupont',
  'client_email':'jean@example.test',
  'total_minor':27025,'subtotal_minor':25000,'vat_minor':2025,
  'vat_basis_points':810,'deposit_paid_minor':deposit,
  'received_minor':0,'amount_due_minor':27025-deposit,
  'invoice_date':'2026-11-05','due_date':'2026-12-05',
  'currency':'CHF','status':status,
  'lifecycle_status':status=='draft'?'draft':'approved',
  'lock_version':version,'notes':'Actual invoice','terms':'30 days',
  'iban':'CH9300762011623852957','billing_address':'Main Street',
  'created_at':'2026-11-05T13:00:00Z','updated_at':'2026-11-05T13:00:00Z',
};
Map<String,dynamic> detailed({String status='draft',int version=1})=>{
  'data':{
    'invoice':serverInvoice(status:status,version:version),
    'items':[
      {'description':'Parts','quantity':2,'unit_price_minor':10000,'total_minor':20000},
      {'description':'Labour','quantity':1,'unit_price_minor':5000,'total_minor':5000},
    ],
    'payments':[],'history':[],'attachments':[],
  },
};
InvoiceRecord draft(String id)=>InvoiceRecord(
  id:id,number:'INV-C7-001',project:'Kitchen',
  clientName:'Jean Dupont',jobId:'34',amount:270.25,
  date:DateTime(2026,11,5),dueDate:DateTime(2026,12,5),
  status:InvoiceStatus.draft,
  vatBasisPoints:810,iban:'CH9300762011623852957',
  invoiceType:'final',
  items:const [
    InvoiceLineItem(description:'Parts',quantity:2,unitPriceMinor:10000),
    InvoiceLineItem(description:'Labour',quantity:1,unitPriceMinor:5000),
  ],
);

void main(){
  setUp(()=>ActiveCompanySession.set(7));
  tearDown(()=>ActiveCompanySession.clear());
  SignApiClient api(Future<http.Response> Function(http.Request) callback)=>
      SignApiClient(baseUrl:Uri.parse('https://example.test'),
        tokenProvider:() async=>'m17-test-key',
        activeCompanyId:()=>ActiveCompanySession.companyId,
        httpClient:MockClient(callback));

  test('lists authenticated server invoices without merging demo payments',
      () async {
    final c=api((r) async {
      expect(r.method,'GET');
      expect(r.url.path,'/api/v1/invoices');
      expect(r.headers['Authorization'],'Bearer m17-test-key');
      expect(r.headers['X-Company-Id'],'7');
      return http.Response(jsonEncode({'data':{
        'records':[serverInvoice()],'page':1,'last_page':1,
      }}),200);
    });
    final records=await RemoteInvoiceRepository(api:c).listInvoices();
    expect(records.length,1);
    expect(records.single.id,'invoice-31');
    expect(records.single.amount,270.25);
    expect(records.single.status,InvoiceStatus.draft);
    expect(records.single.demoOnly,false);
    expect(records.single.payments,isEmpty);
    c.dispose();
  });

  test('create sends idempotent source and integer CHF item prices',() async {
    final c=api((r) async {
      expect(r.method,'POST');
      expect(r.url.path,'/api/v1/invoices');
      final body=jsonDecode(r.body) as Map<String,dynamic>;
      expect(body['job_id'],34);
      expect(body['request_key'],'local-invoice-00001');
      expect(body['invoice_type'],'final');
      expect(body['vat_basis_points'],810);
      expect(body['allocate_deposits'],true);
      expect(body['items'],[
        {'description':'Parts','quantity':2,'unit_price_minor':10000},
        {'description':'Labour','quantity':1,'unit_price_minor':5000},
      ]);
      expect(body.containsKey('paid'),false);
      expect(body.containsKey('status'),false);
      return http.Response(jsonEncode({'data':{
        'invoice':serverInvoice(),
      }}),201);
    });
    await RemoteInvoiceRepository(api:c).saveDraft(draft('local-invoice-00001'));
    c.dispose();
  });

  test('lost reply can reuse exact invoice create key on retry',() async {
    var count=0;
    final keys=<String>[];
    final c=api((r) async {
      keys.add((jsonDecode(r.body) as Map<String,dynamic>)['request_key']
          as String);
      count++;
      if(count==1){
        return http.Response(jsonEncode({'message':'Unavailable'}),503);
      }
      return http.Response(jsonEncode({'data':{
        'invoice':serverInvoice(),
      }}),201);
    });
    final repo=RemoteInvoiceRepository(api:c);
    final invoice=draft('local-invoice-42');
    await expectLater(repo.saveDraft(invoice),
      throwsA(isA<SignApiException>()));
    await repo.saveDraft(invoice);
    expect(keys,['local-invoice-42','local-invoice-42']);
    c.dispose();
  });

  test('rejects another company invoice embedded in list',() async {
    final c=api((r) async=>http.Response(jsonEncode({'data':{
      'records':[serverInvoice(company:8)],'page':1,'last_page':1,
    }}),200));
    await expectLater(RemoteInvoiceRepository(api:c).listInvoices(),
      throwsA(isA<SignApiException>()));
    c.dispose();
  });

  test('company switch rejects in-flight invoice responses',() async {
    final pending=Completer<http.Response>();
    final c=api((r)=>pending.future);
    final future=RemoteInvoiceRepository(api:c).listInvoices();
    await Future<void>.delayed(Duration.zero);
    ActiveCompanySession.set(9);
    pending.complete(http.Response(jsonEncode({'data':{
      'records':[serverInvoice()],'page':1,'last_page':1,
    }}),200));
    await expectLater(future,throwsA(isA<SignApiException>()));
    c.dispose();
  });

  test('approval sends lock version and requires server approved state',() async{
    var approved=false;
    final c=api((r) async {
      if(r.method=='GET'){
        return http.Response(jsonEncode(detailed(
          status:approved?'pending':'draft',version:approved?2:1)),200);
      }
      expect(r.url.path,'/api/v1/invoices/31/approve');
      expect((jsonDecode(r.body) as Map)['confirm'],true);
      expect((jsonDecode(r.body) as Map)['lock_version'],1);
      approved=true;
      return http.Response(jsonEncode({'data':{
        'invoice':serverInvoice(status:'pending',version:2),
      }}),200);
    });
    final record=await RemoteInvoiceRepository(api:c)
        .approveInvoice('invoice-31');
    expect(record.lifecycleStatus,'approved');
    expect(record.status,InvoiceStatus.pending);
    expect(record.lockVersion,2);
    c.dispose();
  });

  test('full manual receipt does not call an online payment provider',() async{
    var paid=false;
    final c=api((r) async {
      if(r.method=='GET'){
        final row=serverInvoice(status:paid?'paid':'pending',
          version:paid?2:1);
        row['received_minor']=paid?27025:0;
        row['amount_due_minor']=paid?0:27025;
        return http.Response(jsonEncode({'data':{
          'invoice':row,
          'items':detailed()['data']['items'],
          'payments':paid?[{
            'id':91,'amount_minor':27025,'paid_at':'2026-11-05',
            'method':'other','status':'paid',
          }]:[],
          'history':[],'attachments':[],
        }}),200);
      }
      expect(r.url.path,'/api/v1/invoices/31/payments');
      final request=jsonDecode(r.body) as Map<String,dynamic>;
      expect(request['confirm'],true);
      expect(request['amount'],'270.25');
      expect(request['method'],'other');
      expect(request['request_key'],'invoice-paid-31-27025-0');
      paid=true;
      return http.Response(jsonEncode({'data':{
        'invoice':serverInvoice(status:'paid',version:2),
      }}),201);
    });
    final updated=await RemoteInvoiceRepository(api:c)
        .markAsPaid('invoice-31');
    expect(updated.status,InvoiceStatus.paid);
    expect(updated.receivedMinor,27025);
    expect(updated.amountDueMinor,0);
    c.dispose();
  });

  test('a voided manual payment can be recorded again without replaying the old key',
      () async {
    var paymentRecorded=false,historyVersion=0;
    final keys=<String>[];
    final c=api((r) async {
      if(r.method=='GET'){
        final row=serverInvoice(
          status:paymentRecorded?'paid':'pending',version:2);
        return http.Response(jsonEncode({'data':{
          'invoice':row,'items':detailed()['data']['items'],
          'payments':paymentRecorded?[{
            'id':92,'amount_minor':27025,'paid_at':'2026-11-05',
            'method':'other','status':'paid',
          }]:[],
          'history':[
            for(var i=0;i<historyVersion;i++)
              {'id':i+1,'type':'payment_voided',
               'created_at':'2026-11-05T12:00:00Z'},
          ],
          'attachments':[],
        }}),200);
      }
      final body=jsonDecode(r.body) as Map<String,dynamic>;
      keys.add(body['request_key'] as String);
      paymentRecorded=true;
      return http.Response(jsonEncode({'data':{
        'invoice':serverInvoice(status:'paid',version:2),
      }}),201);
    });
    final repo=RemoteInvoiceRepository(api:c);
    await repo.markAsPaid('invoice-31');
    paymentRecorded=false;
    historyVersion=2; // Payment recorded then voided in server audit.
    await repo.markAsPaid('invoice-31');
    expect(keys,[
      'invoice-paid-31-27025-0',
      'invoice-paid-31-27025-2',
    ]);
    c.dispose();
  });

  test('deposit candidates reject mismatched aggregate totals',() async {
    final c=api((r) async=>http.Response(jsonEncode({'data':{
      'job_id':34,'currency':'CHF','available_minor':15000,
      'deposit_candidates':[{'id':5,'amount_minor':10000}],
      'allocation_policy':'whole_deposits_once',
    }}),200));
    await expectLater(
      RemoteInvoiceRepository(api:c).availableDepositCandidates(34),
      throwsA(isA<SignApiException>()),
    );
    c.dispose();
  });

  test('only unallocated received money qualifies for invoice credit',() async{
    final c=api((r) async {
      expect(r.url.path,'/api/v1/jobs/34/invoice-deposits');
      return http.Response(jsonEncode({'data':{
        'job_id':34,'currency':'CHF','available_minor':10000,
        'deposit_ids':[5],
        'deposit_candidates':[{'id':5,'amount_minor':10000}],
        'allocation_policy':'whole_deposits_once',
      }}),200);
    });
    expect(await RemoteInvoiceRepository(api:c).availableDeposits(34),10000);
    expect(await RemoteInvoiceRepository(api:c).availableDepositCandidates(34),[10000]);
    c.dispose();
  });
}
