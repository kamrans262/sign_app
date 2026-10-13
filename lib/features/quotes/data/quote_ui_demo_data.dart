import '../domain/quote_review_models.dart';

/// Fictional UI-only quote data. It does not represent an actual customer,
/// service-generated quote, verified signature or document delivery.
abstract final class QuoteUiDemoData {
  static const companyName = 'Northstar Renovations GmbH';
  static const projectName = 'Kitchen Renovation';
  static const customerName = 'Jean Dupont';

  static QuoteReviewDraft quote() => QuoteReviewDraft(
    id: 'ui-demo-kitchen-renovation',
    clientId: 'demo-client-1',
    clientName: customerName,
    quoteNumber: 'Q-2900',
    date: DateTime(2026, 8, 20),
    validUntil: DateTime(2026, 9, 20),
    currency: 'CHF',
    billingAddress: 'Sample Street 12, 8000 Zürich, Switzerland',
    clientEmail: 'jean.dupont@example.com',
    clientPhone: '+41 79 000 00 00',
    vatBasisPoints: 810,
    depositBasisPoints: 3000,
    isDemo: true,
    approvedLocally: true,
    terms: 'UI DEMO ONLY. Sample prices are illustrative. No contractual '
        'agreement, actual delivery, or electronic signature is created.',
    items: [
      QuoteReviewWorkItem(
        id: 'demo-kitchen-cabinets',
        title: 'Kitchen cabinetry installation',
        description: 'Fit and level base and wall cabinets',
        quantity: '1', unitPrice: '2450.00',
      ),
      QuoteReviewWorkItem(
        id: 'demo-worktop', title: 'Worktop installation',
        description: 'Measure, cut and install worktop',
        quantity: '1', unitPrice: '1250.00',
      ),
      QuoteReviewWorkItem(
        id: 'demo-finishing', title: 'Finishing works',
        description: 'Seal edges and clean the installation area',
        quantity: '1', unitPrice: '350.00',
      ),
    ],
  );
}
