import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/features/documents/domain/addendum_draft.dart';
import 'package:sign2digital/features/documents/domain/document_record.dart';
import 'package:sign2digital/features/documents/presentation/screens/document_details_screen.dart';

DocumentRecord _document(String status) => DocumentRecord(
  id: 'addendum-8', category: DocumentCategory.addends,
  number: 'A-8', title: 'Addendum A-8', project: 'Roof repair',
  customer: 'Sample Customer', jobId: '11',
  timestamp: DateTime(2026, 11, 12),
  status: status, version: 1,
  addendumDraftId: 'addendum-8',
  related: [
    DocumentRecord(
      id: 'signed-4', category: DocumentCategory.quotes,
      number: 'Q-11', title: 'Signed Quote Q-11',
      project: 'Roof repair', customer: 'Sample Customer',
      jobId: '11', timestamp: DateTime(2026, 11, 11),
      status: 'signed', verifiedSignedPdfAvailable: true,
    ),
  ],
);

void main() {
  setUp(() {
    AddendumDraftSession.clear();
    AddendumDraftSession.rememberRemote(AddendumDraft(
      id: 'addendum-8', serverId: 8, serverRevision: 1,
      serverStatus: 'draft', number: 'A-8',
      title: 'Roof repair adjustment',
      description: 'Additional waterproofing',
      linkedDocumentId: 'signed-4',
      effectiveDate: DateTime(2026, 11, 12),
    ));
  });
  tearDown(AddendumDraftSession.clear);

  testWidgets('existing approval action requires consent and updates the same document',
      (tester) async {
    var calls = 0;
    final original = _document('draft');
    await tester.pumpWidget(MaterialApp(
      home: DocumentDetailsScreen(
        documentId: original.id, document: original,
        onApproveAddendum: (record) async {
          calls++;
          expect(record.id, original.id);
          expect(record.status, 'draft');
          return _document('approved');
        },
      ),
    ));
    await tester.tap(find.byKey(const Key('document-action-3')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('addendum-approve')), findsOneWidget);
    await tester.tap(find.byKey(const Key('addendum-approve')));
    await tester.pumpAndSettle();
    expect(find.text('Review Addendum'), findsOneWidget);
    expect(calls, 0);
    final submit = find.byKey(const Key('addendum-confirm-approval'));
    final button = tester.widget<FilledButton>(
        find.descendant(of: submit, matching: find.byType(FilledButton)));
    expect(button.onPressed, isNull);
    await tester.tap(find.text('I reviewed and approve this exact separate addendum.'));
    await tester.pumpAndSettle();
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.text('Approved'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('document-action-3')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('addendum-approve')), findsNothing);
  });
}
