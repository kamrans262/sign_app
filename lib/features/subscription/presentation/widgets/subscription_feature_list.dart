import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sign2digital_checkbox.dart';

class SubscriptionFeatureItem {
  const SubscriptionFeatureItem({required this.label, this.included = true});

  final String label;
  final bool included;
}

/// Read-only entitlement display reused by Subscription Overview and Choose Plan.
/// Uses the global check control from Generate AI Document.
class SubscriptionFeatureList extends StatelessWidget {
  const SubscriptionFeatureList({super.key, required this.items});

  final List<SubscriptionFeatureItem> items;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var i = 0; i < items.length; i++) ...[
        Semantics(
          label: '${items[i].label}: '
              '${items[i].included ? "included" : "not included"}',
          child: Row(children: [
            ExcludeSemantics(child: IgnorePointer(
              child: Sign2DigitalCheckbox(
                value: items[i].included,
                onChanged: (_) {},
                showLabel: false,
                boxSize: 16,
              ),
            )),
            const SizedBox(width: 10),
            Expanded(child: Text(
              items[i].label,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.placeholder,
              ),
            )),
          ]),
        ),
        if (i < items.length - 1) const SizedBox(height: 15),
      ],
    ],
  );
}
