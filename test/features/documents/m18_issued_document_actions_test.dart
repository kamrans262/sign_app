import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sign2digital/core/services/active_company_session.dart';
import 'package:sign2digital/core/services/sign_api_client.dart';
import 'package:sign2digital/features/documents/data/remote_general_document_repository.dart';
import 'package:sign2digital/features/documents/presentation/screens/general_document_issued_actions.dart';

Map<String,dynamic> issue()=>{
  'document_id':41,'revision':1,'sha256':'a'*64,
  'byte_size':1024,'issued_at':'2026-11-05T14:00:00Z',
};
Map<String,dynamic> metadata()=>{'data':{
  'issue':issue(),'signatures':[],'deliveries':[],'links':[],
}};

void main(){
  setUp(()=>ActiveCompanySession.set(7));
  tearDown(()=>ActiveCompanySession.clear());
  SignApiClient api(Future<http.Response> Function(http.Request) callback)=>
    SignApiClient(baseUrl:Uri.parse('https://example.test'),
      tokenProvider:() async=>'m18-widget-auth',
      activeCompanyId:()=>ActiveCompanySession.companyId,
      httpClient:MockClient(callback));

  testWidgets('unissued approved document needs explicit issue confirmation',
      (tester) async{
    var wasIssued=false,postCount=0;
    final client=api((request) async{
      if(request.method=='POST'){
        expect(request.url.path,'/api/v1/general-documents/41/issue');
        postCount++;wasIssued=true;
        return http.Response(jsonEncode({'data':issue()}),200);
      }
      return wasIssued
        ?http.Response(jsonEncode(metadata()),200)
        :http.Response(jsonEncode({'message':'not issued'}),404);
    });
    await tester.pumpWidget(MaterialApp(
      home:Scaffold(body:SingleChildScrollView(
        child:GeneralDocumentIssuedActions(documentId:41,
          documentNumber:'GD-2026-TEST',
          repository:RemoteGeneralDocumentRepository(api:client))))));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('general-document-issue')),findsOneWidget);
    expect(postCount,0);
    await tester.tap(find.byKey(const Key('general-document-issue')));
    await tester.pumpAndSettle();
    expect(find.text('Issue Official Document'),findsOneWidget);
    expect(postCount,0);
    await tester.tap(find.text('Issue PDF'));
    await tester.pumpAndSettle();
    expect(postCount,1);
    expect(find.byKey(const Key('general-document-download')),findsOneWidget);
    client.dispose();
  });

  testWidgets('issue failure never fabricates official document', (tester) async{
    final client=api((request) async{
      if(request.method=='POST'){
        return http.Response(jsonEncode({'message':'not approved'}),409);
      }
      return http.Response(jsonEncode({'message':'not issued'}),404);
    });
    await tester.pumpWidget(MaterialApp(
      home:Scaffold(body:SingleChildScrollView(
        child:GeneralDocumentIssuedActions(documentId:41,
          documentNumber:'GD-2026-TEST',
          repository:RemoteGeneralDocumentRepository(api:client))))));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('general-document-issue')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Issue PDF'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('general-document-issue-error')),findsOneWidget);
    expect(find.byKey(const Key('general-document-download')),findsNothing);
    client.dispose();
  });
}
