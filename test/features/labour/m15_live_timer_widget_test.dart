import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sign2digital/core/services/active_company_session.dart';
import 'package:sign2digital/core/services/sign_api_client.dart';
import 'package:sign2digital/features/jobs/domain/job_model.dart';
import 'package:sign2digital/features/labour/data/remote_labour_repository.dart';
import 'package:sign2digital/features/labour/presentation/widgets/m15_live_timer_panel.dart';

void main(){
  setUp(()=>ActiveCompanySession.set(7));
  tearDown(()=>ActiveCompanySession.clear());

  testWidgets('server timer is restored and has Start, Pause, Resume, Stop',
      (tester) async {
    var status='stopped';
    var actions=0;
    var refreshes=0;
    final client=SignApiClient(
      baseUrl:Uri.parse('https://example.test'),
      tokenProvider:() async=>'m15-test',
      activeCompanyId:()=>ActiveCompanySession.companyId,
      httpClient:MockClient((req) async {
        expect(req.headers['Authorization'],'Bearer m15-test');
        expect(req.headers['X-Company-Id'],'7');
        if(req.url.path.endsWith('/timer/current')) {
          refreshes++;
        } else if(req.url.path.contains('/timer/')) {
          actions++;
          final action=req.url.path.split('/').last;
          expect(const ['start','pause','resume','stop'],contains(action));
          final body=jsonDecode(req.body) as Map<String,dynamic>;
          expect((body['request_key'] as String).length,greaterThan(7));
          if(action=='start')expect(body['job_id'],34);
          status=switch(action){
            'start'=>'running','pause'=>'paused',
            'resume'=>'running',_=>'stopped',
          };
        } else {
          throw StateError('Unexpected request: ${req.url.path}');
        }
        return http.Response(jsonEncode({'data':{'timer':{
          'status':status,'job_id':34,'worker_id':52,
          'elapsed_seconds':actions*60,
          'server_now':'2026-11-05T08:00:00Z',
          'lock_version':actions+1,
        }}}),200);
      }),
    );
    final job=JobModel(id:'34',title:'Kitchen',clientId:'3',
      clientName:'Customer',description:'Site work',referenceNumber:'J-34',
      imageAsset:'assets/images/jobs_image.jpg',amountChf:0,
      progressPercentage:0,dueDate:DateTime(2026,11,30),
      stage:JobStage.inProgress,category:JobCategory.active);
    var updates=0;
    await tester.pumpWidget(MaterialApp(
      home:Scaffold(body:SingleChildScrollView(
        child:M15LiveTimerPanel(repository:RemoteLabourRepository(api:client),
          job:job,onUpdated:()=>updates++),
      )),
    ));
    await tester.pump(const Duration(milliseconds:200));
    expect(find.byKey(const Key('m15-timer-start')),findsOneWidget);
    await tester.tap(find.byKey(const Key('m15-timer-start')));
    await tester.pump(const Duration(milliseconds:250));
    expect(find.byKey(const Key('m15-timer-pause')),findsOneWidget);
    await tester.tap(find.byKey(const Key('m15-timer-pause')));
    await tester.pump(const Duration(milliseconds:250));
    expect(find.byKey(const Key('m15-timer-resume')),findsOneWidget);
    await tester.tap(find.byKey(const Key('m15-timer-resume')));
    await tester.pump(const Duration(milliseconds:250));
    expect(find.byKey(const Key('m15-timer-stop')),findsOneWidget);
    await tester.tap(find.byKey(const Key('m15-timer-stop')));
    await tester.pump(const Duration(milliseconds:250));
    expect(find.byKey(const Key('m15-timer-start')),findsOneWidget);
    expect(actions,4);
    expect(updates,4);
    expect(refreshes,greaterThanOrEqualTo(1));
    expect(tester.takeException(),isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    client.dispose();
  });


  testWidgets('company switch ignores a late previous-company timer response',
      (tester) async {
    final oldReply=Completer<http.Response>();
    var sevenRequests=0;
    http.Response timer(String status,int seconds)=>http.Response(
      jsonEncode({'data':{'timer':{
        'status':status,'job_id':34,'worker_id':52,
        'elapsed_seconds':seconds,
        'server_now':'2026-11-05T08:00:00Z',
        'lock_version':2,
      }}}),200,
    );
    final client=SignApiClient(
      baseUrl:Uri.parse('https://example.test'),
      tokenProvider:() async=>'m15-company-test',
      activeCompanyId:()=>ActiveCompanySession.companyId,
      httpClient:MockClient((req) async {
        expect(req.url.path,'/api/v1/labour/timer/current');
        if(req.headers['X-Company-Id']=='7'){
          sevenRequests++;
          if(sevenRequests==2)return oldReply.future;
          return timer('running',180);
        }
        expect(req.headers['X-Company-Id'],'8');
        return timer('stopped',0);
      }),
    );
    await tester.pumpWidget(MaterialApp(home:Scaffold(
      body:M15LiveTimerPanel(repository:RemoteLabourRepository(api:client),
        job:null,onUpdated:(){}),
    )));
    await tester.pump(const Duration(milliseconds:150));
    expect(find.text('Status: RUNNING'),findsOneWidget);
    await tester.tap(find.byKey(const Key('m15-timer-refresh')));
    await tester.pump();
    ActiveCompanySession.set(8);
    // Let the asynchronous token and HTTP pipeline settle before inspecting
    // the new-company server response.
    await tester.pumpAndSettle(const Duration(milliseconds:100));
    expect(find.text('Status: STOPPED'),findsOneWidget);
    expect(find.text('Status: RUNNING'),findsNothing);
    oldReply.complete(timer('running',999));
    await tester.pumpAndSettle(const Duration(milliseconds:100));
    expect(find.text('Status: STOPPED'),findsOneWidget);
    expect(find.byKey(const Key('m15-timer-start')),findsOneWidget);
    ActiveCompanySession.clear();
    await tester.pump();
    expect(find.text('Status: STOPPED'),findsNothing);
    expect(find.text('Select a company before tracking work.'),findsOneWidget);
    expect(tester.takeException(),isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    client.dispose();
  });

}
