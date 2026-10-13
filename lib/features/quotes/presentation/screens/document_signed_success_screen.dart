import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sign2digital_outlined_container.dart';
import '../../../../core/widgets/sign2digital_primary_button.dart';
import '../widgets/sign2digital_animated_success.dart';

/// Display data: production callers must supply trusted signing/audit details.
class QuoteSignedDisplayData {
  const QuoteSignedDisplayData({
    required this.documentId,
    required this.quoteNumber,
    required this.projectName,
    required this.signerName,
    required this.signedAt,
    this.ipAddress,
    this.demoOnly = false,
  });

  final String documentId;
  final String quoteNumber;
  final String projectName;
  final String signerName;
  final DateTime signedAt;
  final String? ipAddress;
  final bool demoOnly;
}

class DocumentSignedSuccessScreen extends StatelessWidget {
  const DocumentSignedSuccessScreen({
    super.key,
    required this.data,
    this.onViewSignedDocument,
    this.onClose,
  });

  final QuoteSignedDisplayData data;
  final VoidCallback? onViewSignedDocument;
  final VoidCallback? onClose;

  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  String get _signedTime {
    final date = data.signedAt.toLocal();
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    return '${_months[date.month - 1]} ${date.day}, ${date.year} '
        '$hour:${date.minute.toString().padLeft(2, '0')} '
        "${date.hour >= 12 ? 'PM' : 'AM'}";
  }

  static const _valueStyle = TextStyle(
    fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w500,
    letterSpacing: -0.3, color: AppColors.dark,
  );
  static const _labelStyle = TextStyle(
    fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w500,
    letterSpacing: -0.3, color: AppColors.placeholder,
  );

  Widget _detailRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 110, child: Text(label, style: _labelStyle)),
        const SizedBox(width: 8),
        Expanded(child: Text(value, style: _valueStyle, softWrap: true)),
      ],
    ),
  );

  Widget _detailsCard() => Sign2DigitalOutlinedContainer(
    child: Column(
      children: [
        _detailRow('Signed By:', data.signerName),
        const Divider(height: 1, thickness: 1, color: AppColors.lightBorder),
        _detailRow('Date and Time:', _signedTime),
        const Divider(height: 1, thickness: 1, color: AppColors.lightBorder),
        _detailRow('IP address:', data.ipAddress?.trim().isNotEmpty == true
            ? data.ipAddress! : 'Not available'),
      ],
    ),
  );

  Widget _quoteCard() => Sign2DigitalOutlinedContainer(
    padding: const EdgeInsets.all(20),
    child: Row(
      children: [
        Container(
          width: 40, height: 40,
          decoration: const BoxDecoration(
            shape: BoxShape.circle, color: Color(0xFFE3ECF0),
          ),
          child: const Icon(
            Icons.description_outlined, color: AppColors.dark, size: 23,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Quote # ${data.quoteNumber}', style: const TextStyle(
                fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w600,
                letterSpacing: -0.3, color: AppColors.dark,
              )),
              const SizedBox(height: 5),
              Text(data.projectName, style: const TextStyle(
                fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w500,
                color: AppColors.placeholder,
              )),
            ],
          ),
        ),
      ],
    ),
  );

  void _viewDocument(BuildContext context) {
    if (onViewSignedDocument != null) {
      onViewSignedDocument!();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(data.demoOnly
            ? 'UI demo only: no real signed PDF exists. Use Quote Preview to inspect the sample quote.'
            : 'Signed PDF is not available yet. Please try again later.'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, viewport) => SingleChildScrollView(
          key: const Key('signed-success-scroll'),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 720, minHeight: viewport.maxHeight,
              ),
              child: IntrinsicHeight(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 50, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(child: Sign2DigitalAnimatedSuccess()),
                      const SizedBox(height: 20),
                      const Text('Document Signed!', textAlign: TextAlign.center,
                        style: TextStyle(fontFamily: 'Inter', fontSize: 24,
                          fontWeight: FontWeight.w700, color: AppColors.dark)),
                      const SizedBox(height: 10),
                      const Text(
                        'Thank you. Your signatures have been successfully added to the document',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontFamily: 'Inter', fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.secondaryText),
                      ),
                      if (data.demoOnly) ...[
                        const SizedBox(height: 12),
                        const Text(
                          'UI DEMO ONLY — no document has actually been signed.',
                          key: Key('signed-success-demo-notice'),
                          textAlign: TextAlign.center,
                          style: TextStyle(fontFamily: 'Inter', fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary),
                        ),
                      ],
                      const SizedBox(height: 20),
                      _quoteCard(),
                      const SizedBox(height: 20),
                      _detailsCard(),
                      const Spacer(),
                      const SizedBox(height: 40),
                      Sign2DigitalPrimaryButton(
                        label: 'View Signed Document',
                        onPressed: () => _viewDocument(context),
                      ),
                      const SizedBox(height: 15),
                      SizedBox(
                        height: 48,
                        child: OutlinedButton(
                          onPressed: onClose ??
                              () => Navigator.of(context).maybePop(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text('Close', style: TextStyle(
                            fontFamily: 'Inter', fontSize: 16,
                            fontWeight: FontWeight.w500,
                          )),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
