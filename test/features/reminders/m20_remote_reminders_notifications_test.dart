import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sign2digital/core/services/active_company_session.dart';
import 'package:sign2digital/core/services/sign_api_client.dart';
import 'package:sign2digital/features/reminders/data/remote_reminder_repository.dart';
import 'package:sign2digital/features/reminders/data/remote_notification_repository.dart';
import 'package:sign2digital/features/reminders/domain/reminder_record.dart';

SignApiClient api(Future<http.Response> Function(http.Request) respond) =>
  SignApiClient(baseUrl:Uri.parse('https://m20-stage1.test'),
    tokenProvider:() async=>'test-token',
    activeCompanyId:()=>ActiveCompanySession.companyId,
    httpClient:MockClient(respond));

Map<String,dynamic> row({int id=11,int company=7,int version=1}) => {
  'id':id,'company_id':company,'owner_user_id':42,
  'title':'Real follow-up','type':'other','notes':'Private only',
  'due_at':'2026-11-10 12:00:00','created_at':'2026-11-05 13:00:00',
  'send_notification':true,'status':'active',
  'completed_at':null,'lock_version':version,
};

void main() {
  setUp(() => ActiveCompanySession.set(7));
  tearDown(ActiveCompanySession.clear);

  test('M20 signed-in reminder listing uses company authenticated API', () async {
    final client=api((request) async {
      expect(request.method,'GET');
      expect(request.url.path,'/api/v1/reminders');
      expect(request.headers['X-Company-Id'],'7');
      expect(request.headers['Authorization'],'Bearer test-token');
      return http.Response(jsonEncode({'data':{
        'records':[row()], 'page':1,'last_page':1,'total':1,
      }}),200);
    });
    final records=await RemoteReminderRepository(api:client).listReminders();
    expect(records,singleton);
    expect(records.single.demoOnly,isFalse);
    expect(records.single.id,'11');
    expect(records.single.lockVersion,1);
    expect(records.single.notes,'Private only');
    client.dispose();
  });

  test('M20 write saves to backend, never session local demo', () async {
    final client=api((request) async {
      expect(request.url.path,'/api/v1/reminders');
      expect(request.method,'POST');
      final body=jsonDecode(request.body) as Map;
      expect(body['title'],'New follow-up');
      expect(body['send_notification'],false);
      expect(body['notes'],'Confidential');
      return http.Response(jsonEncode({'data':{'reminder':row()}}),201);
    });
    final created=await RemoteReminderRepository(api:client).saveReminder(
      ReminderRecord(id:'reminder-local-20261105',title:'New follow-up',
        type:ReminderType.other,
        remindAt:DateTime(2026,11,10,12),
        notes:'Confidential',sendNotification:false));
    expect(created.id,'11');
    expect(created.demoOnly,isFalse);
    client.dispose();
  });

  test('M20 foreign company reminder is rejected before rendering', () async {
    final client=api((request) async =>http.Response(jsonEncode({'data':{
      'records':[row(company:999)],'page':1,'last_page':1,
    }}),200));
    await expectLater(RemoteReminderRepository(api:client).listReminders(),
      throwsA(isA<SignApiException>()));
    client.dispose();
  });

  test('M20 inbox is real, unread scoped, and action endpoints authenticated', () async {
    final calls=<String>[];
    final client=api((request) async {
      calls.add(request.method+' '+request.url.path);
      expect(request.headers['X-Company-Id'],'7');
      if (request.method=='GET') return http.Response(jsonEncode({'data':{
        'records':[{
          'id':54,'company_id':7,'recipient_user_id':42,
          'title':'Client-provided title','body':'Client-provided message',
          'read_at':null,'created_at':'2026-11-05T13:00:00Z',
          'link_type':'reminder','link_id':11,
        }],
        'unread_count':1,'page':1,'last_page':1,
      }}),200);
      return http.Response(jsonEncode({'data':{'updated':true}}),200);
    });
    final inbox=RemoteNotificationRepository(api:client);
    final snapshot=await inbox.list();
    expect(snapshot.unreadCount,1);
    expect(snapshot.records.single.title,'Client-provided title');
    await inbox.markRead(54);
    await inbox.markAllRead();
    await inbox.dismiss(54);
    expect(calls,[
      'GET /api/v1/notifications',
      'POST /api/v1/notifications/54/read',
      'POST /api/v1/notifications/read-all',
      'DELETE /api/v1/notifications/54',
    ]);
    client.dispose();
  });
}