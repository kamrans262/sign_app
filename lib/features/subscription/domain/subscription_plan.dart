import '../data/subscription_overview_repository.dart';

enum SubscriptionBillingPeriod { monthly, yearly }

extension SubscriptionBillingPeriodLabel on SubscriptionBillingPeriod {
  String get label => switch (this) {
    SubscriptionBillingPeriod.monthly => 'Monthly',
    SubscriptionBillingPeriod.yearly => 'Yearly',
  };
}

/// A quoted plan option, not an active subscription or confirmed purchase.
/// Production implementations must supply actual configured price and benefits.
class SubscriptionPlanOption {
  const SubscriptionPlanOption({
    required this.id,
    required this.name,
    required this.period,
    required this.priceLabel,
    required this.description,
    required this.featureLabels,
    this.demoOnly = false,
    this.serverPlanId,
    this.canCheckout = false,
  });

  final String id;
  final String name;
  final SubscriptionBillingPeriod period;
  final String priceLabel;
  final String description;
  final List<String> featureLabels;
  final bool demoOnly;
  /// Numeric published plan ID verified by Laravel; never a hardcoded price.
  final int? serverPlanId;
  final bool canCheckout;
}

/// Plans can later be loaded from the billing catalog without changing UI.
abstract class SubscriptionPlanCatalog {
  List<SubscriptionPlanOption> get options;
}

/// Figma-only prices/benefits; this catalog does NOT represent a payment offer.
class DemoSubscriptionPlanCatalog implements SubscriptionPlanCatalog {
  const DemoSubscriptionPlanCatalog();

  @override
  List<SubscriptionPlanOption> get options => [
    SubscriptionPlanOption(
      id: 'business',
      name: 'Business Plan',
      period: SubscriptionBillingPeriod.monthly,
      priceLabel: 'CHF 20 / month',
      description: 'Perfect for you to getting started',
      featureLabels: [
        for (final feature in SubscriptionFeature.values) feature.label,
      ],
      demoOnly: true,
    ),
    SubscriptionPlanOption(
      id: 'business',
      name: 'Business Plan',
      period: SubscriptionBillingPeriod.yearly,
      // Isolated Figma preview data; replace with backend-configured price.
      priceLabel: 'CHF 200 / year',
      description: 'Perfect for you to getting started',
      featureLabels: [
        for (final feature in SubscriptionFeature.values) feature.label,
        'Priority customer support',
        'Advanced reports & analytics',
        'Additional document storage',
        'Extended AI usage benefits',
      ],
      demoOnly: true,
    ),
  ];
}

/// Keep the draft when navigating Overview ↔ Choose Plan ↔ Payment Details.
/// No purchase, subscription activation or payment is recorded here.
class SubscriptionPlanFlowState {
  SubscriptionBillingPeriod period = SubscriptionBillingPeriod.monthly;
  SubscriptionPlanOption? selectedPlan;

  void changePeriod(SubscriptionBillingPeriod next,
      SubscriptionPlanOption? nextOption) {
    final previous = selectedPlan;
    period = next;
    if (previous != null) {
      selectedPlan = nextOption != null && nextOption.id == previous.id
          ? nextOption
          : null;
    }
  }

  void select(SubscriptionPlanOption plan) {
    period = plan.period;
    selectedPlan = plan;
  }
}
