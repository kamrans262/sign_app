import 'package:flutter/material.dart';

/// A field is verified only after validation by the supplying service.
enum QuoteExtractionStatus { verified, missing, unclear, needsReview }

enum QuotePreparationStage {
  preparing,
  extracting,
  partial,
  completed,
  failed,
  unavailable,
}

class QuoteExtractedField {
  const QuoteExtractedField({
    required this.id,
    required this.label,
    required this.value,
    required this.status,
    this.iconAsset,
    this.fallbackIcon = Icons.description_outlined,
  });

  final String id;
  final String label;
  final String value;
  final QuoteExtractionStatus status;
  final String? iconAsset;
  final IconData fallbackIcon;
}

/// An AI-suggested work item, never a priced or approved quote line.
class QuotePreparedWorkItem {
  const QuotePreparedWorkItem({
    required this.title,
    required this.description,
    this.quantity,
    this.dimensions,
  });

  final String title;
  final String description;
  final int? quantity;
  final String? dimensions;
}

/// Values and progress belong to the data source; neither is inferred by the UI.
/// progressPercentage == null means progress cannot be measured.
class QuotePreparationSnapshot {
  const QuotePreparationSnapshot({
    required this.stage,
    this.progressPercentage,
    this.fields = const [],
    this.items = const [],
    this.currency,
    this.message,
    this.isDemo = false,
  });

  final QuotePreparationStage stage;
  final double? progressPercentage;
  final List<QuoteExtractedField> fields;
  final List<QuotePreparedWorkItem> items;
  final String? currency;
  final String? message;
  final bool isDemo;

  double? get safeProgress {
    final number = progressPercentage;
    if (number == null || !number.isFinite) return null;
    return number.clamp(0.0, 100.0).toDouble();
  }

  static const unavailable = QuotePreparationSnapshot(
    stage: QuotePreparationStage.unavailable,
    message: 'AI quote generation is not connected yet. Your original input has been preserved.',
  );

  /// ONLY for explicit design preview and widget tests, never as an AI result.
  static const figmaPreview = QuotePreparationSnapshot(
    stage: QuotePreparationStage.partial,
    progressPercentage: 60,
    isDemo: true,
    fields: [
      QuoteExtractedField(id: 'demo-items', label: 'Items', value: '3 windows', status: QuoteExtractionStatus.verified, fallbackIcon: Icons.shopping_cart_outlined),
      QuoteExtractedField(id: 'demo-quantity', label: 'Quantity', value: '3', status: QuoteExtractionStatus.verified, fallbackIcon: Icons.shopping_cart_outlined),
      QuoteExtractedField(id: 'demo-dimensions', label: 'Dimensions', value: '1.2 m + 1.5 m (each)', status: QuoteExtractionStatus.verified, fallbackIcon: Icons.open_in_full_outlined),
      QuoteExtractedField(id: 'demo-installation', label: 'Installation', value: 'Include removal of old windows and all labour', status: QuoteExtractionStatus.verified, fallbackIcon: Icons.layers_outlined),
      QuoteExtractedField(id: 'demo-material-a', label: 'Material Type', value: 'Not specialized', status: QuoteExtractionStatus.missing, fallbackIcon: Icons.notes_outlined),
      QuoteExtractedField(id: 'demo-location', label: 'Location', value: '12 Oak Road, London', status: QuoteExtractionStatus.verified, fallbackIcon: Icons.location_on_outlined, iconAsset: 'assets/icons/address.svg'),
      QuoteExtractedField(id: 'demo-material-b', label: 'Material Type', value: 'Unclear', status: QuoteExtractionStatus.unclear, fallbackIcon: Icons.description_outlined),
    ],
  );
}
