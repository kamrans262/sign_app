import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/core/widgets/sign2digital_styled_bottom_sheet.dart';
import 'package:sign2digital/features/documents/domain/document_record.dart';
import 'package:sign2digital/features/jobs/presentation/widgets/job_addenda_bottom_sheet.dart';

DocumentRecord _record(String id, DocumentCategory category, String number, {
    String status = 'approved', bool verified = false,
    List<DocumentRecord> related = const [], String jobId = '44',
    int day = 12}) => DocumentRecord(
  id:id, category:category, number:number,
  title:number, project:'Bathroom Job', customer:'Customer',
  timestamp:DateTime.utc(2026,11,day), status:status,
  jobId:jobId, verifiedSignedPdfAvailable:verified, related:related,
);

void main() {
  final quote1=_record('quote-1',DocumentCategory.quotes,'Q-001');
  final quote2=_record('quote-2',DocumentCategory.quotes,'Q-002');
  final quote3=_record('quote-3',DocumentCategory.quotes,'Q-003');
  final signed=_record('signed-8',DocumentCategory.quotes,'Q-001',
      status:'signed',verified:true);
  final addendum=_record('addendum-9',DocumentCategory.addends,'AD-009',
      status:'draft');
  final unrelated=_record('quote-99',DocumentCategory.quotes,'Q-099',
      jobId:'99');

  Widget app(ValueChanged<JobAddendaSelection?> onSelected) => MaterialApp(
    home:Scaffold(body:Builder(builder:(context)=>Center(
      child:ElevatedButton(
        onPressed:() async {
          final selected=await showSign2DigitalBottomSheet<JobAddendaSelection>(
            context:context, isScrollControlled:true,
            builder:(_)=>JobAddendaBottomSheet(
              jobId:'44',jobReference:'JOB-044',
              live:true,canCreate:true,
              loadDocuments:(_)=>Future.value([
                quote1,quote2,quote3,addendum,unrelated,
              ]),
              loadDetails:(id) async => switch(id) {
                'quote-1' => quote1.withRelated([signed]),
                'quote-2' => quote2.withRelated([addendum]),
                _ => quote3,
              },
            ),
          );
          onSelected(selected);
        },
        child:const Text('Open Addenda')),
    ))),
  );

  testWidgets('separates existing addenda and genuinely unlinked job quotes',
      (tester) async {
    JobAddendaSelection? selected;
    await tester.pumpWidget(app((choice)=>selected=choice));
    await tester.tap(find.text('Open Addenda'));
    await tester.pumpAndSettle();
    expect(find.text('View Addenda'),findsOneWidget);
    expect(find.text('Quotes Without Addenda'),findsOneWidget);
    expect(find.byKey(const Key('job-addenda-existing-addendum-9')),
        findsOneWidget);
    expect(find.byKey(const Key('job-addenda-quote-quote-1')),
        findsOneWidget);
    expect(find.byKey(const Key('job-addenda-quote-quote-2')),
        findsNothing);
    expect(find.byKey(const Key('job-addenda-quote-quote-3')),
        findsOneWidget);
    expect(find.byKey(const Key('job-addenda-quote-quote-99')),
        findsNothing);
    await tester.ensureVisible(
        find.byKey(const Key('job-addenda-quote-quote-1')));
    await tester.tap(find.byKey(const Key('job-addenda-quote-quote-1')));
    await tester.pumpAndSettle();
    expect(selected?.isExisting,false);
    expect(selected?.document.id,'quote-1');
    expect(selected?.signedOriginal?.id,'signed-8');
    expect(tester.takeException(),isNull);
  });

  testWidgets('existing addendum opens its own document identity',
      (tester) async {
    JobAddendaSelection? selected;
    await tester.pumpWidget(app((choice)=>selected=choice));
    await tester.tap(find.text('Open Addenda'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(
        const Key('job-addenda-existing-addendum-9')));
    await tester.pumpAndSettle();
    expect(selected?.isExisting,true);
    expect(selected?.document.id,'addendum-9');
  });

  testWidgets('unsigned quotation remains visible but cannot bypass M10 signing',
      (tester) async {
    JobAddendaSelection? selected;
    await tester.pumpWidget(app((choice)=>selected=choice));
    await tester.tap(find.text('Open Addenda'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
        find.byKey(const Key('job-addenda-quote-quote-3')));
    await tester.tap(find.byKey(const Key('job-addenda-quote-quote-3')));
    await tester.pump();
    expect(selected,isNull);
    expect(find.textContaining('verified signed quotation'),findsOneWidget);
    expect(find.byKey(const Key('job-addenda-close')),findsOneWidget);
  });
}
