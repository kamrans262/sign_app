import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sign2digital/features/quotes/domain/quote_document_tracking.dart';
import 'package:sign2digital/features/quotes/domain/quote_review_models.dart';
import 'package:sign2digital/features/quotes/domain/quote_signature_draft.dart';
import 'package:sign2digital/features/quotes/domain/quote_signing_context.dart';
import 'package:sign2digital/features/quotes/domain/quote_signed_display_data.dart';
import 'package:sign2digital/features/quotes/presentation/screens/add_signature_screen.dart';
import 'package:sign2digital/features/quotes/presentation/screens/public_customer_signing_screen.dart';
import 'package:sign2digital/features/quotes/services/public_quote_signing_gateway.dart';

QuoteReviewDraft quote() => QuoteReviewDraft(
  id: 'q-public', jobId: 'job-public', quoteNumber: 'Q-PUBLIC',
  clientName: 'External Customer', date: DateTime(2026, 10, 16),
  terms: 'Acceptance of work and its price.',
  items: [
    QuoteReviewWorkItem(
      id: 'one', title: 'Repairs', description: 'Roof',
      quantity: '1', unitPrice: '200.00',
    ),
  ],
  approvedLocally: true,
);

class FakeSigningGateway implements PublicQuoteSigningGateway {
  FakeSigningGateway({this.fail = false});
  final bool fail;
  @override
  Future<PublicQuoteSigningSession> open(String token) async {
    if (fail) throw StateError('Invalid signing token.');
    return PublicQuoteSigningSession(
      quote: quote(),
      tracking: QuoteDocumentTracking(
        quoteId: 'q-public',
        requestId: 'signed-request',
        secureUrl: Uri.parse('https://documents.example.org/sign/test-token'),
        expiresAt: DateTime.now().add(const Duration(days: 1)),
        events: [QuoteDocumentEvent(
          id: 'sent', type: QuoteDocumentEventType.documentSent,
          occurredAt: DateTime.now().subtract(const Duration(minutes: 1)),
        )],
      ),
      signer: const QuoteSigningContext(
        documentId: 'doc-public', signerId: 'signer-public',
        documentVersion: 'v1', consentReference: 'consent-v1',
      ),
    );
  }

  @override
  Future<QuoteSignedDisplayData?> submit(
    String token, QuoteSignatureDraft signature,
  ) async => null;
}

void main() {
  testWidgets('guest customer opens document and capture without login',
      (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: PublicCustomerSigningScreen(
      token: 'test-token', gateway: FakeSigningGateway(),
    )));
    await tester.pumpAndSettle();
    expect(find.text('External Customer'), findsWidgets);
    expect(find.text('Log In'), findsNothing);
    final button = find.byKey(const Key('customer-document-review-sign'));
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
    final signed = tester.widget<AddSignatureScreen>(
      find.byType(AddSignatureScreen),
    );
    expect(signed.requestId, 'signed-request');
    expect(signed.signerId, 'signer-public');
    expect(signed.showBusinessNavigation, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invalid guest token never exposes customer data or login',
      (tester) async {
    await tester.pumpWidget(MaterialApp(home: PublicCustomerSigningScreen(
      token: 'invalid', gateway: FakeSigningGateway(fail: true),
    )));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('public-signing-unavailable')), findsOneWidget);
    expect(find.text('External Customer'), findsNothing);
    expect(find.text('Log In'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('HTTP contract requires HTTPS, returns active document and PDF receipt',
      () async {
    expect(
      () => HttpPublicQuoteSigningGateway(
        apiBase: Uri.parse('http://localhost:8000/'),
      ),
      throwsArgumentError,
    );
    final client = MockClient((request) async {
      expect(request.url.scheme, 'https');
      expect(request.url.path, startsWith('/api/public/signing/'));
      if (request.method == 'GET') {
        return http.Response(jsonEncode({
          'quote': {
            'id': 'q-public', 'jobId': 'job-public',
            'quoteNumber': 'Q-PUBLIC',
            'clientName': 'External Customer',
            'date': '2026-10-16T12:00:00Z',
            'terms': 'Accepted terms',
            'items': [{
              'id': 'item-1', 'title': 'Repair roof',
              'description': 'Work', 'quantity': '1', 'unitPrice': '100.00',
            }],
          },
          'request': {
            'requestId': 'signed-request',
            'secureUrl': 'https://documents.example.org/sign/test-token',
            'expiresAt': DateTime.now().add(const Duration(days: 1))
                .toUtc().toIso8601String(),
            'events': [{
              'id': 'sent-1', 'type': 'documentSent',
              'occurredAt': DateTime.now().toUtc().toIso8601String(),
            }],
          },
          'signer': {
            'documentId': 'doc-public', 'signerId': 'signer-public',
            'documentVersion': 'v1', 'consentReference': 'consent-v1',
          },
        }), 200);
      }
      expect(request.method, 'POST');
      expect(request.url.path, endsWith('/submit'));
      final data = jsonDecode(request.body) as Map<String, dynamic>;
      expect(data['signerId'], 'signer-public');
      expect(data['consentAccepted'], isTrue);
      const signedPdf = '%PDF-1.7\n1 0 obj\nendobj\n%%EOF\n';
      return http.Response(jsonEncode({
        'documentId': 'doc-public',
        'quoteId': 'q-public',
        'jobId': 'job-public',
        'quoteNumber': 'Q-PUBLIC',
        'projectName': 'Repairs',
        'signerName': 'External Customer',
        'signedAt': DateTime.now().toUtc().toIso8601String(),
        'signedPdfBase64': base64Encode(signedPdf.codeUnits),
        'signedPdfSha256': sha256.convert(signedPdf.codeUnits).toString(),
      }), 200);
    });
    final gateway = HttpPublicQuoteSigningGateway(
      apiBase: Uri.parse('https://api.example.org/'), client: client,
    );
    final session = await gateway.open('test-token');
    expect(session.quote.jobId, 'job-public');
    expect(session.tracking.requestIsActive, isTrue);
    final evidence = QuoteSignatureDraft(
      quoteId: 'q-public', documentId: 'doc-public',
      requestId: 'signed-request', signerId: 'signer-public',
      documentVersion: 'v1', consentReference: 'consent-v1',
      method: QuoteSignatureMethod.type, typedName: 'External Customer',
      pngBytes: Uint8List.fromList([1, 2, 3]),
      capturedAt: DateTime.now().toUtc(),
      consentAccepted: true,
    );
    final receipt = await gateway.submit('test-token', evidence);
    expect(receipt?.documentId, 'doc-public');
    expect(receipt?.jobId, 'job-public');
    expect(receipt?.signedPdfBytes, isNotEmpty);
  });
}
