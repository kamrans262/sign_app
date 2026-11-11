import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sign2digital_outlined_button.dart';
import '../../../../core/widgets/sign2digital_primary_button.dart';
import '../../../clients/presentation/widgets/sign2digital_status_badge.dart';
import '../../../quotes/presentation/widgets/sign2digital_quote_shadow_panel.dart';
import '../../data/subscription_overview_repository.dart';

/// Shared Current Plan surface across Overview and Subscription Management.
/// The management variation omits the overview actions, not the shared card.
enum SubscriptionPlanCardVariant { overview, management }

class SubscriptionCurrentPlanCard extends StatelessWidget {
  const SubscriptionCurrentPlanCard({
    super.key,
    required this.data,
    this.variant = SubscriptionPlanCardVariant.overview,
    this.onViewBilling,
    this.onManagePlan,
  });

  final SubscriptionOverview data;
  final SubscriptionPlanCardVariant variant;
  final VoidCallback? onViewBilling;
  final VoidCallback? onManagePlan;

  @override
  Widget build(BuildContext context) {
    final management = variant == SubscriptionPlanCardVariant.management;
    final isFree = !data.demoOnly &&
        const {'free', 'granted'}.contains(data.status?.toLowerCase());
    final description = data.billingDescription ?? 'Billing details unavailable';
    final billingLines = management
        ? description.split(' · ')
        : <String>[description];

    return Sign2DigitalQuoteShadowPanel(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!management) ...[
                  const Text('Current Plan', style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.3,
                    color: AppColors.dark,
                  )),
                  const SizedBox(height: 2),
                ],
                Text(data.planName ?? 'Plan unavailable',
                  key: const Key('subscription-plan-name'),
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: management ? 14 : 18,
                    fontWeight: management ? FontWeight.w500 : FontWeight.w600,
                    letterSpacing: -0.3,
                    color: AppColors.dark,
                  )),
                SizedBox(height: management ? 2 : 7),
                Text(data.priceLabel ?? (isFree ? 'Free' : 'Price unavailable'),
                  key: const Key('subscription-plan-price'),
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: management ? 18 : 14,
                    fontWeight: management ? FontWeight.w600 : FontWeight.w500,
                    letterSpacing: management ? -0.3 : null,
                    color: management ? AppColors.dark : AppColors.placeholder,
                  )),
                SizedBox(height: management ? 5 : 4),
                for (final line in billingLines)
                  Text(line,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.placeholder,
                    )),
              ],
            )),
            const SizedBox(width: 8),
            Sign2DigitalStatusBadge(
              key: const Key('subscription-status'),
              status: data.status ?? 'Unknown',
            ),
          ]),
          if (!management) ...[
            const SizedBox(height: 25),
            Row(children: [
              Expanded(child: Sign2DigitalOutlinedButton(
                key: const Key('subscription-view-billing'),
                label: isFree ? 'Plan Details' : 'View Billing',
                primaryOutline: true,
                onPressed: onViewBilling ?? () {},
              )),
              const SizedBox(width: 10),
              Expanded(child: Sign2DigitalPrimaryButton(
                key: const Key('subscription-manage-plan'),
                label: isFree ? 'Upgrade Plan' : 'Manage Plan',
                height: 52,
                onPressed: onManagePlan ?? () {},
              )),
            ]),
          ],
          if (data.demoOnly) ...[
            const SizedBox(height: 12),
            Text(
              management
                  ? 'Demo preview · Subscription data is not verified billing information.'
                  : 'Demo preview · Sample subscription and usage; no billing connected.',
              key: const Key('subscription-demo-notice'),
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                color: AppColors.placeholder,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
