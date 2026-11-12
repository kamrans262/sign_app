import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:sign2digital/core/widgets/sign2digital_primary_button.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sign2digital/core/services/active_company_session.dart';
import 'package:sign2digital/core/services/sign_api_client.dart';
import 'package:sign2digital/features/equipment/data/remote_equipment_loan_repository.dart';
import 'package:sign2digital/features/equipment/domain/equipment_loan_record.dart';
import 'package:sign2digital/features/equipment/presentation/screens/equipment_loan_reminder_actions.dart';

Map<String,dynamic> preview({
  int loanVersion=1,
  bool sendAvailable=true,
  bool automatic=false,
  bool transportReady=true,
  List<Map<String,dynamic>> history=const [],
})=>{
  'loan_id':22,'loan_version':loanVersion,'status':'overdue',
  'borrower_name':'Borrower Smith',
  'borrower_email':'borrower@example.test',
  'equipment_name':'Mini Excavator','expected_return_date':'2026-10-05',
  'transport_ready':transportReady,
  'send_available':sendAvailable,
  'automatic_enabled':automatic,
  'recipient_confirmed':automatic,
  'frequency_days':7,'automatic_global_enabled':false,
  'not_available_reason':sendAvailable?null:'Outbound mail not configured.',
  'delivery_history':history,
};

EquipmentLoanRecord loan({EquipmentLoanStatus status=EquipmentLoanStatus.overdue})=>
  EquipmentLoanRecord(
    id:22,companyId:7,assetId:10,
    equipmentCode:'EX-100',equipmentName:'Mini Excavator',
    borrowerName:'Borrower Smith',borrowerEmail:'borrower@example.test',
    loanDate:DateTime(2026,10,1),
    expectedReturnDate:DateTime(2026,10,5),status:status,
  );

SignApiClient client(Future<http.Response> Function(http.Request) response)=>
  SignApiClient(baseUrl:Uri.parse('https://m19-stage2.test'),
    tokenProvider:() async=>'m19-stage2-test-token',
    activeCompanyId:()=>ActiveCompanySession.companyId,
    httpClient:MockClient(response));

