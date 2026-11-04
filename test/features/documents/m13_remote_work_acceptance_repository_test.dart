import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sign2digital/core/services/active_company_session.dart';
import 'package:sign2digital/core/services/sign_api_client.dart';
import 'package:sign2digital/features/documents/data/remote_work_acceptance_repository.dart';
import 'package:sign2digital/features/documents/domain/document_record.dart';
import 'package:sign2digital/features/documents/domain/work_acceptance_data.dart';

Map<String,dynamic> acceptance({String status='draft',int company=7,
  String? digest,int? managed}) => {
  'id':21,'company_id':company,'job_id':34,'client_id':6,
  'number':'WA-00000021','completed_work':'Windows repaired',
  'completion_date':'2026-11-04','cleaning_status':'cleaned',
  'status':status,'revision':2,'project':'Window Repair',
  'customer':'Jean Customer','created_at':'2026-11-04T12:00:00Z',
  'updated_at':'2026-11-04T12:00:00Z','outstanding_issues':'Handle loose',
  'remedial_work':'Replace handle','photo_ids':<int>[],
  'has_signed_pdf':managed!=null,'managed_document_id':managed,
  'signed_pdf_sha256':digest,
  'approved_pdf_sha256':digest,
  'acceptance_result':managed!=null?status:null,
  'signed_at':managed!=null?'2026-11-04T15:00:00Z':null,
  'customer_reservation':managed!=null?'Handle pending':null,
  'customer_rating':managed!=null?4:null,
};

void main() {
  setUp(()=>ActiveCompanySession.set(7));
  tearDown(()=>ActiveCompanySession.clear());

  SignApiClient client(Future<http.Response> Function(http.Request) response) =>
      SignApiClient(
        baseUrl:Uri.parse('https://api.test'),
        tokenProvider:() async=>'m13-test-token',
        activeCompanyId:()=>ActiveCompanySession.companyId,
        httpClient:MockClient(response),
      );

  test('list is authenticated, company scoped and preserves status',() async {
    final api=client((req) async {
      expect(req.headers['Authorization'],'Bearer m13-test-token');
      expect(req.headers['X-Company-Id'],'7');
      expect(req.url.path,'/api/v1/work-acceptances');
      return http.Response(jsonEncode({'data':{
        'records':[acceptance()],'last_page':1,'page':1,
      }}),200);
    });
    final records=await RemoteWorkAcceptanceRepository(api:api).listDocuments();
    expect(records.single.id,'acceptance-21');
    expect(records.single.reportKind,ReportKind.workAcceptance);
    expect(records.single.demoOnly,false);
    api.dispose();
  });

  test('cross-company data are rejected even if endpoint responds 200',() async {
    final api=client((req) async=>http.Response(jsonEncode({'data':{
      'records':[acceptance(company:8)],'last_page':1,
    }}),200));
    await expectLater(RemoteWorkAcceptanceRepository(api:api).listDocuments(),
        throwsA(isA<SignApiException>()));
    api.dispose();
  });

  test('draft edit transmits the expected revision and original job',() async {
    final api=client((req) async {
      expect(req.method,'PATCH');
      expect(req.url.path,'/api/v1/work-acceptances/21');
      final data=jsonDecode(req.body) as Map<String,dynamic>;
      expect(data['revision'],2);
      expect(data['job_id'],34);
      expect(data['completed_work'],'Windows completed');
      return http.Response(jsonEncode({'data':{'acceptance':acceptance()}}),200);
    });
    final draft=WorkAcceptanceDraft(
      id:21,revision:2,jobId:'34',completedWork:'Windows completed',
      completionDate:DateTime(2026,11,4),cleaningStatus:'cleaned',
    );
    final saved=await RemoteWorkAcceptanceRepository(api:api).saveDraft(draft);
    expect(saved.id,'acceptance-21');
    api.dispose();
  });

  test('approval requires explicit user intent and exact revision',() async {
    final api=client((req) async {
      expect(req.method,'POST');
      expect(req.url.path,'/api/v1/work-acceptances/21/approve');
      expect(jsonDecode(req.body),{'revision':2,'confirm':true});
      return http.Response(jsonEncode({'data':{
        'acceptance':acceptance(status:'approved'),
      }}),200);
    });
    final record=DocumentRecord(
      id:'acceptance-21',category:DocumentCategory.reports,
      number:'WA-00000021',title:'Window Repair',
      project:'Window Repair',customer:'Jean Customer',
      timestamp:DateTime(2026,11,4),
      status:'draft',version:2,reportKind:ReportKind.workAcceptance,
    );
    final approved=await RemoteWorkAcceptanceRepository(api:api).approve(record);
    expect(approved.status,'approved');
    api.dispose();
  });

  test('verified signed PDF and customer reservations load from real audit',() async {
    final pdf=Uint8List.fromList('%PDF-1.4\n1 0 obj\nendobj\n%%EOF'.codeUnits);
    final digest=sha256.convert(pdf).toString();
    final png=Uint8List.fromList([
      137,80,78,71,13,10,26,10,0,1,2,3,4,5,6,7,
    ]);
    final api=client((req) async {
      if(req.url.path.endsWith('/pdf/signed')) {
        return http.Response.bytes(pdf,200,headers:{
          'content-type':'application/pdf',
        });
      }
      if(req.url.path.endsWith('/signature')) {
        return http.Response.bytes(png,200,headers:{
          'content-type':'image/png',
        });
      }
      return http.Response(jsonEncode({'data':{
        'acceptance':acceptance(status:'accepted_with_reservations',
          digest:digest,managed:92),
        'events':[
          {'id':1,'type':'created','actor_id':1,
           'created_at':'2026-11-04T12:00:00Z'},
          {'id':2,'type':'sent','actor_id':1,
           'created_at':'2026-11-04T13:00:00Z'},
          {'id':3,'type':'client_viewed','actor_id':null,
           'created_at':'2026-11-04T14:00:00Z'},
          {'id':4,'type':'customer_signed','actor_id':null,
           'created_at':'2026-11-04T15:00:00Z'},
        ],
      }}),200);
    });
    final result=await RemoteWorkAcceptanceRepository(api:api)
        .details('acceptance-21');
    expect(result.reportKind,ReportKind.workAcceptance);
    expect(result.workAcceptance!.acceptanceResult,'accepted_with_reservations');
    expect(result.workAcceptance!.reservation,'Handle pending');
    expect(result.workAcceptance!.verifiedReportPdf,pdf);
    expect(result.workAcceptance!.verifiedSignaturePng,png);
    expect(result.workAcceptance!.events.length,5);
    expect(result.workAcceptance!.events.last.stage,
        WorkAcceptanceStage.completed);
    api.dispose();
  });
}
