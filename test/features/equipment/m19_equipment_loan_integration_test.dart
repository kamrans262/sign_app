import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sign2digital/core/services/active_company_session.dart';
import 'package:sign2digital/core/services/sign_api_client.dart';
import 'package:sign2digital/features/equipment/data/demo_equipment_repository.dart';
import 'package:sign2digital/features/equipment/data/demo_equipment_loan_repository.dart';
import 'package:sign2digital/features/equipment/data/remote_equipment_repository.dart';
import 'package:sign2digital/features/equipment/data/remote_equipment_loan_repository.dart';
import 'package:sign2digital/features/equipment/domain/equipment_loan_record.dart';
import 'package:sign2digital/features/equipment/presentation/screens/equipment_loans_screen.dart';
import 'package:sign2digital/features/equipment/presentation/screens/equipment_loan_details_screen.dart';
import 'package:sign2digital/features/equipment/presentation/screens/create_equipment_loan_screen.dart';

Map<String,dynamic> asset({int company=7})=>{
  'id':10,'company_id':company,'code':'EX-100','name':'Mini Excavator',
  'category':'Excavation','brand':'Kubota','model':'U27',
  'purchase_date':'2026-02-01','status':'available',
  'initial_hours':245,'hours':245,'location':'Warehouse',
  'notes':'','lock_version':1,
  'current_loan_id':null,
  'usage':[],'maintenance':[],'history':[],'photos':[],
  'created_at':'2026-09-01T10:00:00Z',
};

Map<String,dynamic> loan({String status='overdue',int company=7})=>{
  'id':22,'company_id':company,'equipment_asset_id':10,
  'equipment_code':'EX-100','equipment_name':'Mini Excavator',
  'borrower_type':'external','borrower_name':'Borrower Smith',
  'borrower_email':'borrower@example.test',
  'client_id':null,'job_id':null,
  'loan_date':'2026-09-01','expected_return_date':'2026-09-04',
  'status':status,'stored_status':'active',
  'actual_return_date':null,'notes':'', 'lock_version':1,
};

SignApiClient api(Future<http.Response> Function(http.Request) handler)=>
  SignApiClient(baseUrl:Uri.parse('https://example.test'),
    tokenProvider:() async=>'m19-test-auth',
    activeCompanyId:()=>ActiveCompanySession.companyId,
    httpClient:MockClient(handler));

