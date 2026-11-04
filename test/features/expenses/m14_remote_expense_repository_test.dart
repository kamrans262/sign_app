import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sign2digital/core/services/active_company_session.dart';
import 'package:sign2digital/core/services/sign_api_client.dart';
import 'package:sign2digital/features/expenses/data/remote_expense_repository.dart';
import 'package:sign2digital/features/expenses/domain/expense_record.dart';

Map<String,dynamic> expense({int company=7,int version=1,
  String status='to_review'}) => {
  'id':21,'company_id':company,'job_id':34,'job':'Kitchen',
  'client_name':'Example Client','category':'material',
  'supplier':'Shop','description':'Door bolts','expense_date':'2026-11-05',
  'amount_minor':1234,'currency':'CHF','status':status,
  'tags':['hardware'],'lock_version':version,
  'approved_at':null,'approved_by':null,
  'reimbursement_requested_at':null,
  'updated_at':'2026-11-05T11:00:00Z',
};

void main() {
  setUp(()=>ActiveCompanySession.set(7));
  tearDown(()=>ActiveCompanySession.clear());

  SignApiClient api(Future<http.Response> Function(http.Request) callback) =>
      SignApiClient(
        baseUrl:Uri.parse('https://example.test'),
        tokenProvider:() async=>'m14-test-token',
        activeCompanyId:()=>ActiveCompanySession.companyId,
        httpClient:MockClient(callback),
      );

  test('list is authenticated and amounts are exact CHF cents',() async {
    final client=api((req) async {
      expect(req.headers['Authorization'],'Bearer m14-test-token');
      expect(req.headers['X-Company-Id'],'7');
      expect(req.url.path,'/api/v1/expenses');
      return http.Response(jsonEncode({'data':{
        'records':[expense()],'page':1,'last_page':1,
      }}),200);
    });
    final list=await RemoteExpenseRepository(api:client).listExpenses();
    expect(list.single.demoOnly,false);
    expect(list.single.id,'expense-21');
    expect(list.single.amount,12.34);
    expect(list.single.supplier,'Shop');
    expect(list.single.status,ExpenseStatus.toReview);
    client.dispose();
  });

  test('cross company response is rejected on the client',() async {
    final client=api((req) async=>http.Response(jsonEncode({'data':{
      'records':[expense(company:8)],'page':1,'last_page':1,
    }}),200));
    await expectLater(RemoteExpenseRepository(api:client).listExpenses(),
        throwsA(isA<SignApiException>()));
    client.dispose();
  });

  test('saving a manual draft uses server amount and tenant',() async {
    final client=api((req) async {
      expect(req.method,'POST');
      expect(req.url.path,'/api/v1/expenses');
      final data=jsonDecode(req.body) as Map<String,dynamic>;
      expect(data['amount'],'12.34');
      expect(data['supplier'],'Shop');
      expect(data['job_id'],34);
      return http.Response(jsonEncode({'data':{'expense':expense()}}),201);
    });
    await RemoteExpenseRepository(api:client).saveDraft(ExpenseRecord(
      id:'local-expense-1',jobId:'34',job:'Kitchen',report:'',
      category:ExpenseCategory.material,title:'Material',
      amount:12.34,date:DateTime(2026,11,5),
      status:ExpenseStatus.toReview,supplier:'Shop',
    ));
    client.dispose();
  });

  test('verified private receipt can be loaded with its SHA256',() async {
    final bytes=Uint8List.fromList([137,80,78,71,13,10,26,10,0,0,0,0]);
    final digest=sha256.convert(bytes).toString();
    final client=api((req) async {
      if(req.url.path.endsWith('/receipts/41')) {
        expect(req.headers['Authorization'],'Bearer m14-test-token');
        return http.Response.bytes(bytes,200,headers:{
          'content-type':'image/png',
        });
      }
      return http.Response(jsonEncode({'data':{
        'expense':expense(),
        'history':[{'id':1,'type':'created',
          'created_at':'2026-11-05T11:00:00Z','actor_id':1}],
        'receipts':[{'id':41,'name':'receipt.png','mime_type':'image/png',
          'sha256':digest,'byte_size':bytes.length}],
      }}),200);
    });
    final loaded=await RemoteExpenseRepository(api:client)
        .getExpense('expense-21');
    expect(loaded.photos.single.bytes,bytes);
    expect(loaded.photos.single.sourceKey,'remote-receipt-41');
    expect(loaded.history.single.title,'created');
    client.dispose();
  });

  test('invalid receipt digest fails closed',() async {
    final bytes=Uint8List.fromList([137,80,78,71,13,10,26,10,0,0]);
    final client=api((req) async {
      if(req.url.path.endsWith('/receipts/41')) {
        return http.Response.bytes(bytes,200,headers:{
          'content-type':'image/png',
        });
      }
      return http.Response(jsonEncode({'data':{
        'expense':expense(),
        'history':[],
        'receipts':[{'id':41,'name':'receipt.png','mime_type':'image/png',
          'sha256':'0'*64,'byte_size':bytes.length}],
      }}),200);
    });
    await expectLater(RemoteExpenseRepository(api:client)
      .getExpense('expense-21'),throwsA(isA<SignApiException>()));
    client.dispose();
  });
}
