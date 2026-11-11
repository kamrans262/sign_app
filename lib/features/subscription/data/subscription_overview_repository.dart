/// A subscription is only verified when supplied by the connected service.
/// The app currently has no billing backend; the demo fixture is clearly marked.
enum SubscriptionFeature {
  unlimitedProjects('Unlimited projects & job management'),
  clientManagement('Client management'),
  quotes('Quotes & approvals'),
  aiDocuments('AI document generation'),
  siteReports('Site reports & meeting minutes'),
  eSignature('eSignatures & work acceptance'),
  invoices('Invoices & deposits'),
  expenses('Purchases & expense tracking'),
  labour('Time & labour tracking'),
  equipment('Equipment management'),
  reminders('Reminders & global search'),
  emailSupport('Email support');

  const SubscriptionFeature(this.label);
  final String label;
}

class SubscriptionUsage {
  const SubscriptionUsage({this.documents, this.clients, this.equipment});

  /// Null means the metric was not supplied, not zero.
  final int? documents;
  final int? clients;
  final int? equipment;
}

class SubscriptionOverview {
  const SubscriptionOverview({
    this.planName,
    this.status,
    this.priceLabel,
    this.billingDescription,
    this.features,
    this.usage = const SubscriptionUsage(),
    this.freeDocumentLimit,
    this.freeDocumentsUsed,
    this.freeDocumentsRemaining,
    this.enforcementEnabled = false,
    this.canCheckout = false,
    this.canManageBilling = false,
    this.cancelAtPeriodEnd = false,
    this.periodEndsAt,
    this.demoOnly = false,
  });

  final String? planName;
  final String? status;
  final String? priceLabel;
  final String? billingDescription;

  /// Null means entitlements are unknown; an empty set means none are granted.
  final Set<SubscriptionFeature>? features;
  final SubscriptionUsage usage;
  final int? freeDocumentLimit;
  final int? freeDocumentsUsed;
  final int? freeDocumentsRemaining;
  final bool enforcementEnabled;
  final bool canCheckout;
  final bool canManageBilling;
  final bool cancelAtPeriodEnd;
  final String? periodEndsAt;

  /// Every preview-only billing field and statistic must be identified as demo.
  final bool demoOnly;
}

abstract class SubscriptionOverviewRepository {
  Future<SubscriptionOverview> load();
}

/// Figma preview, not a payment, paid account, or actual entitlement record.
/// Replace by injecting a backend repository into SubscriptionOverviewScreen.
class DemoSubscriptionOverviewRepository
    implements SubscriptionOverviewRepository {
  const DemoSubscriptionOverviewRepository();

  @override
  Future<SubscriptionOverview> load() async => const SubscriptionOverview(
    planName: 'Professional',
    status: 'Active',
    priceLabel: 'CHF 49 / month',
    billingDescription: 'Billed monthly · Renews on 15 Sep 2026',
    features: {
      SubscriptionFeature.unlimitedProjects,
      SubscriptionFeature.aiDocuments,
      SubscriptionFeature.eSignature,
      SubscriptionFeature.invoices,
      SubscriptionFeature.labour,
      SubscriptionFeature.equipment,
      SubscriptionFeature.reminders,
      SubscriptionFeature.emailSupport,
    },
    // Design-only Figma usage examples, not backend statistics.
    usage: SubscriptionUsage(documents: 24, clients: 8, equipment: 5),
    demoOnly: true,
  );
}
