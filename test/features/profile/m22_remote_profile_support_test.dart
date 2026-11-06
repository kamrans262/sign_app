import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sign2digital/core/services/sign_api_client.dart';
import 'package:sign2digital/features/profile/data/remote_security_access_repository.dart';
import 'package:sign2digital/features/profile/data/remote_profile_preferences_repository.dart';
import 'package:sign2digital/features/profile/data/remote_support_repository.dart';
import 'package:sign2digital/features/profile/presentation/screens/help_support_screen.dart';

SignApiClient api(Future<http.Response> Function(http.Request) handler) =>
  SignApiClient(
    baseUrl:Uri.parse('https://example.test'),
    tokenProvider:() async=>'test-token',
    httpClient:MockClient(handler),
  );

http.Response success(Map<String,dynamic> data) =>
  http.Response(jsonEncode({'data':data}),200,
    headers:{'content-type':'application/json'});

void main(){
  test('security reads true sessions, does not pretend extra TOTP is enrolled',()async{
    final observed=<String>[];
    final source=RemoteSecurityAccessRepository(api:api((req)async{
      observed.add(req.method+' '+req.url.path);
      expect(req.headers['Authorization'],'Bearer test-token');
      if(req.method=='GET')return success({
        'two_factor_enabled':null,'two_factor_available':false,
        'sessions':[{
          'id':'5','device_name':'iPhone personal',
          'last_used_at':'2026-11-06T02:00:00Z',
          'is_current':true,
        },{
          'id':'6','device_name':'Mac laptop',
          'created_at':'2026-11-05T12:00:00Z',
          'is_current':false,
        }],
      });
      if(req.method=='DELETE'){
        expect(jsonDecode(req.body)['password'],'correct-password');
        return success({'revoked':true});
      }
      if(req.url.path.endsWith('revoke-others')){
        expect(jsonDecode(req.body)['password'],'correct-password');
        return success({'revoked':1});
      }
      if(req.url.path.endsWith('password/change')){
        expect(jsonDecode(req.body)['password_confirmation'],'New!Pass123');
        return success({'requires_login':true});
      }
      throw StateError(req.url.toString());
    }));
    final security=await source.load();
    expect(security.demoOnly,false);
    expect(security.twoFactorEnabled,isNull);
    expect(security.sessions!.length,2);
    expect(security.sessions![0].isCurrent,true);
    expect(security.sessions![0].location,'Location unavailable');
    expect(await source.changeTwoFactor(enable:true,
      confirmationPassword:'correct-password'),false);
    expect(await source.revokeSession(sessionId:'6',
      confirmationPassword:'correct-password'),true);
    expect(await source.revokeOtherSessions(
      confirmationPassword:'correct-password'),true);
    expect(await source.changePassword(
      current:'correct-password',next:'New!Pass123'),true);
    expect(observed.any((x)=>x.contains('DELETE /api/v1/me/sessions/6')),true);
  });

  test('real preferences load/save over authenticated API',()async{
    var saved=false;
    final source=RemoteProfilePreferencesRepository(api:api((req)async{
      if(req.method=='PATCH'){
        saved=true;
        final payload=jsonDecode(req.body) as Map<String,dynamic>;
        expect(payload['language'],'French');
        expect(payload['pushNotifications'],false);
        return success(payload);
      }
      return success({
        'language':'English','dateFormat':'DD/MM/YYYY',
        'timeFormat':'24 hours','timeZone':'Europe/Zurich',
        'pushNotifications':true,'emailNotifications':true,
        'smsNotifications':false,
      });
    }));
    final prefs=await source.load();
    expect(prefs.language,'English');
    await source.save(prefs.copyWith(language:'French',
      pushNotifications:false));
    expect(saved,true);
  });

  test('support FAQ, tickets, create and reply use real user-bound endpoints',()async{
    final touched=<String>[];
    final source=RemoteSupportRepository(api:api((req)async{
      touched.add(req.method+' '+req.url.path);
      if(req.url.path=='/api/v1/support/faqs')
        return success({'records':[{
          'id':1,'category':'general','question':'Where are my invoices?',
          'answer':'Open Invoices.',
        }]});
      if(req.url.path=='/api/v1/support/tickets'&&req.method=='GET')
        return success({'records':[],'pagination':{
          'has_more':false,'page':1,'total':0}});
      if(req.url.path=='/api/v1/support/tickets'&&req.method=='POST'){
        expect(jsonDecode(req.body)['category'],'bug');
        return success({'ticket':{
          'id':4,'reference':'S2D-TEST','subject':'Upload issue',
          'description':'Cannot upload photos','status':'open',
          'category':'bug','created_at':'2026-11-06',
        }});
      }
      if(req.url.path=='/api/v1/support/tickets/4/replies'){
        expect(jsonDecode(req.body)['body'],'More details');
        return success({'ticket':{
          'id':4,'reference':'S2D-TEST','subject':'Upload issue',
          'description':'Cannot upload photos','status':'open',
          'category':'bug','created_at':'2026-11-06',
        },'replies':[{
          'id':7,'author_user_id':2,'body':'More details','created_at':'2026-11-06',
        }]});
      }
      throw StateError(req.url.toString());
    }));
    expect((await source.faqs()).single.question,'Where are my invoices?');
    expect(await source.tickets(),isEmpty);
    final ticket=await source.create(category:'bug',
      subject:'Upload issue',description:'Cannot upload photos');
    expect(ticket.id,4);
    final replied=await source.reply(4,'More details');
    expect(replied.replies.single.body,'More details');
    expect(touched,contains('POST /api/v1/support/tickets'));
  });

  testWidgets('Help & Support renders published FAQ and authenticated tickets',
      (tester)async{
    final source=RemoteSupportRepository(api:api((req)async{
      if(req.url.path.endsWith('/faqs'))return success({'records':[{
        'id':9,'category':'general','question':'How do I contact support?',
        'answer':'Use the ticket form.',
      }]});
      if(req.url.path.endsWith('/tickets'))return success({
        'records':[{
          'id':13,'reference':'S2D-13','subject':'Existing ticket',
          'description':'Issue description','status':'open',
          'category':'bug','created_at':'2026-11-06',
        }],
        'pagination':{'has_more':false,'page':1,'total':1},
      });
      throw StateError(req.url.path);
    }));
    await tester.pumpWidget(MaterialApp(home:HelpSupportScreen(repository:source)));
    await tester.pumpAndSettle();
    expect(find.text('How do I contact support?'),findsOneWidget);
    expect(find.text('My Tickets (1)'),findsOneWidget);
    expect(find.text('Existing ticket'),findsOneWidget);
    expect(find.byKey(const Key('m22-contact-support')),findsOneWidget);
    expect(tester.takeException(),isNull);
  });

  test('private support attachment is listed and downloaded with bearer auth', () async {
    final source = RemoteSupportRepository(api: api((req) async {
      expect(req.headers['Authorization'], 'Bearer test-token');
      if (req.url.path == '/api/v1/support/tickets/4') {
        return success({
          'ticket': {
            'id': 4, 'reference': 'S2D-4', 'subject': 'Attachment test',
            'description': 'Please review', 'status': 'open',
            'category': 'bug', 'created_at': '2026-11-06',
          },
          'replies': <Object>[],
          'attachments': [{
            'id': 8, 'original_name': 'proof.jpg',
            'mime_type': 'image/jpeg', 'byte_size': 4,
          }],
        });
      }
      if (req.url.path == '/api/v1/support/tickets/4/attachments/8') {
        return http.Response.bytes([255, 216, 255, 217], 200,
          headers: {'content-type': 'image/jpeg'});
      }
      throw StateError(req.url.path);
    }));
    final ticket = await source.details(4);
    expect(ticket.attachments.single.originalName, 'proof.jpg');
    final bytes = await source.downloadAttachment(4, ticket.attachments.single);
    expect(bytes, [255, 216, 255, 217]);

  });

  testWidgets('ticket details show private attachments with original name',
      (tester) async {
    final source = RemoteSupportRepository(api: api((req) async =>
      success({
        'ticket': {
          'id': 4, 'reference': 'S2D-4', 'subject': 'Attachment test',
          'description': 'Please review', 'status': 'closed',
          'category': 'bug', 'created_at': '2026-11-06',
        },
        'replies': <Object>[],
        'attachments': [{
          'id': 8, 'original_name': 'proof.jpg',
          'mime_type': 'image/jpeg', 'byte_size': 4,
        }],
      })));
    await tester.pumpWidget(MaterialApp(
      home: SupportTicketDetailsScreen(ticketId: 4, repository: source)));
    await tester.pumpAndSettle();
    expect(find.text('Attachments'), findsOneWidget);
    expect(find.text('proof.jpg'), findsOneWidget);
    expect(find.byKey(const Key('m22-attachment-8')), findsOneWidget);
  });
}
