import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/features/quotes/domain/quote_document_tracking.dart';
import 'package:sign2digital/features/quotes/domain/quote_review_models.dart';
import 'package:sign2digital/features/quotes/domain/quote_signature_draft.dart';
import 'package:sign2digital/features/quotes/presentation/screens/add_signature_screen.dart';
import 'package:sign2digital/features/quotes/presentation/screens/customer_document_view_screen.dart';
import 'package:sign2digital/features/quotes/presentation/screens/document_signed_success_screen.dart';
import 'package:sign2digital/features/quotes/presentation/screens/signature_request_screen.dart';
import 'package:sign2digital/features/quotes/presentation/screens/send_quote_screen.dart';

QuoteReviewDraft _quote() => QuoteReviewDraft(
  id: 'phase3-quote', quoteNumber: 'Q-PHASE3',
  clientId: 'client-12', jobId: 'job-12', companyId: 'company-12',
  clientName: 'Test Client', clientEmail: 'client@example.com',
  date: DateTime(2026, 10, 16),
  terms: 'The customer agrees to the described work.',
  items: [
    QuoteReviewWorkItem(
      id: 'work-12', title: 'Repair roof', description: 'Replace tiles',
      quantity: '1', unitPrice: '300.00',
    ),
  ],
  approvedLocally: true,
);

QuoteDocumentTracking _request() => QuoteDocumentTracking(
  quoteId: 'phase3-quote', requestId: 'request-12',
  secureUrl: Uri.parse('https://example.org/sign/request-12'),
  expiresAt: DateTime.now().add(const Duration(days: 1)),
  events: [
    QuoteDocumentEvent(
      id: 'sent-12', type: QuoteDocumentEventType.documentSent,
      occurredAt: DateTime.now().subtract(const Duration(minutes: 2)),
    ),
  ],
);

const _signer = QuoteSigningContext(
  documentId: 'document-12', signerId: 'signer-12',
  documentVersion: 'v1', consentReference: 'terms-v1',
);

Future<void> _enterTypedSignature(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const Key('signature-tab-type')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('signature-tab-type')));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(const Key('signature-type-input')), 'Test Client',
  );
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('Confirm Signature'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Confirm Signature'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(find.byKey(const Key('signature-consent-checkbox')));
  await tester.pump();
  await tester.tap(find.byKey(const Key('signature-consent-continue')));
  await tester.pump();
  // The image encoder in the signature capture uses the engine event loop.
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
  });
  await tester.pumpAndSettle();
}

void main() {
  setUp(QuoteSignatureDraftSession.clearAll);
  tearDown(QuoteSignatureDraftSession.clearAll);

  testWidgets('Send Quote retains real request and authorized signer callback',
      (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: SendQuoteScreen(
      quote: _quote(),
      tracking: _request(),
      signingContext: _signer,
      onSubmitVerifiedSignature: (_) async => null,
    )));
    await tester.pumpAndSettle();
    final open = find.byKey(const Key('send-view-tracking'));
    await tester.ensureVisible(open);
    await tester.pumpAndSettle();
    await tester.tap(open);
    await tester.pumpAndSettle();
    expect(find.byType(SignatureRequestScreen), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('signature-view-document')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('signature-view-document')));
    await tester.pumpAndSettle();
    expect(find.byType(CustomerDocumentViewScreen), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const Key('customer-document-review-sign')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('customer-document-review-sign')));
    await tester.pumpAndSettle();
    final capture = tester.widget<AddSignatureScreen>(
      find.byType(AddSignatureScreen),
    );
    expect(capture.requestId, 'request-12');
    expect(capture.signerId, 'signer-12');
    expect(capture.documentId, 'document-12');
    expect(capture.documentVersion, 'v1');
    expect(find.byKey(const Key('dashboard-tab-0')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('verified receipt shows success and a real signed timeline event',
      (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    QuoteSignatureDraft? submitted;
    await tester.pumpWidget(MaterialApp(home: SignatureRequestScreen(
      quote: _quote(), tracking: _request(), signingContext: _signer,
      onSubmitVerifiedSignature: (draft) async {
        submitted = draft;
        return QuoteSignedDisplayData(
          documentId: 'document-12', quoteNumber: 'Q-PHASE3',
          projectName: 'Repair roof', signerName: 'Test Client',
          signedAt: DateTime.now().toUtc(),
        );
      },
    )));
    await tester.pumpAndSettle();
    final view = find.byKey(const Key('signature-view-document'));
    await tester.ensureVisible(view);
    await tester.pumpAndSettle();
    await tester.tap(view);
    await tester.pumpAndSettle();
    final review = find.byKey(const Key('customer-document-review-sign'));
    await tester.ensureVisible(review);
    await tester.pumpAndSettle();
    await tester.tap(review);
    await tester.pumpAndSettle();
    expect(find.byType(AddSignatureScreen), findsOneWidget);
    await _enterTypedSignature(tester);
    expect(submitted, isNotNull);
    expect(submitted!.quoteId, 'phase3-quote');
    expect(submitted!.requestId, 'request-12');
    expect(submitted!.documentVersion, 'v1');
    expect(submitted!.consentAccepted, isTrue);
    expect(find.byType(DocumentSignedSuccessScreen), findsOneWidget);
    expect(find.text('Document Signed!'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(SignatureRequestScreen), findsOneWidget);
    expect(find.text('Document Signed'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('incorrect receipt is rejected and does not claim signed',
      (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: CustomerDocumentViewScreen(
      quote: _quote(), tracking: _request(), signingContext: _signer,
      documentTitle: 'Quote',
      onSubmitVerifiedSignature: (_) async => QuoteSignedDisplayData(
        documentId: 'different-document',
        quoteNumber: 'Q-PHASE3', projectName: 'Repair roof',
        signerName: 'Test Client', signedAt: DateTime.now(),
      ),
    )));
    await tester.pumpAndSettle();
    final review = find.byKey(const Key('customer-document-review-sign'));
    await tester.ensureVisible(review);
    await tester.pumpAndSettle();
    await tester.tap(review);
    await tester.pumpAndSettle();
    await _enterTypedSignature(tester);
    expect(find.byType(DocumentSignedSuccessScreen), findsNothing);
    expect(find.textContaining('not submitted'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
