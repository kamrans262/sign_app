import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/core/services/active_company_session.dart';
import 'package:sign2digital/features/company/data/remote_company_repository.dart';
import 'package:sign2digital/features/company/domain/company_profile.dart';
import 'package:sign2digital/features/clients/data/remote_client_repository.dart';
import 'package:sign2digital/features/clients/domain/client_profile.dart';
import 'package:sign2digital/features/clients/presentation/widgets/sign2digital_details_tabs.dart';
import 'package:sign2digital/features/documents/data/remote_general_document_repository.dart';
import 'package:sign2digital/features/documents/domain/general_document_draft.dart';
import 'package:sign2digital/features/documents/presentation/screens/general_document_details_screen.dart';
import 'package:sign2digital/features/quotes/presentation/widgets/sign2digital_quote_summary_card.dart';
import 'package:sign2digital/features/quotes/presentation/widgets/sign2digital_signature_action_card.dart';

class _HistoryRepository extends RemoteGeneralDocumentRepository {
  @override
  Future<Map<String,dynamic>?> issuedMetadata(int id) async => null;
  @override
  Future<List<Map<String,dynamic>>> history(int id) async => [
    {'id':11,'type':'created','created_at':'2026-11-12 12:00:00'},
  ];
}

class _IssuedRepository extends _HistoryRepository {
  @override
  Future<Map<String,dynamic>?> issuedMetadata(int id) async => {
    'issue':{'document_id':id},'signatures':[],
    'deliveries':[], 'links':[],
  };
  @override
  Future<Uint8List> issuedPdf(int id) async =>
      Uint8List.fromList([37,80,68,70,45,49,46,55]);
}

class _Company extends RemoteCompanyRepository {
  @override
  Future<CompanyProfile?> byId(String id) async => CompanyProfile(
    id:id,companyName:'Swiss Renovation GmbH',address:'',
    countryIsoCode:'CH',dialingCode:'+41',phoneNumber:'',
    email:'',swissCompanyId:'',vatNumber:'',iban:'',qrIban:'',
    documentNumbering:'');
}

class _Client extends RemoteClientRepository {
  @override
  Future<ClientProfile> getClient(int id) async => ClientProfile(
    id:id.toString(),companyName:'Kamran',companyType:'Individual client',
    email:'kamran@example.com',phone:'',jobCount:0,fullName:'Kamran');
}

