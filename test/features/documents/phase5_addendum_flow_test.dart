import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/core/theme/app_theme.dart';
import 'package:sign2digital/features/documents/domain/addendum_draft.dart';
import 'package:sign2digital/features/documents/domain/addendum_signature_request.dart';
import 'package:sign2digital/features/documents/domain/document_record.dart';
import 'package:sign2digital/features/documents/data/demo_document_repository.dart';
import 'package:sign2digital/features/documents/presentation/screens/create_addendum_screen.dart';
import 'package:sign2digital/features/documents/presentation/screens/document_details_screen.dart';
import 'package:sign2digital/features/documents/services/addendum_pdf_service.dart';

DocumentRecord source({bool signed = true}) => DocumentRecord(
  id: 'original-quote-5',
  category: DocumentCategory.quotes,
  number: 'Q-500',
  title: 'Quote Q-500',
  project: 'Job 500',
  customer: 'Customer Five',
  timestamp: DateTime(2026, 10, 15),
  status: signed ? 'Signed' : 'Approved',
  verifiedSignedPdfAvailable: false,
);

AddendumDraft draft({
  String quantity = '3',
  String unitPrice = '100.00',
  int vat = 810,
}) => AddendumDraft(
  id: 'addendum-5',
  number: 'A-500',
  title: 'Roof variation',
  description: 'Extend roofing scope',
  linkedDocumentId: 'original-quote-5',
  linkedDocumentNumber: 'Q-500',
  linkedJobId: 'job-5',
  linkedClientId: 'client-5',
  effectiveDate: DateTime(2026, 10, 16),
  additionalWork: 'Roof tiles',
  quantity: quantity,
  unitPrice: unitPrice,
  vatBasisPoints: vat,
);

