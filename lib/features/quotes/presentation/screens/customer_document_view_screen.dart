import 'package:flutter/material.dart';

import '../../domain/quote_document_tracking.dart';
import '../../domain/quote_review_models.dart';
import '../../domain/quote_signature_draft.dart';
import 'add_signature_screen.dart';
import 'document_signed_success_screen.dart';
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
    this.documentTitle = 'Invoice',
    this.onReviewAndSign,
    this.signingContext,
    this.onSubmitSignature,
    this.onSubmitVerifiedSignature,
    this.onVerifiedSignature,
    this.demoReviewEnabled = false,
  });

  final QuoteReviewDraft quote;
  final QuoteDocumentTracking? tracking;
  final String? description;
  /// Customer-facing document card label; independently customizable.
  final String documentTitle;
  final Future<void> Function(QuoteReviewDraft quote)? onReviewAndSign;
  final QuoteSigningContext? signingContext;
  final Future<bool> Function(QuoteSignatureDraft draft)? onSubmitSignature;
  /// Trusted service must return actual signed-document/audit details.
  /// Null means submission was not confirmed; never infer success locally.
  final Future<QuoteSignedDisplayData?> Function(QuoteSignatureDraft draft)?
      onSubmitVerifiedSignature;
  /// Called only after the trusted service's confirmation is validated.
  final ValueChanged<QuoteSignedDisplayData>? onVerifiedSignature;
  final bool demoReviewEnabled;

  Future<void> _openAddSignature(
    BuildContext context,
    QuoteReviewDraft draft,
  ) async {
    final requestId = tracking?.requestId;
    final signer = signingContext;
    if (requestId == null) return;

    QuoteSignedDisplayData? verifiedResult;
    Future<bool> submitVerified(QuoteSignatureDraft submitted) async {
      // Submission and signer/document authorization live in the connected
      // service, never in the local UI or inferred from a request URL.
      final result = await onSubmitVerifiedSignature!(submitted);
      if (result == null ||
          result.documentId != signer!.documentId ||
          result.quoteNumber != draft.quoteNumber ||
          (result.demoOnly && !draft.isDemo)) {
        return false;
      }
      verifiedResult = result;
      return true;
    }

    final submitted = await Navigator.of(context).push<QuoteSignatureDraft>(
      MaterialPageRoute<QuoteSignatureDraft>(
        builder: (_) => AddSignatureScreen(
          quoteId: draft.id,
          documentId: signer?.documentId ?? draft.id,
          requestId: requestId,
          signerId: signer?.signerId ?? '',
          documentVersion: signer?.documentVersion ?? '',
          consentReference: signer?.consentReference ?? '',
          termsText: draft.terms,
          onSubmit: signer == null
              ? null
              : onSubmitVerifiedSignature != null
                  ? submitVerified
                  : onSubmitSignature,
          // The external customer route never exposes business navigation.
          showBusinessNavigation: false,
        ),
      ),
    );
    if (!context.mounted || submitted == null || verifiedResult == null) {
      return;
    }
    onVerifiedSignature?.call(verifiedResult!);
    if (!context.mounted) return;
    await Navigator.of(context).push<void>(MaterialPageRoute<void>(
      builder: (_) => DocumentSignedSuccessScreen(data: verifiedResult!),
    ));
  }

  @override
  Widget build(BuildContext context) => QuotePreviewScreen(
    quote: quote,
    tracking: tracking,
    customerView: true,
    documentTitle: documentTitle,
    description: description,
    onReviewAndSign: onReviewAndSign ?? (draft) => _openAddSignature(context, draft),
    demoReviewEnabled: demoReviewEnabled,
  );
}
