import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/features/quotes/data/signed_quote_file_store.dart';
import 'package:sign2digital/features/quotes/domain/quote_document_tracking.dart';
import 'package:sign2digital/features/quotes/domain/quote_review_models.dart';
import 'package:sign2digital/features/quotes/domain/quote_signed_display_data.dart';

QuoteDocumentEvent event(QuoteDocumentEventType type) =>
    QuoteDocumentEvent(id: type.name, type: type, occurredAt: DateTime(2026, 9, 2));

QuoteReviewDraft quote({String? jobId = 'job-77'}) => QuoteReviewDraft(
  id: 'quote-77', jobId: jobId, clientId: 'client-77',
  quoteNumber: 'Q-77', clientName: 'Client',
  date: DateTime(2026, 9, 1),
  terms: 'Terms', items: [
    QuoteReviewWorkItem(
      id: 'item', title: 'Work', description: 'Verified signed job document',
      quantity: '1', unitPrice: '50.00',
    ),
  ],
  approvedLocally: true,
);

QuoteSignedDisplayData receipt({
  Uint8List? bytes,
  String documentId = 'doc-77',
  String jobId = 'job-77',
}) => QuoteSignedDisplayData(
  documentId: documentId, quoteId: 'quote-77', jobId: jobId,
  quoteNumber: 'Q-77', projectName: 'Work',
  signerName: 'Customer', signedAt: DateTime(2026, 9, 3),
  signedPdfBytes: bytes,
);

void main() {
  test('all six statuses derive from verified events and expiry', () {
    final now = DateTime(2026, 9, 3);
    final draft = QuoteDocumentTracking(quoteId: 'quote-77');
    expect(draft.statusAt(now), QuoteSignatureStatus.draft);

    final sent = QuoteDocumentTracking(
      quoteId: 'quote-77', requestId: 'request-77',
      events: [event(QuoteDocumentEventType.documentSent)],
    );
    expect(sent.statusAt(now), QuoteSignatureStatus.sent);
    expect(sent.withEvent(event(QuoteDocumentEventType.documentViewed))
        .statusAt(now), QuoteSignatureStatus.viewed);
    expect(sent.withEvent(event(QuoteDocumentEventType.signatureRequested))
        .statusAt(now), QuoteSignatureStatus.awaitingSignature);

    final expired = QuoteDocumentTracking(
      quoteId: 'quote-77', requestId: 'request-77',
      expiresAt: DateTime(2026, 9, 2),
      events: [event(QuoteDocumentEventType.documentSent)],
    );
    expect(expired.statusAt(now), QuoteSignatureStatus.expired);
    expect(expired.usableUrl(now), isNull);
    // Expiry is checked even when a sender still has the old request ID.
    expect(expired.requestIsActive, isFalse);

    final signed = expired.withEvent(event(QuoteDocumentEventType.documentSigned));
    expect(signed.statusAt(now), QuoteSignatureStatus.signed);
  });

  test('verified PDF is indexed by job and cannot be overwritten', () async {
    final root = await Directory.systemTemp.createTemp('sign2digital_signed_');
    addTearDown(() => root.delete(recursive: true));
    final store = SignedQuoteFileStore(directoryProvider: () async => root);
    final pdfBytes = Uint8List.fromList(
      '%PDF-1.7\n1 0 obj\nendobj\n%%EOF'.codeUnits,
    );
    final signed = receipt(bytes: pdfBytes);
    expect(await store.storeVerified(quote(), signed), isTrue);
    final job = await store.forJob('job-77');
    expect(job, hasLength(1));
    expect(job.single.documentId, 'doc-77');
    expect(job.single.quoteNumber, 'Q-77');
    expect(await store.forJob('job-88'), isEmpty);
    expect(await store.read(job.single), orderedEquals(pdfBytes));

    // Identical re-delivery is idempotent, never adds another record.
    expect(await store.storeVerified(quote(), signed), isTrue);
    expect(await store.forJob('job-77'), hasLength(1));

    final altered = receipt(bytes: Uint8List.fromList('%PDF-DIFFERENT'.codeUnits));
    await expectLater(store.storeVerified(quote(), altered), throwsStateError);
    expect(await store.read(job.single), orderedEquals(pdfBytes));

    // Reopen with a new store instance to verify on-disk indexing.
    final reopened = SignedQuoteFileStore(directoryProvider: () async => root);
    expect(await reopened.forJob('job-77'), hasLength(1));
  });

  test('unsigned and incorrectly linked PDF cannot become signed job file',
      () async {
    final root = await Directory.systemTemp.createTemp('sign2digital_unsigned_');
    addTearDown(() => root.delete(recursive: true));
    final store = SignedQuoteFileStore(directoryProvider: () async => root);
    final goodPdf = Uint8List.fromList('%PDF-1.7\n%%EOF'.codeUnits);
    expect(await store.storeVerified(quote(), receipt()), isFalse);
    await expectLater(
      store.storeVerified(quote(), receipt(bytes: Uint8List.fromList([1, 2, 3]))),
      throwsFormatException,
    );
    await expectLater(
      store.storeVerified(quote(), receipt(bytes: goodPdf, jobId: 'another-job')),
      throwsFormatException,
    );
    await expectLater(
      store.storeVerified(quote(jobId: null), receipt(bytes: goodPdf)),
      throwsFormatException,
    );
    expect(await store.list(), isEmpty);
  });
}