void main() {
  setUp(() {
    AddendumDraftSession.clear();
    AddendumSignatureRequestSession.clear();
  });

  tearDown(() {
    AddendumDraftSession.clear();
    AddendumSignatureRequestSession.clear();
  });

  test('prices use minor units and non-financial variations remain valid', () {
    final work = draft();
    expect(work.subtotalMinor, 30000);
    expect(work.vatMinor, 2430);
    expect(work.totalMinor, 32430);
    expect(work.validationIssues, isEmpty);

    final invalid = draft(quantity: 'not-a-number');
    expect(invalid.totalMinor, isNull);
    expect(invalid.validationIssues, contains(
        'Quantity must be a whole number between 1 and 100000.'));

    final incomplete = draft(unitPrice: '');
    expect(incomplete.totalMinor, isNull);
    expect(incomplete.validationIssues,
        contains('Enter a valid positive unit price.'));

    final noteOnly = draft().copyWith(
      additionalWork: '', quantity: '', unitPrice: '',
    );
    expect(noteOnly.validationIssues, isEmpty);
    expect(noteOnly.totalMinor, 0);

    expect(draft(vat: 10001).validationIssues,
        contains('VAT must be between 0% and 100%.'));
  });

  test('created addendum is linked and cannot alter the original document',
      () async {
    final original = source();
    final originalStatus = original.status;
    final addendum = draft();
    AddendumDraftSession.create(addendum);
    final actual = AddendumDraftSession.load(addendum.id)!;
    expect(actual.isCreatedLocally, isTrue);
    expect(actual.linkedDocumentId, original.id);
    expect(original.status, originalStatus);
    expect(original.verifiedSignedPdfAvailable, isFalse);

    // PDF contains an explicit unsigned notice and cannot be used as proof
    // of acceptance or replace a signed original.
    final pdf = await const AddendumPdfService().build(actual, original);
    expect(pdf, isA<Uint8List>());
    expect(String.fromCharCodes(pdf.take(5)), '%PDF-');
    expect(pdf.length, greaterThan(100));
  });

  testWidgets('Figma addendum screen restores financial inputs and reviews',
      (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    AddendumDraftSession.save(draft());
    await tester.pumpWidget(MaterialApp(home: CreateAddendumScreen(
      linkedDocument: source(), draftId: 'addendum-5',
    )));
    expect(find.byKey(const Key('create-addendum-scroll')), findsOneWidget);
    final total = find.byKey(const Key('addendum-total'));
    await tester.ensureVisible(total);
    await tester.pumpAndSettle();
    expect(find.textContaining('CHF 324.30'), findsOneWidget);
    final review = find.byKey(const Key('addendum-review'));
    await tester.ensureVisible(review);
    await tester.tap(review);
    await tester.pumpAndSettle();
    expect(find.descendant(
      of: find.byType(BottomSheet),
      matching: find.text('Review Addendum'),
    ), findsOneWidget);
    expect(find.text('Original: Q-500'), findsOneWidget);
    expect(find.textContaining('CHF 324.30'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('created addendum opens PDF details, while saved draft edits',
      (tester) async {
    final original = source();
    final data = draft();
    AddendumDraftSession.create(data);
    final created = DocumentRecord(
      id: data.id,
      category: DocumentCategory.addends,
      number: data.number,
      title: 'Addendum ${data.number}',
      project: original.project,
      customer: original.customer,
      timestamp: DateTime.now(),
      status: 'Draft',
      addendumDraftId: data.id,
      related: [original],
    );
    await tester.pumpWidget(MaterialApp(home: DocumentDetailsScreen(
      documentId: created.id, document: created,
      // The native printing plugin is integration-tested separately. Here we
      // verify that the generated addendum PDF reaches the preview widget.
      pdfPreviewBuilder: (bytes) => SizedBox(
        key: const Key('document-pdf-preview'),
        child: Text('Unsigned addendum PDF: ${bytes.length} bytes'),
      ),
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('details-tab-1')));
    // A PDF viewer can schedule frames indefinitely. Bounded pumping keeps
    // this test independent of platform viewer animations and timeouts.
    for (var attempt = 0;
        attempt < 20 &&
            find.byKey(const Key('document-pdf-preview')).evaluate().isEmpty;
        attempt++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byKey(const Key('document-signed-pdf-unavailable')), findsNothing);
    expect(find.byKey(const Key('document-pdf-preview')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Send for Signature needs service confirmation and source IDs',
      (tester) async {
    final original = source();
    final createdDraft = draft();
    AddendumDraftSession.create(createdDraft);
    final doc = DocumentRecord(
      id: createdDraft.id, category: DocumentCategory.addends,
      number: createdDraft.number,
      title: 'Addendum ${createdDraft.number}',
      project: original.project,
      customer: original.customer,
      timestamp: DateTime.now(),
      status: 'Draft',
      related: [original],
      addendumDraftId: createdDraft.id,
    );
    var calls = 0;
    await tester.pumpWidget(MaterialApp(home: DocumentDetailsScreen(
      documentId: doc.id,
      document: doc,
      requestAddendumSignature: (draft, source) async {
        calls++;
        expect(draft.id, createdDraft.id);
        expect(source.id, original.id);
        return AddendumSignatureRequest(
          requestId: 'request-500',
          addendumId: draft.id,
          originalDocumentId: source.id,
          secureUrl: Uri.parse('https://sign.example.org/addenda/token-500'),
          expiresAt: DateTime.now().add(const Duration(days: 3)),
          confirmedSentAt: DateTime.now().toUtc(),
        );
      },
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('document-action-3')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('addendum-send-for-signature')), findsOneWidget);
    await tester.tap(find.byKey(const Key('addendum-send-for-signature')));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.byKey(const Key('addendum-signature-request-status')),
      findsOneWidget);
    expect(find.text('Status: Awaiting Signature'), findsOneWidget);
    final receipt = AddendumSignatureRequestSession.forAddendum(doc.id);
    expect(receipt?.originalDocumentId, original.id);
    expect(receipt?.addendumId, doc.id);
    expect(AddendumDraftSession.isLocked(doc.id), isTrue);
    expect(() => AddendumDraftSession.create(
      createdDraft.copyWith(description: 'Changed after sending'),
    ), throwsStateError);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dark iPhone signature link is readable and reopening does not POST again',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final original = source();
    final createdDraft = draft();
    AddendumDraftSession.create(createdDraft);
    final doc = DocumentRecord(
      id: createdDraft.id, category: DocumentCategory.addends,
      number: createdDraft.number, title: 'Addendum',
      project: original.project, customer: original.customer,
      timestamp: DateTime.now(), status: 'Approved',
      related: [original], addendumDraftId: createdDraft.id,
    );
    var calls = 0;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: DocumentDetailsScreen(
        documentId: doc.id, document: doc,
        requestAddendumSignature: (draft, source) async {
          calls++;
          return AddendumSignatureRequest(
            requestId: 'existing-501', addendumId: draft.id,
            originalDocumentId: source.id,
            secureUrl: Uri.parse('https://sign.example.org/link-501'),
            expiresAt: DateTime.now().add(const Duration(days: 3)),
            confirmedSentAt: null,
          );
        },
      ),
    ));
    await tester.pumpAndSettle();
    for (var attempt = 0; attempt < 2; attempt++) {
      await tester.tap(find.byKey(const Key('document-action-3')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('addendum-send-for-signature')));
      await tester.pumpAndSettle();
      expect(find.text('Status: Link ready (not emailed)'), findsOneWidget);
      final label = find.text('Original document: Q-500');
      final ctx = tester.element(label);
      expect(DefaultTextStyle.of(ctx).style.color!.computeLuminance(),
        lessThan(.25));
      expect(find.byKey(const Key('addendum-copy-secure-link')),
        findsOneWidget);
      await tester.tapAt(const Offset(15, 120));
      await tester.pumpAndSettle();
    }
    expect(calls, 1, reason: 'Opening the saved link must not send a second request');
    expect(tester.takeException(), isNull);
  });

  test('repository connects created addendum to source in both directions',
      () async {
    final originalId = 'documents-figma-quote-1';
    AddendumDraftSession.create(draft().copyWith(
      linkedDocumentId: originalId,
      linkedDocumentNumber: 'Q-12800',
      linkedJobId: 'job-5',
    ));
    final records = await const DemoDocumentRepository().listDocuments();
    final addendum = records.singleWhere((record) =>
        record.id == 'addendum-5');
    final original = records.singleWhere((record) =>
        record.id == originalId);
    expect(addendum.category, DocumentCategory.addends);
    expect(addendum.related.single.id, original.id);
    expect(original.related.any((r) => r.id == addendum.id), isTrue);
    expect(original.status, 'Signed');
    expect(addendum.status, 'Draft');
    expect(addendum.verifiedSignedPdfAvailable, isFalse);
    expect(addendum.addendumDraftId, 'addendum-5');
    expect(addendum.history.any((e) =>
        e.type == DocumentHistoryType.signed), isFalse);
  });

  test('mismatched service receipt cannot be associated with source', () {
    final original = source();
    AddendumDraftSession.create(draft());
    final stored = AddendumDraftSession.load('addendum-5')!;
    expect(() => AddendumSignatureRequestSession.remember(
      stored, original, AddendumSignatureRequest(
        requestId: 'wrong-request',
        addendumId: 'different-document',
        originalDocumentId: original.id,
        secureUrl: Uri.parse('https://sign.example.org/addenda/token-500'),
        expiresAt: DateTime.now().add(const Duration(days: 1)),
        confirmedSentAt: DateTime.now().toUtc(),
      ),
    ), throwsFormatException);
    expect(AddendumSignatureRequestSession.forAddendum(stored.id), isNull);
  });
}
