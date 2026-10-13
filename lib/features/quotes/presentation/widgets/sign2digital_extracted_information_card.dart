import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import 'sign2digital_quote_shadow_panel.dart';
import '../../domain/quote_extraction_models.dart';
import 'sign2digital_extracted_info_row.dart';

class Sign2DigitalExtractedInformationCard extends StatelessWidget {
  const Sign2DigitalExtractedInformationCard({super.key, required this.fields});

  final List<QuoteExtractedField> fields;

  @override
  Widget build(BuildContext context) {
    return Sign2DigitalQuoteShadowPanel(
      key: const Key('quote-extracted-information-card'),
      clip: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 18, 20, 12),
          child: Text('Extracted Information', style: TextStyle(
            fontFamily: 'Inter', fontSize: 18, fontWeight: FontWeight.w600,
            letterSpacing: -0.3, color: AppColors.dark,
          )),
        ),
        if (fields.isEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Text('No extracted details are available yet.',
              style: TextStyle(fontFamily: 'Inter', fontSize: 14,
                color: AppColors.placeholder)),
          )
        else
          for (var i = 0; i < fields.length; i++) ...[
            if (i > 0) const Divider(
              height: 1, thickness: 1, color: AppColors.lightBorder),
            Sign2DigitalExtractedInfoRow(key: ValueKey(fields[i].id),
                field: fields[i]),
          ],
      ]),
    );
  }
}
