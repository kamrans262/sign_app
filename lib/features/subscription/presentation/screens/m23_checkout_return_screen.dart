import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sign2digital_header.dart';
import '../../../../core/widgets/sign2digital_primary_button.dart';
import '../../data/remote_subscription_repository.dart';
import '../../services/m23_billing_deep_links.dart';
import 'subscription_overview_screen.dart';

/// Payment is verified from Stripe through the authenticated Laravel API;
/// browser success/cancel alone never activates an entitlement.
class M23CheckoutReturnScreen extends StatefulWidget {
  const M23CheckoutReturnScreen({
    super.key,
    required this.result,
    this.repository,
  });

  final M23BillingReturn result;
  final RemoteSubscriptionRepository? repository;

  @override
  State<M23CheckoutReturnScreen> createState() =>
      _M23CheckoutReturnScreenState();
}

class _M23CheckoutReturnScreenState
    extends State<M23CheckoutReturnScreen> {
  late final RemoteSubscriptionRepository _repository;
  bool _verifying = false;
  bool _verified = false;
  String _message = '';

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? RemoteSubscriptionRepository();
    if (widget.result.kind == M23BillingReturnKind.success) {
      _message = 'Verifying your Checkout with Stripe...';
      WidgetsBinding.instance.addPostFrameCallback((_) => _verify());
    } else if (widget.result.kind == M23BillingReturnKind.cancel) {
      _message = 'Checkout was canceled. No payment has been confirmed.';
    } else {
      _message = 'You are back in Sign2Digital. Review your subscription to see the latest billing status.';
    }
  }

  Future<void> _verify() async {
    final intent = widget.result.intentId;
    if (_verifying || intent == null) return;
    setState(() {
      _verifying = true;
      _message = 'Checking the payment directly with Stripe...';
    });
    try {
      final verified = await _repository.checkoutStatus(intent);
      if (!mounted) return;
      setState(() {
        _verified = verified.verified;
        _message = verified.verified
            ? 'Subscription verified. Your account now uses the provider-confirmed plan.'
            : 'Payment is not confirmed yet (${verified.status}). '
              'If you completed Checkout, try Verify Again.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _message = 'Could not verify the payment yet. No paid access has '
          'been granted from the browser return. Check your connection '
          'and choose Verify Again.';
      });
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  void _openSubscription() {
    Navigator.of(context).pushReplacement<void, void>(MaterialPageRoute<void>(
      builder: (_) => const SubscriptionOverviewScreen(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final label = _verified ? 'Subscription Verified'
        : widget.result.kind == M23BillingReturnKind.cancel
          ? 'Checkout Canceled'
          : widget.result.kind == M23BillingReturnKind.portal
            ? 'Billing Return'
            : 'Payment Verification';
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          const Sign2DigitalHeader(title: 'Subscription'),
          Expanded(child: Center(child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                CircleAvatar(
                  radius: 29,
                  backgroundColor: const Color(0xFFE3ECF0),
                  child: Icon(
                    _verified ? Icons.check_circle_outline_rounded
                        : widget.result.kind == M23BillingReturnKind.cancel
                          ? Icons.close_rounded : Icons.verified_user_outlined,
                    color: AppColors.primary, size: 30,
                  ),
                ),
                const SizedBox(height: 20),
                Text(label, key: const Key('m23-return-title'),
                  style: const TextStyle(fontFamily: 'Inter',fontSize: 20,
                    fontWeight: FontWeight.w700,color: AppColors.dark)),
                const SizedBox(height: 10),
                Text(_message, key: const Key('m23-return-message'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontFamily: 'Inter',fontSize: 14,
                    fontWeight: FontWeight.w500,color: AppColors.placeholder)),
                if (_verifying) ...[
                  const SizedBox(height: 18),
                  const CircularProgressIndicator(color: AppColors.primary),
                ],
                if (!_verifying && !_verified &&
                    widget.result.intentId != null) ...[
                  const SizedBox(height: 12),
                  TextButton(
                    key: const Key('m23-return-verify-again'),
                    onPressed: _verify,
                    child: const Text('Verify Again'),
                  ),
                ],
              ]),
            ),
          ))),
        ]),
      ),
      bottomNavigationBar: SafeArea(top:false,
        child: Padding(padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: Center(heightFactor:1, child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Sign2DigitalPrimaryButton(
              key: const Key('m23-return-view-subscription'),
              label: 'View Subscription',
              enabled: !_verifying,
              onPressed: _openSubscription,
            ),
          )),
        ),
      ),
    );
  }
}
