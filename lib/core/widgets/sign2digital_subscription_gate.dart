import 'package:flutter/material.dart';

import '../navigation/sign2digital_navigation.dart';
import '../services/sign_api_client.dart';
import '../theme/app_colors.dart';
import '../../features/subscription/presentation/screens/subscription_overview_screen.dart';

/// Offer a safe, explicit route to plans for a verified server 402.
/// Existing documents remain accessible; no automatic checkout is initiated.
abstract final class Sign2DigitalSubscriptionGate {
  static Future<bool> handle(BuildContext context, Object error) async {
    if (error is! SignApiException || error.statusCode != 402 ||
        !context.mounted) {
      return false;
    }
    final viewPlans = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Subscription Required',
            style: TextStyle(color: AppColors.dark)),
        content: const Text(
          'Your current plan\'s document allowance has been reached. '
          'Existing documents remain available to view or edit. '
          'Choose a plan to create or issue more documents.',
          style: TextStyle(color: AppColors.dark),
        ),
        actions: [
          TextButton(
            key: const Key('subscription-required-later'),
            onPressed: () => Navigator.of(dialog).pop(false),
            child: const Text('Keep Editing'),
          ),
          TextButton(
            key: const Key('subscription-required-view-plans'),
            onPressed: () => Navigator.of(dialog).pop(true),
            child: const Text('View Plans'),
          ),
        ],
      ),
    );
    if (viewPlans == true && context.mounted) {
      await Sign2DigitalNavigation.open<void>(
          context, const SubscriptionOverviewScreen());
    }
    return true;
  }
}