void main(){
  setUp((){
    ActiveCompanySession.set(7);
    DemoEquipmentLoanRepository.resetForTests();
    DemoEquipmentRepository.resetForTests();
  });
  tearDown(ActiveCompanySession.clear);

  test('authenticated equipment list has no demo records and tenant proof',() async{
    final client=api((request) async{
      expect(request.headers['X-Company-Id'],'7');
      expect(request.url.path,'/api/v1/equipment');
      return http.Response(jsonEncode({'data':{
        'records':[asset()],'page':1,'last_page':1,'total':1,
      }}),200);
    });
    final records=await RemoteEquipmentRepository(api:client).listEquipment();
    expect(records.length,1);
    expect(records.first.id,'EX-100');
    expect(records.first.demoOnly,false);
    expect(records.first.serverId,10);
    expect(records.first.currentLoanId,isNull);
    client.dispose();
  });

  test('foreign-company asset response fails closed',() async{
    final client=api((request) async=>http.Response(jsonEncode({'data':{
      'records':[asset(company:8)],'page':1,'last_page':1,
    }}),200));
    await expectLater(RemoteEquipmentRepository(api:client).listEquipment(),
      throwsA(isA<SignApiException>()));
    client.dispose();
  });

  test('company switching during equipment request discards stale data',() async{
    final pending=Completer<http.Response>();
    final client=api((request)=>pending.future);
    final future=RemoteEquipmentRepository(api:client).listEquipment();
    await Future<void>.delayed(Duration.zero);
    ActiveCompanySession.set(8);
    pending.complete(http.Response(jsonEncode({'data':{
      'records':[asset()], 'page':1,'last_page':1,
    }}),200));
    await expectLater(future,throwsA(isA<SignApiException>()));
    client.dispose();
  });

  test('loan listing validates status and tenant; extend sends lock version',() async{
    var extendCount=0;
    final client=api((request) async{
      if(request.url.path=='/api/v1/equipment-loans'){
        return http.Response(jsonEncode({'data':{
          'records':[loan()],'page':1,'last_page':1,
        }}),200);
      }
      if(request.url.path.endsWith('/extend')){
        extendCount++;
        expect(request.method,'POST');
        final body=jsonDecode(request.body) as Map;
        expect(body['lock_version'],1);
        expect(body['confirm'],true);
        expect(body['expected_return_date'],'2027-04-05');
        return http.Response(jsonEncode({'data':{
          'loan':{...loan(status:'active'),
            'lock_version':2,'expected_return_date':'2027-04-05'},
        }}),200);
      }
      if(request.url.path=='/api/v1/equipment-loans/22'){
        return http.Response(jsonEncode({'data':{
          'loan':{...loan(status:'active'),'lock_version':2,
            'expected_return_date':'2027-04-05'},
          'history':[
            {'id':1,'type':'created','actor_id':1,
             'created_at':'2026-09-01T10:00:00Z','metadata':{}},
            {'id':2,'type':'return_date_extended','actor_id':1,
             'created_at':'2026-11-05T10:00:00Z',
             'metadata':{'old_date':'2026-09-04',
               'new_date':'2027-04-05'}},
          ],
        }}),200);
      }
      throw StateError('Unexpected route');
    });
    final repo=RemoteEquipmentLoanRepository(api:client);
    final records=await repo.listLoans();
    expect(records.single.status,EquipmentLoanStatus.overdue);
    final extended=await repo.extend(22,1,DateTime(2027,4,5));
    expect(extendCount,1);
    expect(extended.status,EquipmentLoanStatus.active);
    expect(extended.lockVersion,2);
    expect(extended.events.length,2);
    client.dispose();
  });

  test('loan creation never invents borrower or returned status',() async{
    final client=api((request) async{
      final body=jsonDecode(request.body) as Map;
      expect(body['borrower_name'],'Borrower Smith');
      expect(body['equipment_asset_id'],10);
      expect(body['request_key'],'m19-stable-test-key');
      return http.Response(jsonEncode({'data':{'loan':loan(status:'active')}}),201);
    });
    final repository=RemoteEquipmentLoanRepository(api:client);
    final draft=EquipmentLoanRecord(
      assetId:10,equipmentCode:'EX-100',equipmentName:'Mini Excavator',
      borrowerName:'Borrower Smith',
      loanDate:DateTime(2026,9,1),expectedReturnDate:DateTime(2027,9,4),
      requestKey:'m19-stable-test-key',
    );
    expect((await repository.createLoan(draft)).status,EquipmentLoanStatus.active);
    client.dispose();
  });

  testWidgets('loan list uses existing cards and three lifecycle tabs',(tester) async{
    const repository=DemoEquipmentLoanRepository();
    await repository.createLoan(EquipmentLoanRecord(
      assetId:1,equipmentCode:'EQP-0001',
      equipmentName:'Mini Excavator',borrowerName:'Preview Borrower',
      loanDate:DateTime(2026,1,1),
      expectedReturnDate:DateTime(2027,1,1)));
    await tester.pumpWidget(const MaterialApp(
      home:EquipmentLoansScreen(repository:repository)));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('equipment-loan-card-1')),findsOneWidget);
    expect(find.byKey(const Key('equipment-loans-create')),findsOneWidget);
    await tester.tap(find.byKey(const Key('details-tab-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('equipment-loans-empty')),findsOneWidget);
    await tester.tap(find.byKey(const Key('details-tab-2')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('equipment-loans-empty')),findsOneWidget);
  });

  testWidgets('new loan form saves actual borrower and equipment',(tester) async{
    const loans=DemoEquipmentLoanRepository();
    await tester.pumpWidget(const MaterialApp(home:CreateEquipmentLoanScreen(
      repository:loans,equipmentRepository:DemoEquipmentRepository())));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('equipment-loan-pick-asset')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('equipment-loan-asset-EQP-0001')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(
      const Key('equipment-loan-borrower-name')),'Independent Borrower');
    await tester.scrollUntilVisible(
      find.byKey(const Key('equipment-loan-save')),180,
      scrollable:find.byType(Scrollable).first);
    await tester.tap(find.byKey(const Key('equipment-loan-save')));
    await tester.pumpAndSettle();
    final records=await loans.listLoans();
    expect(records.length,1);
    expect(records.single.borrowerName,'Independent Borrower');
    expect(records.single.assetId,1);
  });

  testWidgets('loan detail keeps history and uses return confirmation',(tester) async{
    const repository=DemoEquipmentLoanRepository();
    final record=await repository.createLoan(EquipmentLoanRecord(
      assetId:1,equipmentCode:'EQP-0001',
      equipmentName:'Mini Excavator',borrowerName:'Borrower Doe',
      loanDate:DateTime(2026,2,1),
      expectedReturnDate:DateTime(2027,5,1)));
    await tester.pumpWidget(MaterialApp(
      home:EquipmentLoanDetailsScreen(loan:record,repository:repository)));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('equipment-loan-information')),findsOneWidget);
    expect(find.byKey(const Key('equipment-loan-detail-status')),findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('equipment-loan-return-action')),180,
      scrollable:find.byType(Scrollable).first);
    await tester.tap(find.byKey(const Key('equipment-loan-return-action')));
    await tester.pumpAndSettle();
    // Date picker deliberately requires explicit staff confirmation.
    expect(find.byType(DatePickerDialog),findsOneWidget);
  });
}
