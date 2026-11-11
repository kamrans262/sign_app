import 'dart:math';

import '../../../core/services/sign_api_client.dart';
import '../../../core/services/active_company_session.dart';
import '../../auth/data/mobile_auth_repository.dart';
import '../domain/subscription_plan.dart';
import 'subscription_overview_repository.dart';

/// Authenticated, company-bound M23 data: no local subscription/status fixture.
class RemoteSubscriptionRepository implements SubscriptionOverviewRepository {
  RemoteSubscriptionRepository({SignApiClient? api})
      : _api = api ?? MobileAuthRepository.shared.api;

  final SignApiClient _api;

  static Map<String, dynamic> _payload(Map<String, dynamic> response) {
    final value = response['data'];
    if (value is! Map<String, dynamic>) {
      throw const SignApiException('Invalid subscription response.');
    }
    return value;
  }

  static Map<String, dynamic> _record(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const SignApiException('Invalid subscription data.');
    }
    return value;
  }

  static int _integer(Object? value) => value is num
      ? value.toInt() : int.tryParse('$value') ?? 0;

  static String? _string(Object? value) => value is String ? value : null;

  Future<Map<String, dynamic>> _get(String endpoint) async {
    final companyId = ActiveCompanySession.companyId;
    if (companyId == null || companyId <= 0) {
      throw const SignApiException('Choose a company to view its subscription.');
    }
    final result = _payload(await _api.get(endpoint, companyScoped: true));
    if (companyId != ActiveCompanySession.companyId) {
      throw const SignApiException('Company changed. Reload subscription information.');
    }
    if (result['company_id'] != null &&
        _integer(result['company_id']) != companyId) {
      throw const SignApiException('Subscription belongs to a different company.');
    }
    return result;
  }

  @override
  Future<SubscriptionOverview> load() async {
    final result = await _get('/api/v1/billing/overview');
    final usage = _record(result['usage']);
    final allowance = _record(result['allowance']);
    final features = result['features'];
    if (features != null && features is! List) {
      throw const SignApiException('Invalid subscription entitlements.');
    }
    final allowed = <SubscriptionFeature>{};
    if (features is List) {
      for (final raw in features) {
        for (final feature in SubscriptionFeature.values) {
          if (feature.name == raw) allowed.add(feature);
        }
      }
    }
    return SubscriptionOverview(
      planName: _string(result['plan_name']),
      status: _string(result['status']),
      priceLabel: _string(result['price_label']),
      billingDescription: _string(result['billing_description']),
      features: features is List ? allowed : null,
      usage: SubscriptionUsage(
        documents: usage['documents'] == null ? null : _integer(usage['documents']),
        clients: usage['clients'] == null ? null : _integer(usage['clients']),
        equipment: usage['equipment'] == null ? null : _integer(usage['equipment']),
      ),
      freeDocumentLimit: _integer(allowance['limit']),
      freeDocumentsRemaining: _integer(allowance['remaining']),
      freeDocumentsUsed: _integer(allowance['used']),
      enforcementEnabled: allowance['enforcement_enabled'] == true,
      canCheckout: result['can_checkout'] == true,
      canManageBilling: result['can_manage_billing'] == true,
      cancelAtPeriodEnd: result['cancel_at_period_end'] == true,
      periodEndsAt: _string(result['period_ends_at']),
      demoOnly: false,
    );
  }

  Future<Map<String, dynamic>> usage() => _get('/api/v1/billing/usage');
  Future<Map<String, dynamic>> history() => _get('/api/v1/billing/history');

  /// Uses device cryptographic randomness, not a timestamp or tenant secret.
  /// The same UUID can be reused for an uncertain Checkout retry.
  static String newRequestId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }

  Future<Map<String, dynamic>> _write(
      String endpoint, Map<String, dynamic> body) async {
    final company = ActiveCompanySession.companyId;
    if (company == null || company < 1) {
      throw const SignApiException('Choose a company before managing billing.');
    }
    final result = _payload(await _api.post(endpoint,
      companyScoped: true, data: body));
    if (ActiveCompanySession.companyId != company ||
        (result['company_id'] != null &&
            _integer(result['company_id']) != company)) {
      throw const SignApiException(
        'Company changed. Refresh billing before continuing.');
    }
    return result;
  }

  static Uri hostedUrl(Object? raw, {bool portal = false}) {
    final uri = raw is String ? Uri.tryParse(raw) : null;
    if (uri == null || uri.scheme != 'https' ||
        uri.host != (portal ? 'billing.stripe.com' : 'checkout.stripe.com') ||
        uri.userInfo.isNotEmpty || uri.hasPort || uri.path.isEmpty) {
      throw const SignApiException('Untrusted Stripe payment destination.');
    }
    return uri;
  }

  Future<M23CheckoutAttempt> startCheckout(int serverPlanId,
      {String? requestId}) async {
    if (serverPlanId < 1) {
      throw const SignApiException('Select a valid published subscription plan.');
    }
    final body = await _write('/api/v1/billing/checkout',{
      'plan_id': serverPlanId,
      'request_id': requestId ?? newRequestId(),
    });
    final intent = _string(body['intent_id']);
    if (intent == null || intent.isEmpty || body['status'] != 'pending') {
      throw const SignApiException('Checkout has not been authorized.');
    }
    return M23CheckoutAttempt(
      intentId: intent, url: hostedUrl(body['checkout_url']));
  }

  Future<M23CheckoutVerification> checkoutStatus(String intentId) async {
    if (intentId.length != 36 ||
        !RegExp(r'^[A-Fa-f0-9-]+').hasMatch(intentId)) {
      throw const SignApiException('Invalid Checkout confirmation reference.');
    }
    final status = await _get('/api/v1/billing/checkout/$intentId/status');
    return M23CheckoutVerification(
      status: _string(status['status']) ?? 'pending',
      verified: status['verified'] == true,
    );
  }

  Future<Uri> portal() async {
    final result = await _write('/api/v1/billing/portal', {});
    return hostedUrl(result['portal_url'], portal: true);
  }

  Future<Map<String, dynamic>> cancel() =>
      _write('/api/v1/billing/cancel', {'confirm': true});

  Future<Map<String, dynamic>> resume() =>
      _write('/api/v1/billing/resume', {'confirm': true});

  Future<Map<String, dynamic>> previewChange(int serverPlanId) =>
      _write('/api/v1/billing/change-preview', {'plan_id': serverPlanId});

  Future<Map<String, dynamic>> changePlan(int serverPlanId,
          {required String requestId}) =>
      _write('/api/v1/billing/change', {
        'plan_id': serverPlanId,
        'request_id': requestId,
        'confirm': true,
        'proration_behavior': 'none',
      });
}

