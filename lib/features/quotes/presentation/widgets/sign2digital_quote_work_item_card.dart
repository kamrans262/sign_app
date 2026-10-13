import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/quote_review_models.dart';
import 'sign2digital_quote_item_field.dart';

/// Content-sized editable work item. No fixed cell height, no clipped values.
class Sign2DigitalQuoteWorkItemCard extends StatelessWidget {
  const Sign2DigitalQuoteWorkItemCard({
    super.key, required this.item, required this.number,
    required this.currency, required this.onChanged,
  });
  final QuoteReviewWorkItem item;
  final int number;
  final String currency;
  final VoidCallback onChanged;

  Widget _inputRow(List<Widget> children) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < 270) {
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 15),
            children[i],
          ],
        ]);
      }
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(child: children[i]),
        ],
      ]);
    },
  );

  @override
  Widget build(BuildContext context) {
    final invalidQuantity = item.validQuantity == null;
    final invalidPrice = item.priceMinor == null;
    return Column(
      key: ValueKey('quote-work-item-${item.id}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 50, height: 50,
            alignment: Alignment.center,
            decoration: BoxDecoration(shape: BoxShape.circle,
              color: AppColors.white,
              border: Border.all(color: AppColors.lightBorder)),
            child: Text('$number', style: const TextStyle(fontFamily: 'Inter',
              fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.primary))),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            TextFormField(
              key: ValueKey('quote-title-${item.id}'),
              initialValue: item.title, onChanged: (value) {
                item.title = value; onChanged();
              },
              maxLines: null,
              style: const TextStyle(fontFamily: 'Inter', fontSize: 16,
                fontWeight: FontWeight.w600, letterSpacing: -0.3, color: AppColors.dark),
              decoration: const InputDecoration(hintText: 'Item title',
                isDense: true, contentPadding: EdgeInsets.zero,
                border: InputBorder.none),
            ),
            const SizedBox(height: 5),
            TextFormField(
              key: ValueKey('quote-description-${item.id}'),
              initialValue: item.description, onChanged: (value) {
                item.description = value; onChanged();
              },
              maxLines: null, minLines: 1,
              style: const TextStyle(fontFamily: 'Inter', fontSize: 12,
                  fontWeight: FontWeight.w500, color: AppColors.placeholder),
              decoration: const InputDecoration(hintText: 'Description',
                  isDense: true, contentPadding: EdgeInsets.zero,
                  border: InputBorder.none),
            ),
          ])),
        ]),
        const SizedBox(height: 15),
        _inputRow([
          Sign2DigitalQuoteItemField(key: ValueKey('qty-${item.id}'),
            label: 'Quantity', value: item.quantity, numeric: true,
            leadingIcon: Icons.shopping_cart_outlined, missing: invalidQuantity,
            onChanged: (value) { item.quantity = value; onChanged(); }),
          if (item.dimensions != null)
            Sign2DigitalQuoteItemField(key: ValueKey('dims-${item.id}'),
              label: 'Dimensions', value: item.dimensions!,
              leadingIcon: Icons.open_in_full_outlined,
              missing: item.dimensions!.trim().isEmpty,
              onChanged: (value) { item.dimensions = value; onChanged(); })
          else
            Sign2DigitalQuoteItemField(key: ValueKey('price-${item.id}'),
              label: 'Unit Price', value: item.unitPrice, numeric: true,
              missing: invalidPrice,
              onChanged: (value) { item.unitPrice = value; onChanged(); }),
        ]),
        if (item.dimensions != null) ...[
          const SizedBox(height: 15),
          _inputRow([
            Sign2DigitalQuoteItemField(key: ValueKey('price-${item.id}'),
              label: 'Unit Price', value: item.unitPrice, numeric: true,
              missing: invalidPrice,
              onChanged: (value) { item.unitPrice = value; onChanged(); }),
            Sign2DigitalQuoteItemField(key: ValueKey('total-${item.id}-${item.totalMinor}'),
              label: 'Total', value: quoteMoney(item.totalMinor, currency),
              readOnly: true, missing: item.totalMinor == null,
              onChanged: (_) {}),
          ]),
        ],
        if (item.dimensions == null && item.id.startsWith('manual-'))
          Align(alignment: Alignment.centerLeft, child: TextButton.icon(
            onPressed: () { item.dimensions = ''; onChanged(); },
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add dimensions'),
          )),
        for (final entry in item.otherFields.entries) ...[
          const SizedBox(height: 15),
          Sign2DigitalQuoteItemField(
            key: ValueKey('extra-${item.id}-${entry.key}'),
            label: entry.key, value: entry.value,
            missing: entry.value.trim().isEmpty ||
                item.unresolvedOtherFields.contains(entry.key),
            onChanged: (value) {
              item.otherFields[entry.key] = value;
              if (value.trim().isNotEmpty) {
                item.unresolvedOtherFields.remove(entry.key);
              }
              onChanged();
            },
          ),
        ],
      ],
    );
  }
}
