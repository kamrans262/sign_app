import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sign2digital_header.dart';
import '../../data/quote_ui_demo_data.dart';
import '../../domain/quote_document_tracking.dart';
import '../../domain/quote_extraction_models.dart';
import '../../domain/quote_review_models.dart';
import '../../domain/quote_signature_draft.dart';
import 'add_signature_screen.dart';
import 'create_quote_screen.dart';
import 'customer_document_view_screen.dart';
import 'document_signed_success_screen.dart';
import 'in_person_signature_screen.dart';
import 'quote_ai_processing_screen.dart';
import 'quote_preview_screen.dart';
import 'review_quote_screen.dart';
import 'send_quote_screen.dart';
import 'signature_request_screen.dart';

/// Explicitly fictional manual UI tour; nothing is transmitted or signed.
class QuoteUiDemoScreen extends StatelessWidget {
  const QuoteUiDemoScreen({super.key});

  Future<void> _push(BuildContext context, Widget screen) =>
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(builder: (_) => screen),
      );

  Future<void> _openSignature(
      BuildContext context, QuoteReviewDraft quote) async {
    // This callback exists ONLY in the clearly labeled UI demo. It allows
    // exercising the UI without implying a real signing/audit service.
    final draft = await Navigator.of(context).push<QuoteSignatureDraft>(
      MaterialPageRoute<QuoteSignatureDraft>(
        builder: (_) => Banner(
          message: 'UI DEMO',
          location: BannerLocation.topEnd,
          child: AddSignatureScreen(
            quoteId: quote.id,
            documentId: 'demo-document-not-real',
            requestId: 'demo-request-not-real',
            signerId: 'demo-signer-not-verified',
            documentVersion: 'demo-v1',
            consentReference: 'demo-terms',
            termsText: quote.terms,
            onSubmit: (_) async => true, // Local UI exercise only.
          ),
        ),
      ),
    );
    if (!context.mounted || draft == null) return;
    final signer = draft.typedName?.trim().isNotEmpty == true
        ? draft.typedName!.trim() : QuoteUiDemoData.customerName;
    await _push(context, DocumentSignedSuccessScreen(
      data: QuoteSignedDisplayData(
        documentId: draft.documentId,
        quoteNumber: quote.quoteNumber,
        projectName: QuoteUiDemoData.projectName,
        signerName: signer,
        // A screenshot fixture, NEVER the time of an actual signature.
        signedAt: DateTime(2026, 8, 23, 22),
        demoOnly: true,
      ),
    ));
  }

  Widget _inPersonDemo(QuoteReviewDraft quote) => InPersonSignatureScreen(
    quote: quote,
    projectName: QuoteUiDemoData.projectName,
    documentId: 'demo-document-not-real',
    customerSignerId: 'demo-customer-not-verified',
    businessSignerId: 'demo-business-not-verified',
    // Only the explicit UI tour supplies a fictional completion fixture.
    onSubmit: (submission) async => QuoteSignedDisplayData(
      documentId: submission.documentId,
      quoteNumber: quote.quoteNumber,
      projectName: QuoteUiDemoData.projectName,
      signerName: quote.clientName,
      signedAt: DateTime(2026, 8, 23, 22),
      demoOnly: true,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final quote = QuoteUiDemoData.quote();
    final tracking = QuoteDocumentTracking.figmaFixture(quote.id);
    final entries = <(String, String, VoidCallback)>[
      ('Create Quote', 'Try text, voice and image inputs',
          () => _push(context, const CreateQuoteScreen())),
      ('AI Processing', 'Sample UI progress, not an AI response',
          () => _push(context, QuoteAiProcessingScreen(
            initialSnapshot: QuotePreparationSnapshot.figmaPreview,
            demoReviewDraft: quote,
          ))),
      ('Review Quote', 'Edit sample items, prices and terms',
          () => _push(context, ReviewQuoteScreen(initialDraft: quote.copy()))),
      ('Quote Preview', 'Read the sample PDF-ready quote',
          () => _push(context, QuotePreviewScreen(
            quote: quote.copy(),
            onInPersonSign: () => _push(context, _inPersonDemo(quote.copy())),
          ))),
      ('Send Quote', 'Inspect email and share UI; delivery is not confirmed',
          () => _push(context, SendQuoteScreen(quote: quote.copy()))),
      ('Signature Tracking', 'View a sample activity timeline',
          () => _push(context, SignatureRequestScreen(
            quote: quote.copy(), tracking: tracking,
          ))),
      ('Customer Document', 'Tap Review and Sign to test capture and success',
          () => _push(context, CustomerDocumentViewScreen(
            quote: quote.copy(),
            tracking: tracking,
            description: QuoteUiDemoData.projectName,
            demoReviewEnabled: true,
            onReviewAndSign: (draft) => _openSignature(context, draft),
          ))),
      ('Add Signature', 'Try Draw, Type, Upload and Confirm',
          () => _openSignature(context, quote.copy())),
      ('In-Person Signature', 'Capture customer and business signatures separately',
          () => _push(context, _inPersonDemo(quote.copy()))),
      ('Document Signed!', 'Preview the final confirmation screen directly',
          () => _push(context, DocumentSignedSuccessScreen(
            data: QuoteSignedDisplayData(
              documentId: 'demo-document-not-real',
              quoteNumber: quote.quoteNumber,
              projectName: QuoteUiDemoData.projectName,
              signerName: QuoteUiDemoData.customerName,
              signedAt: DateTime(2026, 8, 23, 22),
              demoOnly: true,
            ),
          ))),
    ];
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Sign2DigitalHeader(
              title: 'Quote UI Demo',
              onBack: () => Navigator.of(context).maybePop(),
            ),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: ListView(
                    key: const Key('quote-ui-demo-list'),
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE3ECF0),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'UI DEMO ONLY — Fictional company, prices, '
                          'statuses and signing data. Nothing is sent or '
                          'legally signed.',
                          style: TextStyle(color: AppColors.dark,
                            fontFamily: 'Inter', fontSize: 13),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(QuoteUiDemoData.companyName,
                        style: const TextStyle(fontFamily: 'Inter',
                          fontSize: 20, fontWeight: FontWeight.w700,
                          color: AppColors.dark)),
                      const SizedBox(height: 6),
                      Text('Customer: ${quote.clientName}  •  '
                          '${quote.quoteNumber}  •  '
                          '${QuoteUiDemoData.projectName}',
                        style: const TextStyle(color: AppColors.secondaryText,
                          fontFamily: 'Inter', fontSize: 13)),
                      const SizedBox(height: 18),
                      for (var i = 0; i < entries.length; i++) ...[
                        Card(
                          margin: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: const BorderSide(
                              color: AppColors.lightBorder),
                          ),
                          color: Colors.white,
                          elevation: 0,
                          child: ListTile(
                            key: Key('quote-demo-step-$i'),
                            onTap: entries[i].$3,
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFFE3ECF0),
                              child: Text('${i + 1}',
                                style: const TextStyle(
                                  color: AppColors.primary)),
                            ),
                            title: Text(entries[i].$1,
                              style: const TextStyle(fontFamily: 'Inter',
                                fontSize: 15, fontWeight: FontWeight.w600,
                                color: AppColors.dark)),
                            subtitle: Text(entries[i].$2,
                              style: const TextStyle(fontFamily: 'Inter',
                                fontSize: 12,
                                color: AppColors.secondaryText)),
                            trailing: const Icon(Icons.chevron_right,
                              color: AppColors.primary),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
