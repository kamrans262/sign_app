import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sign2digital/core/services/active_company_session.dart';
import 'package:sign2digital/core/services/sign_api_client.dart';
import 'package:sign2digital/features/documents/data/remote_general_document_repository.dart';
import 'package:sign2digital/features/documents/presentation/screens/general_document_editor_screen.dart';

void main(){
  setUp(()=>ActiveCompanySession.set(7));
  tearDown(()=>ActiveCompanySession.clear());
  SignApiClient api(Future<http.Response> Function(http.Request) callback)=>
    SignApiClient(baseUrl:Uri.parse('https://example.test'),
      tokenProvider:() async=>'m18-widget-test',
      activeCompanyId:()=>ActiveCompanySession.companyId,
      httpClient:MockClient(callback));

  Map<String,dynamic> savedDocument()=>{
    'id':41,'company_id':7,'number':'GD-2026-WIDGET',
    'type':'letter','title':'Business Letter','locale':'en',
    'status':'draft','revision':1,'lock_version':1,
    'client_id':null,'job_id':null,
    'created_at':'2026-11-05T14:00:00Z',
  };
  Map<String,dynamic> detail()=>{'data':{
    'document':savedDocument(),
    'content':{
      'revision':1,'source':'manual',
      'blocks':[{'type':'paragraph','text':'A real business message.',
        'bold':false,'italic':false}],
    },
    'revisions':[],'history':[],'attachments':[],
  }};

  testWidgets('existing-style editor saves a real manual draft',
      (tester) async{
    var saves=0;
    final client=api((request) async{
      if(request.method=='POST'){
        final body=jsonDecode(request.body) as Map;
        expect(body['type'],'letter');
        expect((body['request_key'] as String).startsWith('m18-draft-'),true);
        expect(body['blocks'],[{
          'type':'paragraph','text':'A real business message.',
          'bold':false,'italic':false,
        }]);
        saves++;
        return http.Response(jsonEncode({'data':{
          'document':savedDocument(),
        }}),201);
      }
      expect(request.url.path,'/api/v1/general-documents/41');
      return http.Response(jsonEncode(detail()),200);
    });
    await tester.pumpWidget(MaterialApp(home:
      GeneralDocumentEditorScreen(
        repository:RemoteGeneralDocumentRepository(api:client))));
    await tester.enterText(
      find.byKey(const Key('general-document-title')), 'Business Letter');
    // The scrollable editor builds off-screen inputs lazily.
    await tester.scrollUntilVisible(
      find.byKey(const Key('general-document-text-0')), 200,
      scrollable: find.byType(Scrollable).first);
    await tester.enterText(
      find.byKey(const Key('general-document-text-0')),
      'A real business message.');
    await tester.scrollUntilVisible(
      find.byKey(const Key('general-document-save')), 200,
      scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byKey(const Key('general-document-save')));
    await tester.pumpAndSettle();
    expect(saves,1);
    // The review action is below Save Draft and may be lazily built.
    await tester.scrollUntilVisible(find.text('Mark Reviewed'), 160,
      scrollable: find.byType(Scrollable).first);
    expect(find.text('Mark Reviewed'),findsOneWidget);
    client.dispose();
  });

  testWidgets('failed AI request keeps manual paragraphs intact',
      (tester) async{
    final client=api((request) async=>http.Response(
      jsonEncode({'message':'Provider quota exhausted'}),503));
    await tester.pumpWidget(MaterialApp(home:
      GeneralDocumentEditorScreen(
        repository:RemoteGeneralDocumentRepository(api:client))));
    await tester.scrollUntilVisible(
      find.byKey(const Key('general-document-text-0')), 200,
      scrollable: find.byType(Scrollable).first);
    await tester.enterText(
      find.byKey(const Key('general-document-text-0')),
      'Manual text stays here.');
    await tester.scrollUntilVisible(
      find.byKey(const Key('general-document-instructions')), 200,
      scrollable: find.byType(Scrollable).first);
    await tester.enterText(
      find.byKey(const Key('general-document-instructions')),
      'Suggest a professional document introduction.');
    await tester.scrollUntilVisible(
      find.text('Suggest with AI'), 200,
      scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Suggest with AI'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('general-document-error')),findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('general-document-text-0')), -200,
      scrollable: find.byType(Scrollable).first);
    expect(tester.widget<TextField>(
      find.byKey(const Key('general-document-text-0'))
    ).controller!.text, 'Manual text stays here.');
    client.dispose();
  });
}
