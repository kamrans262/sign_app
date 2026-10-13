import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/quote_extraction_models.dart';

class Sign2DigitalExtractedInfoRow extends StatelessWidget {
  const Sign2DigitalExtractedInfoRow({super.key, required this.field});

  final QuoteExtractedField field;

  static const Color warning = Color(0xFFE6A23C);

  // AI-suggested rows are not verified, but they are also not missing data.
  // Reserve amber warnings for missing/unclear information only.
  bool get _isWarning => field.status == QuoteExtractionStatus.missing ||
      field.status == QuoteExtractionStatus.unclear;

  bool get _isSuggested => field.status == QuoteExtractionStatus.needsReview;

  @override
  Widget build(BuildContext context) {
    final accent = _isWarning ? warning
        : _isSuggested ? AppColors.primary : AppColors.dark;
    return Semantics(
      container: true,
      label: '${field.label}: ${field.value}, ${field.status.name}',
      child: Container(
        key: Key('quote-extracted-row-${field.id}'),
        color: _isWarning ? warning.withAlpha(26) : AppColors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        child: LayoutBuilder(builder: (context, constraints) {
          final available = constraints.maxWidth;
          final narrow = available < 265;
          final label = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: 16, height: 16, child: field.iconAsset == null
                  ? Icon(field.fallbackIcon, size: 16, color: accent)
                  : SvgPicture.asset(field.iconAsset!, width: 16, height: 16,
                      colorFilter: ColorFilter.mode(accent, BlendMode.srcIn),
                      errorBuilder: (context, error, stackTrace) =>
                          Icon(field.fallbackIcon, size: 16, color: accent))),
              const SizedBox(width: 10),
              Flexible(child: Text(field.label,
                  style: TextStyle(fontFamily: 'Inter', fontSize: 14,
                      fontWeight: FontWeight.w500, height: 1.25, color: accent))),
            ],
          );
          final value = Text(field.value.isNotEmpty ? field.value : '—',
            style: const TextStyle(fontFamily: 'Inter', fontSize: 14,
                fontWeight: FontWeight.w500, height: 1.3,
                color: AppColors.placeholder));
          final stateIcon = _isWarning
              ? const Tooltip(
                  message: 'Missing or unclear detail',
                  child: Icon(Icons.account_circle_outlined,
                    key: Key('quote-field-missing'), color: warning, size: 24),
                )
              : _isSuggested
                  ? const Tooltip(
                      message: 'AI extracted - not yet approved; confirm in Review Quote',
                      child: CircleAvatar(
                        key: Key('quote-field-ai-extracted'), radius: 12,
                        backgroundColor: AppColors.primary,
                        child: Icon(Icons.check, size: 17, color: Colors.white)),
                    )
                  : const Tooltip(
                      message: 'Verified by the supplying service',
                      child: CircleAvatar(radius: 12,
                        backgroundColor: AppColors.primary,
                        child: Icon(Icons.check, size: 17,
                          color: Colors.white)),
                    );
          if (narrow) {
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [label, const SizedBox(height: 8), value])),
              const SizedBox(width: 10),
              stateIcon,
            ]);
          }
          final labelWidth = (available * .37).clamp(104.0, 148.0);
          return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            SizedBox(width: labelWidth, child: label),
            const SizedBox(width: 10),
            Expanded(child: value),
            const SizedBox(width: 12),
            stateIcon,
          ]);
        }),
      ),
    );
  }
}