void main(){
  setUp(()=>ActiveCompanySession.set(7));
  tearDown(ActiveCompanySession.clear);

  test('preview and delivery state remain server-authoritative',() async{
    final api=client((request) async{
      expect(request.method,'GET');
      expect(request.headers['X-Company-Id'],'7');
      expect(request.url.path,
        '/api/v1/equipment-loans/22/reminders/preview');
      return http.Response(jsonEncode({'data':preview(
        history:[{
          'id':49,'kind':'manual','due_date':'2026-10-05',
          'status':'submitted','attempt_count':1,
          'created_at':'2026-11-05T14:00:00Z',
          'delivery_note':'Transport accepted, inbox unconfirmed.',
        }],
      )}),200);
    });
    final p=await RemoteEquipmentLoanRepository(api:api).reminderPreview(22);
    expect(p.loanId,22);
    expect(p.sendAvailable,true);
    expect(p.deliveryHistory.single.status,'submitted');
    expect(p.deliveryHistory.single.attemptCount,1);
    api.dispose();
  });

  test('manual send requires version, request key and explicit flags',() async{
    final api=client((request) async{
      expect(request.method,'POST');
      expect(request.url.path,
        '/api/v1/equipment-loans/22/reminders/send');
      final body=jsonDecode(request.body) as Map;
      expect(body['lock_version'],4);
      expect(body['confirm'],true);
      expect(body['recipient_confirmed'],true);
      expect(body['request_key'],'m19-review-key-001');
      return http.Response(jsonEncode({'data':{'reminder':{
        'id':61,'kind':'manual','status':'submitted',
        'loan_version':4,'attempt_count':1,
        'delivery_note':'Inbox delivery not confirmed.',
      }}}),200);
    });
    final result=await RemoteEquipmentLoanRepository(api:api).sendReminder(
      22,lockVersion:4,requestKey:'m19-review-key-001');
    expect(result.status,'submitted');
    expect(result.deliveryNote,contains('not confirmed'));
    api.dispose();
  });

  test('policy update only uses server loan version and company ID',() async{
    final api=client((request) async{
      expect(request.method,'PUT');
      expect(request.url.path,
        '/api/v1/equipment-loans/22/reminders/policy');
      final body=jsonDecode(request.body) as Map;
      expect(body['lock_version'],1);
      expect(body['automatic_enabled'],true);
      expect(body['recipient_confirmed'],true);
      expect(body['frequency_days'],7);
      return http.Response(jsonEncode({'data':preview(
        loanVersion:2,automatic:true)}),200);
    });
    final p=await RemoteEquipmentLoanRepository(api:api)
      .updateReminderPolicy(22,lockVersion:1,enabled:true,
        recipientConfirmed:true);
    expect(p.automaticEnabled,true);
    expect(p.loanVersion,2);
    api.dispose();
  });

  test('changing active company rejects stale in-flight preview',() async{
    final pending=Completer<http.Response>();
    final api=client((request)=>pending.future);
    final future=RemoteEquipmentLoanRepository(api:api).reminderPreview(22);
    await Future<void>.delayed(Duration.zero);
    ActiveCompanySession.set(8);
    pending.complete(http.Response(jsonEncode({'data':preview()}),200));
    await expectLater(future,throwsA(isA<SignApiException>()));
    api.dispose();
  });

  testWidgets('no configured transport never enables send button',(tester) async{
    var sends=0;
    final api=client((request) async{
      if(request.method=='POST')sends++;
      return http.Response(jsonEncode({'data':preview(
        sendAvailable:false,transportReady:false)}),200);
    });
    await tester.pumpWidget(MaterialApp(
      home:Scaffold(body:SingleChildScrollView(child:
        EquipmentLoanReminderActions(loan:loan(),
          repository:RemoteEquipmentLoanRepository(api:api))))));
    await tester.pumpAndSettle();
    final button=find.byKey(const Key('equipment-reminder-send'));
    expect(button,findsOneWidget);
    expect(find.text('Outbound mail not configured.'),findsOneWidget);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(sends,0);
    api.dispose();
  });

  testWidgets('manual send requires staff confirmation before POST',(tester) async{
    var posted=0;
    final api=client((request) async{
      if(request.method=='GET'){
        return http.Response(jsonEncode({'data':preview()}),200);
      }
      posted++;
      final body=jsonDecode(request.body) as Map;
      expect(body['recipient_confirmed'],true);
      expect(body['confirm'],true);
      return http.Response(jsonEncode({'data':{'reminder':{
        'id':99,'kind':'manual','status':'submitted',
        'attempt_count':1,'delivery_note':'Transport submitted.',
      }}}),200);
    });
    await tester.pumpWidget(MaterialApp(home:Scaffold(
      body:SingleChildScrollView(child:EquipmentLoanReminderActions(
        loan:loan(),repository:RemoteEquipmentLoanRepository(api:api))))));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('equipment-reminder-send')));
    await tester.pumpAndSettle();
    expect(find.text('Send Equipment Return Reminder?'),findsOneWidget);
    final confirm=find.byKey(const Key('equipment-reminder-confirm-send'));
    expect(tester.widget<Sign2DigitalPrimaryButton>(confirm).enabled,isFalse);
    expect(posted,0);
    await tester.tap(find.byKey(const Key('equipment-reminder-consent')));
    await tester.pumpAndSettle();
    expect(tester.widget<Sign2DigitalPrimaryButton>(confirm).enabled,isTrue);
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(posted,1);
    api.dispose();
  });

  testWidgets('opting in requires confirmation and displays server disabled notice',
      (tester) async{
    var saves=0;
    var autoEnabled=false;
    final api=client((request) async{
      if(request.method=='PUT'){
        saves++;
        final data=jsonDecode(request.body) as Map;
        expect(data['automatic_enabled'],true);
        expect(data['recipient_confirmed'],true);
        autoEnabled=true;
      }
      return http.Response(jsonEncode({'data':preview(
        automatic:autoEnabled,loanVersion:autoEnabled?2:1)}),200);
    });
    await tester.pumpWidget(MaterialApp(home:Scaffold(
      body:SingleChildScrollView(child:EquipmentLoanReminderActions(
        loan:loan(),repository:RemoteEquipmentLoanRepository(api:api))))));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('equipment-reminder-policy')));
    await tester.pumpAndSettle();
    expect(saves,0);
    expect(tester.widget<Sign2DigitalPrimaryButton>(
      find.byKey(const Key('equipment-reminder-policy-save'))).enabled,isFalse);
    await tester.tap(find.byKey(const Key('equipment-reminder-policy-confirm')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('equipment-reminder-policy-save')));
    await tester.pumpAndSettle();
    expect(saves,1);
    expect(find.textContaining('Overdue Reminders: On'),findsOneWidget);
    expect(find.text('Automatic sending is disabled on the server.'),
      findsOneWidget);
    api.dispose();
  });

  testWidgets('returned loan shows immutable reminder history without send',
      (tester) async{
    final api=client((request) async=>http.Response(jsonEncode({
      'data':preview(history:[{
        'id':71,'kind':'manual','due_date':'2026-10-05',
        'status':'submitted','attempt_count':1,
        'created_at':'2026-11-05T12:00:00Z',
        'delivery_note':'Inbox delivery was not confirmed.',
      }]),
    }),200));
    await tester.pumpWidget(MaterialApp(home:Scaffold(
      body:SingleChildScrollView(child:EquipmentLoanReminderActions(
        loan:loan(status:EquipmentLoanStatus.returned),
        repository:RemoteEquipmentLoanRepository(api:api))))));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('equipment-reminder-send')),findsNothing);
    expect(find.byKey(const Key('equipment-reminder-delivery-71')),findsOneWidget);
    api.dispose();
  });
}
