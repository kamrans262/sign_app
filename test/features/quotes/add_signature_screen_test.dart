import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/features/quotes/domain/quote_signature_draft.dart';
import 'package:sign2digital/features/quotes/presentation/screens/add_signature_screen.dart';
import 'package:sign2digital/features/quotes/presentation/screens/customer_document_view_screen.dart';
import 'package:sign2digital/features/quotes/domain/quote_document_tracking.dart';
import 'package:sign2digital/features/quotes/domain/quote_review_models.dart';

void main() {
  setUp(QuoteSignatureDraftSession.clearAll);

  Widget screen({
    Future<bool> Function(QuoteSignatureDraft)? onSubmit,
    bool navigation = false,
    ValueChanged<int>? onTabSelected,
    String requestId = 'request-01',
  }) => MaterialApp(home: AddSignatureScreen(
    quoteId: 'q1', documentId: 'doc1', requestId: requestId,
    signerId: 'verified-signer', documentVersion: 'v1',
    consentReference: 'terms-v1', termsText: 'Test document terms and services.',
    onSubmit: onSubmit,
    showBusinessNavigation: navigation, onTabSelected: onTabSelected,
  ));

  test('image header checks both content signatures', () {
    expect(isSupportedSignatureImage(Uint8List.fromList([1, 2, 3])), isFalse);
    expect(isSupportedSignatureImage(Uint8List.fromList([
      0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a,
    ])), isTrue);
  });

  testWidgets('draw starts empty, can draw, clear and preserve other drafts',
      (tester) async {
    await tester.pumpWidget(screen());
    expect(find.text('Add Signature'), findsOneWidget);
    expect(find.byKey(const Key('signature-draw-canvas')), findsOneWidget);
    final canvas = find.byKey(const Key('signature-draw-canvas'));
    await tester.timedDrag(canvas, const Offset(90, 40),
      const Duration(milliseconds: 180));
    await tester.pump();
    await tester.tap(find.byKey(const Key('signature-tab-type')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('signature-type-input')), 'Jean Dupont');
    await tester.tap(find.byKey(const Key('signature-tab-draw')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('signature-clear')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('signature-tab-type')));
    await tester.pumpAndSettle();
    expect(find.text('Jean Dupont'), findsWidgets);
  });

  testWidgets('cannot confirm an empty signature', (tester) async {
    await tester.pumpWidget(screen());
    await tester.ensureVisible(find.text('Confirm Signature'));
    await tester.tap(find.text('Confirm Signature'));
    await tester.pump();
    expect(find.textContaining('Please add a signature'), findsOneWidget);
  });

  testWidgets('typed signature requires consent and sends correct IDs, png, method',
      (tester) async {
    QuoteSignatureDraft? captured;
    await tester.pumpWidget(screen(onSubmit: (draft) async {
      captured = draft;
      return false;
    }));
    await tester.tap(find.byKey(const Key('signature-tab-type')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('signature-type-input')), 'Anne Example');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Confirm Signature'));
    await tester.tap(find.text('Confirm Signature'));
    await tester.pumpAndSettle();
    expect(find.text('Confirm agreement'), findsOneWidget);
    expect(tester.widget<TextButton>(find.byKey(
      const Key('signature-consent-continue'))).onPressed, isNull);
    await tester.tap(find.byKey(const Key('signature-consent-checkbox')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('signature-consent-continue')));
    await tester.pumpAndSettle();
    expect(captured, isNotNull);
    expect(captured!.quoteId, 'q1');
    expect(captured!.documentId, 'doc1');
    expect(captured!.requestId, 'request-01');
    expect(captured!.signerId, 'verified-signer');
    expect(captured!.method, QuoteSignatureMethod.type);
    expect(captured!.typedName, 'Anne Example');
    expect(captured!.consentAccepted, isTrue);
    expect(isSupportedSignatureImage(captured!.pngBytes), isTrue);
    expect(find.textContaining('not submitted'), findsOneWidget);
  });

  testWidgets('request context is required before signature confirmation',
      (tester) async {
    await tester.pumpWidget(screen(requestId: ''));
    await tester.tap(find.byKey(const Key('signature-tab-type')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('signature-type-input')), 'A. Example');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.ensureVisible(find.text('Confirm Signature'));
    await tester.tap(find.text('Confirm Signature'));
    await tester.pump();
    expect(find.textContaining('valid signing request'), findsOneWidget);
  });

  testWidgets('upload screen is a real action and switching tabs preserves type',
      (tester) async {
    await tester.pumpWidget(screen());
    await tester.tap(find.byKey(const Key('signature-tab-upload')));
    await tester.pumpAndSettle();
    expect(find.text('Upload Signature'), findsOneWidget);
    expect(find.text('Choose an image of your signature'), findsOneWidget);
    await tester.tap(find.byKey(const Key('signature-tab-type')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('signature-type-input')), 'Muller AG');
    await tester.tap(find.byKey(const Key('signature-tab-upload')));
    await tester.tap(find.byKey(const Key('signature-tab-type')));
    await tester.pumpAndSettle();
    expect(find.text('Muller AG'), findsWidgets);
  });
  testWidgets('customer review action opens local capture but never claims signed',
      (tester) async {
    final quote = QuoteReviewDraft(
      id: 'quote-integration', quoteNumber: 'Q-24',
      clientName: 'Muller AG', currency: 'CHF',
      terms: 'Terms applicable to this document.',
      items: [QuoteReviewWorkItem(id: '1', title: 'Window',
        quantity: '1', unitPrice: '100.00')],
      approvedLocally: true,
    );
    final tracking = QuoteDocumentTracking(
      quoteId: 'quote-integration',
      requestId: 'real-request-context',
      secureUrl: Uri.parse('https://example.com/sign/request-01'),
      expiresAt: DateTime.now().add(const Duration(days: 1)),
      events: [QuoteDocumentEvent(
        id: 'sent', type: QuoteDocumentEventType.documentSent,
        occurredAt: DateTime.now().subtract(const Duration(minutes: 5)),
      )],
    );
    await tester.pumpWidget(MaterialApp(home: CustomerDocumentViewScreen(
      quote: quote, tracking: tracking,
    )));
    final action = find.byKey(const Key('customer-document-review-sign'));
    await tester.ensureVisible(action);
    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(find.text('Add Signature'), findsOneWidget);
    expect(find.text('Confirm Signature'), findsOneWidget);
    expect(find.text('Document Signed'), findsNothing);
    // No signer verification context was supplied: confirmation is blocked.
    await tester.tap(find.byKey(const Key('signature-tab-type')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('signature-type-input')), 'Jane');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.ensureVisible(find.text('Confirm Signature'));
    await tester.tap(find.text('Confirm Signature'));
    await tester.pump();
    expect(find.textContaining('valid signing request'), findsOneWidget);
  });

}