void main() {
  setUp(() => ActiveCompanySession.clear());
  const draft = GeneralDocumentDraft(
    id: 41, companyId: 7, number: 'GD-2026-041',
    type: 'power_of_attorney', title: 'Power of Attorney',
    status: 'draft', revision: 1, lockVersion: 1,
    jobTitle: 'Bathroom Renovation', clientName: 'Kamran',
    blocks: [
      GeneralTextBlock(type: 'heading', text: 'Authorization'),
      GeneralTextBlock(type: 'paragraph', text: 'Real saved content.'),
    ],
  );

  testWidgets('Uses existing summary, four action cards and Details tabs',
      (tester) async {
    await tester.pumpWidget(MaterialApp(home: GeneralDocumentDetailsScreen(
      documentId: 41, initialDocument: draft,
      repository: _HistoryRepository(),
    )));
    await tester.pumpAndSettle();
    expect(find.text('Documents'), findsOneWidget);
    expect(find.byType(Sign2DigitalQuoteSummaryCard), findsOneWidget);
    expect(find.byType(Sign2DigitalSignatureActionCard), findsNWidgets(4));
    expect(find.byType(Sign2DigitalDetailsTabs), findsOneWidget);
    expect(find.text('Power of Attorney'), findsWidgets);
    expect(find.text('Document Information'), findsOneWidget);
    expect(find.text('Bathroom Renovation'), findsWidgets);
    final buttons = find.byKey(const Key('general-document-bottom-actions'));
    expect(buttons, findsOneWidget);
    expect(find.byKey(const Key('general-document-action-edit')), findsOneWidget);
    expect(find.byKey(const Key('general-document-action-review')), findsOneWidget);
    expect(tester.getSize(find.byKey(const Key('general-document-action-edit'))).width,
      lessThan(tester.getSize(buttons).width));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Bottom action buttons only appear on Details tab', (tester) async {
    await tester.pumpWidget(MaterialApp(home: GeneralDocumentDetailsScreen(
      documentId: 41, initialDocument: draft,
      repository: _HistoryRepository(),
      pdfPreviewBuilder: (bytes) => const Text('PDF Preview Rendered'),
    )));
    await tester.pumpAndSettle();
    for(final index in [1,2,3]){
      await tester.tap(find.byKey(Key('details-tab-$index')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('general-document-bottom-actions')), findsNothing);
      if(index==1){
        expect(find.text('PDF Preview Rendered'),findsOneWidget);
        expect(find.byKey(const Key('general-document-unissued-label')),
          findsOneWidget);
      }
      if(index==3) expect(find.text('created'),findsOneWidget);
    }
    await tester.tap(find.byKey(const Key('details-tab-0')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('general-document-bottom-actions')),findsOneWidget);
  });

  testWidgets('Issued document shows paired Details actions without duplicates',
      (tester) async {
    const approved = GeneralDocumentDraft(
      id:45,companyId:7,clientId:12,number:'GD-2026-045',
      title:'Client Agreement',type:'letter',status:'approved',
      revision:2,lockVersion:2,
      blocks:[GeneralTextBlock(type:'paragraph',text:'Verified contract.')],
    );
    ActiveCompanySession.setVerified(7,role:'owner',permissions:const []);
    await tester.pumpWidget(MaterialApp(home: GeneralDocumentDetailsScreen(
      documentId:45,initialDocument:approved,
      repository:_IssuedRepository(),clientRepository:_Client(),
      companyRepository:_Company(),
      pdfPreviewBuilder:(bytes)=>const Text('PDF Preview Rendered'),
    )));
    await tester.pumpAndSettle();
    expect(find.text('Swiss Renovation GmbH'),findsOneWidget);
    expect(find.byKey(const Key('general-document-action-issue')),findsNothing);
    final buttons=find.byKey(const Key('general-document-bottom-actions'));
    expect(buttons,findsOneWidget);
    expect(find.byKey(const Key('general-document-send')),findsOneWidget);
    expect(find.byKey(const Key('general-document-sign')),findsOneWidget);
    final last=find.byKey(const Key('general-document-copy-link'));
    expect(last,findsOneWidget);
    expect(tester.getSize(last).width,closeTo(tester.getSize(buttons).width,1));
    expect(find.text('Preview / Download PDF'),findsNothing);
    expect(find.text('Share Verified PDF'),findsNothing);

    await tester.ensureVisible(find.byKey(const Key('general-document-send')));
    await tester.tap(find.byKey(const Key('general-document-send')));
    await tester.pumpAndSettle();
    final email=find.byWidgetPredicate((widget) =>
      widget is TextField &&
      widget.decoration?.labelText=='Recipient Email');
    expect(email,findsOneWidget);
    expect(tester.widget<TextField>(email).controller?.text,
      'kamran@example.com');
  });

  testWidgets('Approved documents show one full-width action in Details',
      (tester) async {
    const approved = GeneralDocumentDraft(
      id: 42,companyId:7,number:'GD-2026-042',
      title:'Approved Letter',type:'letter',status:'approved',
      revision:2,lockVersion:2,
      blocks:[GeneralTextBlock(type:'paragraph',text:'Approved content.')],
    );
    await tester.pumpWidget(MaterialApp(home: GeneralDocumentDetailsScreen(
      documentId:42,initialDocument:approved,
      repository:_HistoryRepository(),
    )));
    await tester.pumpAndSettle();
    final button=find.byKey(const Key('general-document-issue'));
    expect(button,findsOneWidget);
    expect(find.byKey(const Key('general-document-action-edit')),findsNothing);
    expect(find.byKey(const Key('general-document-action-review')),findsNothing);
    expect(tester.getSize(button).width,
      closeTo(tester.getSize(find.byKey(
        const Key('general-document-bottom-actions'))).width,1));
  });
}
