import 'package:flutter/material.dart';

import '../../domain/quote_document_tracking.dart';
import '../../domain/quote_review_models.dart';
import '../../domain/quote_signature_draft.dart';
import 'add_signature_screen.dart';
import 'quote_preview_screen.dart';

/// Context obtained from a trusted, authorized signing-request service.
/// The Flutter application does not establish authorization by itself.
class QuoteSigningContext {
  const QuoteSigningContext({
    required this.documentId,
    required this.signerId,
    required this.documentVersion,
    required this.consentReference,
  });

  final String documentId;
  final String signerId;
  final String documentVersion;
  final String consentReference;
}

/// Reuses the Quote Preview document in read-only customer mode.
/// The signing screen opens for a valid active request, but it cannot submit
/// until an authorized identity/document-version context is supplied.
/// It never creates a signing success event locally.
class CustomerDocumentViewScreen extends StatelessWidget {
  const CustomerDocumentViewScreen({
    super.key,
    required this.quote,
    this.tracking,
    this.description,
    this.documentTitle = 'Quote',
    this.onReviewAndSign,
    this.signingContext,
    this.onSubmitSignature,
  });

  final QuoteReviewDraft quote;
  final QuoteDocumentTracking? tracking;
  final String? description;
  /// Set to 'Invoice' only for an actual invoice or isolated Figma fixture.
  final String documentTitle;
  final Future<void> Function(QuoteReviewDraft quote)? onReviewAndSign;
  final QuoteSigningContext? signingContext;
  final Future<bool> Function(QuoteSignatureDraft draft)? onSubmitSignature;

  Future<void> _openAddSignature(BuildContext context, QuoteReviewDraft draft) async {
    final requestId = tracking?.requestId;
    final signer = signingContext;
    if (requestId == null) return;
    await Navigator.of(context).push<QuoteSignatureDraft>(
      MaterialPageRoute<QuoteSignatureDraft>(
        builder: (_) => AddSignatureScreen(
          quoteId: draft.id,
          documentId: signer?.documentId ?? draft.id,
          requestId: requestId,
          signerId: signer?.signerId ?? '',
          documentVersion: signer?.documentVersion ?? '',
          consentReference: signer?.consentReference ?? '',
          termsText: draft.terms,
          onSubmit: signer == null ? null : onSubmitSignature,
          // External customer signing links never show business navigation.
          showBusinessNavigation: false,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => QuotePreviewScreen(
    quote: quote,
    tracking: tracking,
    customerView: true,
    documentTitle: documentTitle,
    description: description,
    onReviewAndSign: onReviewAndSign ?? (draft) => _openAddSignature(context, draft),
  );
}