class M23CheckoutAttempt {
  const M23CheckoutAttempt({required this.intentId, required this.url});
  final String intentId;
  final Uri url;
}

class M23CheckoutVerification {
  const M23CheckoutVerification({required this.status,
    required this.verified});
  final String status;
  final bool verified;
}

/// A server catalog is explicitly loaded; samples are never mixed into
/// signed-in plan selection, even when the server returns no plans.
class RemoteSubscriptionPlanCatalog implements SubscriptionPlanCatalog {
  RemoteSubscriptionPlanCatalog({SignApiClient? api})
      : _repo = RemoteSubscriptionRepository(api: api);

  /// Reuse the same company-scoped repository as Subscription Overview.
  RemoteSubscriptionPlanCatalog.fromRepository(this._repo);

  final RemoteSubscriptionRepository _repo;
  List<SubscriptionPlanOption> _options = const [];

  @override
  List<SubscriptionPlanOption> get options => List.unmodifiable(_options);

  Future<void> load() async {
    _options = const [];
    final data = await _repo._get('/api/v1/billing/plans');
    final plans = data['plans'];
    if (plans is! List) {
      throw const SignApiException('Invalid plan catalogue.');
    }
    final parsed = <SubscriptionPlanOption>[];
    for (final item in plans) {
      final row = RemoteSubscriptionRepository._record(item);
      final code = RemoteSubscriptionRepository._string(row['code']);
      final name = RemoteSubscriptionRepository._string(row['name']);
      final price = RemoteSubscriptionRepository._string(row['price_label']);
      final featureLabels = row['feature_labels'];
      final period = switch (row['period']) {
        'monthly' => SubscriptionBillingPeriod.monthly,
        'yearly' => SubscriptionBillingPeriod.yearly,
        _ => null,
      };
      if (code == null || code.isEmpty || name == null || price == null ||
          period == null || featureLabels is! List ||
          featureLabels.any((label) => label is! String)) {
        throw const SignApiException('Invalid configured plan.');
      }
      parsed.add(SubscriptionPlanOption(
        serverPlanId: RemoteSubscriptionRepository._integer(row['id']),
        canCheckout: row['can_checkout'] == true,
        id: code, name: name, period: period, priceLabel: price,
        amountMinor: row['amount_minor'] is num
            ? (row['amount_minor'] as num).toInt() : null,
        currency: RemoteSubscriptionRepository._string(row['currency']),
        description: RemoteSubscriptionRepository._string(row['description']) ?? '',
        featureLabels: List<String>.unmodifiable(featureLabels.cast<String>()),
      ));
    }
    _options = List.unmodifiable(parsed);
  }
}
