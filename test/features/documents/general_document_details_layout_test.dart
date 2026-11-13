import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/core/services/active_company_session.dart';
import 'package:sign2digital/features/clients/presentation/widgets/sign2digital_details_tabs.dart';
import 'package:sign2digital/features/documents/data/remote_general_document_repository.dart';
import 'package:sign2digital/features/documents/domain/general_document_draft.dart';
import 'package:sign2digital/features/documents/presentation/screens/general_document_details_screen.dart';
import 'package:sign2digital/features/quotes/presentation/widgets/sign2digital_quote_summary_card.dart';
import 'package:sign2digital/features/quotes/presentation/widgets/sign2digital_signature_action_card.dart';

class _HistoryRepository extends RemoteGeneralDocumentRepository {
  @override
  Future<List<Map<String,dynamic>>> history(int id) async => [
    {'id':11,'type':'created','created_at':'2026-11-12 12:00:00'},
  ];
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
    )));
    await tester.pumpAndSettle();
    for(final index in [1,2,3]){
      await tester.tap(find.byKey(Key('details-tab-$index')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('general-document-bottom-actions')), findsNothing);
      if(index==1) expect(find.text('Real saved content.'),findsOneWidget);
      if(index==3) expect(find.text('created'),findsOneWidget);
    }
    await tester.tap(find.byKey(const Key('details-tab-0')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('general-document-bottom-actions')),findsOneWidget);
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
    final button=find.byKey(const Key('general-document-action-issue'));
    expect(button,findsOneWidget);
    expect(find.byKey(const Key('general-document-action-edit')),findsNothing);
    expect(find.byKey(const Key('general-document-action-review')),findsNothing);
    expect(tester.getSize(button).width,
      closeTo(tester.getSize(find.byKey(
        const Key('general-document-bottom-actions'))).width,1));
  });
}
