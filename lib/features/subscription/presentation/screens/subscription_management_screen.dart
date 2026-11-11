import '../../../../core/navigation/sign2digital_navigation.dart';
import 'package:flutter/material.dart';
import '../../../../core/widgets/sign2digital_styled_bottom_sheet.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/services/active_company_session.dart';
import '../../../auth/data/mobile_auth_repository.dart';
import '../../data/remote_subscription_repository.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sign2digital_bottom_navigation_bar.dart';
import '../../../../core/widgets/sign2digital_header.dart';
import '../../data/subscription_overview_repository.dart';
import '../../domain/subscription_plan.dart';
import '../widgets/subscription_current_plan_card.dart';
import '../widgets/subscription_management_action_card.dart';
import 'choose_plan_screen.dart';

/// Manages an existing subscription without pretending demo status is verified.
/// Payment and billing callbacks are supplied by the future backend integration.
class SubscriptionManagementScreen extends StatefulWidget {
  const SubscriptionManagementScreen({
    super.key,
    this.repository,
    this.flowState,
    this.onPaymentMethod,
    this.onBillingHistory,
    this.onUsage,
    this.onConfirmCancellation,
    this.onNavigationSelected,
  });

  final SubscriptionOverviewRepository? repository;
  final SubscriptionPlanFlowState? flowState;
  final VoidCallback? onPaymentMethod;
  final VoidCallback? onBillingHistory;
  final VoidCallback? onUsage;
  final Future<void> Function(SubscriptionOverview)? onConfirmCancellation;
  final ValueChanged<int>? onNavigationSelected;

  @override
  State<SubscriptionManagementScreen> createState() =>
      _SubscriptionManagementScreenState();
}

class _SubscriptionManagementScreenState
    extends State<SubscriptionManagementScreen> {
  late final SubscriptionOverviewRepository _repository;
  late final SubscriptionPlanFlowState _flowState;
  SubscriptionOverview? _data;
  bool _loading = true;
  bool _cancelling = false;
  String? _error;

  static const _sectionStyle = TextStyle(
    fontFamily: 'Inter',
    fontSize: 20,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    color: AppColors.dark,
  );

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ??
        (MobileAuthRepository.shared.isSignedIn
            ? RemoteSubscriptionRepository()
            : const DemoSubscriptionOverviewRepository());
    if (_repository is RemoteSubscriptionRepository) {
      ActiveCompanySession.selected.addListener(_load);
    }
    _flowState = widget.flowState ?? SubscriptionPlanFlowState();
    _load();
  }

  @override
  void dispose() {
    if (_repository is RemoteSubscriptionRepository) {
      ActiveCompanySession.selected.removeListener(_load);
    }
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() { _loading = true; _error = null; });
    try {
      final value = await _repository.load();
      if (!mounted) return;
      setState(() { _data = value; _loading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _data = null;
        _loading = false;
        _error = 'Unable to load subscription information.';
      });
    }
  }

  void _notice(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _changePlan() async {
    await Sign2DigitalNavigation.push<void>(context,MaterialPageRoute<void>(
      builder: (_) => ChoosePlanScreen(
        flowState: _flowState,
        billingRepository: _repository is RemoteSubscriptionRepository
            ? _repository : null,
        changeExistingPlan: _data?.canManageBilling == true,
      ),
    ));
    if (mounted) await _load();
  }

  Future<void> _paymentMethod() async {
    final handler = widget.onPaymentMethod;
    if (handler != null) { handler(); return; }
    if (_repository is! RemoteSubscriptionRepository ||
        _data?.canManageBilling != true) {
      _notice(_repository is RemoteSubscriptionRepository
          ? 'Stripe payment methods are unavailable until billing is configured.'
          : 'Payment Method is not connected yet.');
      return;
    }
    try {
      final url=await _repository.portal();
      if(!mounted)return;
      final opened=await launchUrl(url,mode:LaunchMode.externalApplication);
      if(!opened)throw const FormatException('Secure portal not opened.');
      if(mounted)_notice('Billing Portal opened. Refresh to verify updates.');
    }catch(_){
      if(mounted)_notice('Secure billing portal is currently unavailable.');
    }
  }

  Future<void> _billingHistory() async {
    final handler = widget.onBillingHistory;
    if (handler != null) { handler(); return; }
    if (_repository is! RemoteSubscriptionRepository) {
      _notice('Subscription billing history is not connected yet.');
      return;
    }
    try {
      final result = await _repository.history();
      if (!mounted) return;
      final records = result['invoices'];
      if (records is! List) throw const FormatException();
      await showSign2DigitalBottomSheet<void>(context: context, useSafeArea: true,
        builder: (sheet) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
          child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Billing History', style: _sectionStyle),
              const SizedBox(height: 18),
              if (records.isEmpty)
                const Text('No verified subscription invoices yet.',
                  key: Key('m23-no-billing-history'),
                  style: TextStyle(color: AppColors.placeholder))
              else
                for (final record in records.take(15))
                  Padding(padding: const EdgeInsets.only(bottom: 10),
                    child: Text(_billingLine(record))),
            ]),
        ),
      );
    } catch (_) {
      _notice('Unable to load verified billing history.');
    }
  }

  String _billingLine(Object? record) {
    if (record is! Map<String, dynamic>) return 'Invalid billing record';
    final amount = record['amount_due_minor'];
    final currency = record['currency'] ?? '';
    final status = record['status'] ?? 'unknown';
    if (amount is! num) return 'Billing record unavailable';
    return '$currency ${(amount / 100).toStringAsFixed(2)} · $status';
  }

  void _usage() {
    final handler = widget.onUsage;
    if (handler != null) { handler(); return; }
    final data = _data;
    if (data == null) return;
    final usage = data.usage;

    showSign2DigitalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (sheet) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
        child: Column(mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(data.demoOnly ? 'Usage This Month' : 'Document & Company Usage',
            style: _sectionStyle),
          const SizedBox(height: 20),
          _usageLine('Documents', usage.documents),
          if (!data.demoOnly) const Text(
            'Document creations are counted for your account. '
            'Client and equipment totals belong to the company.',
            style: TextStyle(fontFamily:'Inter',fontSize:12,
              color:AppColors.dark),
          ),
          const SizedBox(height: 12),
          _usageLine('Clients', usage.clients),
          const SizedBox(height: 12),
          _usageLine('Equipments', usage.equipment),
          if (data.freeDocumentLimit != null) ...[
            const SizedBox(height:12),
            _usageLine('Free documents remaining', data.freeDocumentsRemaining),
            if (!data.enforcementEnabled) const Text(
              'Subscription quotas are not enforced yet.',
              style: TextStyle(fontFamily:'Inter',fontSize:12,
                color:AppColors.placeholder)),
          ],
          if (data.demoOnly) ...[
            const SizedBox(height: 16),
            const Text('Demo preview · Usage values are samples.',
              style: TextStyle(
                fontFamily: 'Inter', fontSize: 12,
                color: AppColors.placeholder)),
          ],
        ]),
      ),
    );
  }

  Widget _usageLine(String label, int? value) => Row(
    children: [
      Expanded(child: Text(label, style: const TextStyle(
        fontFamily: 'Inter', fontSize: 14,
        fontWeight: FontWeight.w500, color: AppColors.dark))),
      Text(value?.toString() ?? 'Unavailable', style: const TextStyle(
        fontFamily: 'Inter', fontSize: 14,
        fontWeight: FontWeight.w500, color: AppColors.placeholder)),
    ],
  );

  bool get _isFreePlan => !(_data?.demoOnly ?? false) &&
      const {'free', 'granted'}.contains(_data?.status?.toLowerCase());

  bool get _hasBillingHistory {
    if (_data == null || _isFreePlan) return false;
    return _data!.demoOnly ||
        const {'active', 'trialing', 'past_due', 'unpaid', 'canceled'}
            .contains(_data?.status?.toLowerCase());
  }

  // A free allowance, administrative grant or unverified provider state
  // is not a paid subscription that the user can cancel.
  bool get _canCancelSubscription {
    final current = _data;
    if (current == null || !current.canManageBilling) return false;
    return const {'active', 'trialing', 'past_due', 'unpaid'}
        .contains(current.status?.toLowerCase().trim());
  }

  Future<void> _cancelSubscription() async {
    if (_cancelling || !_canCancelSubscription) return;
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Cancel Subscription?'),
        content: const Text(
          'Cancellation will be requested for the end of your billing '
          'period. No cancellation is applied unless Stripe confirms it. '
          'Do you want to proceed?'),
        actions: [
          TextButton(
            key: const Key('subscription-keep-plan'),
            onPressed: () => Navigator.of(dialog).pop(false),
            child: const Text('Keep Plan'),
          ),
          TextButton(
            key: const Key('subscription-confirm-cancel'),
            onPressed: () => Navigator.of(dialog).pop(true),
            child: const Text('Confirm Cancellation'),
          ),
        ],
      ),
    );
    if (approved != true || !mounted) return;
    final callback = widget.onConfirmCancellation;
    if (callback == null && _repository is! RemoteSubscriptionRepository) {
      _notice('Cancellation is not connected. No changes were made.');
      return;
    }
    setState(() => _cancelling = true);
    try {
      if (callback != null) {
        await callback(_data!);
      } else if (_data!.canManageBilling) {
        await (_repository as RemoteSubscriptionRepository).cancel();
      } else {
        _notice('Stripe cancellation is unavailable. No changes were made.');
        return;
      }
      if (mounted) await _load();
    } catch (_) {
      _notice('Cancellation request could not be completed.');
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  Future<void> _resumeSubscription() async {
    if (_cancelling || !_canCancelSubscription ||
        _repository is! RemoteSubscriptionRepository ||
        _data?.cancelAtPeriodEnd != true) {
      return;
    }
    setState(()=>_cancelling=true);
    try {
      await _repository.resume();
      if(mounted)await _load();
    }catch(_){
      if(mounted)_notice('Unable to resume cancellation. Confirm in Stripe Billing.');
    }finally {
      if(mounted)setState(()=>_cancelling=false);
    }
  }

  void _navigation(int index) {
    if (index == 4) {
      Navigator.of(context).maybePop();
      return;
    }
    final callback = widget.onNavigationSelected;
    if (callback == null) {
      _notice('Navigation is not connected yet.');
      return;
    }
    Navigator.of(context).popUntil((route) => route.isFirst);
    callback(index);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.white,
    body: SafeArea(bottom: false, child: Column(children: [
      const Sign2DigitalHeader(title: 'Subscription'),
      Expanded(child: Center(child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth:
          MediaQuery.orientationOf(context) == Orientation.landscape
              ? double.infinity : 720),
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            key: const Key('subscription-management-scroll'),
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            children: [
              if (_loading)
                const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Center(child: CircularProgressIndicator(
                    key: Key('subscription-management-loading'))))
              else if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Center(child: TextButton(
                    key: const Key('subscription-management-retry'),
                    onPressed: _load,
                    child: Text('$_error Tap to retry.'))))
              else if (_data != null) ...[
                const Text('Current Plan', style: _sectionStyle),
                const SizedBox(height: 10),
                SubscriptionCurrentPlanCard(
                  key: const Key('subscription-management-plan-card'),
                  data: _data!,
                  variant: SubscriptionPlanCardVariant.management,
                ),
                const SizedBox(height: 20),
                SubscriptionManagementActionCard(
                  key: const Key('subscription-action-change-plan'),
                  title: _isFreePlan ? 'Upgrade Plan' : 'Change Plan',
                  subtitle: _isFreePlan
                      ? 'Explore Business monthly and yearly'
                      : 'Upgrade or downgrade your plan',
                  icon: Icons.swap_horiz_rounded,
                  onTap: _changePlan,
                ),
                if (_data!.canManageBilling || _data!.demoOnly) ...[
                  const SizedBox(height: 20),
                  SubscriptionManagementActionCard(
                    key: const Key('subscription-action-payment-method'),
                    title: 'Payment Method',
                    subtitle: 'Update your card or bank details',
                    icon: Icons.credit_card_outlined,
                    onTap: _paymentMethod,
                  ),
                ],
                if (_hasBillingHistory) ...[
                  const SizedBox(height: 20),
                  SubscriptionManagementActionCard(
                    key: const Key('subscription-action-billing-history'),
                    title: 'Billing History',
                    subtitle: 'View and download verified invoices',
                    icon: Icons.receipt_long_outlined,
                    onTap: _billingHistory,
                  ),
                ],
                const SizedBox(height: 20),
                SubscriptionManagementActionCard(
                  key: const Key('subscription-action-usage'),
                  title: 'Usage',
                  subtitle: 'See your current plan usage',
                  icon: Icons.format_list_bulleted_rounded,
                  onTap: _usage,
                ),
                if (_canCancelSubscription) ...[
                  const SizedBox(height: 20),
                  SubscriptionManagementActionCard(
                    key: const Key('subscription-action-cancel'),
                    title: _data!.cancelAtPeriodEnd
                        ? 'Cancellation Scheduled' : 'Cancel Subscription',
                    subtitle: _data!.cancelAtPeriodEnd
                        ? 'Access continues until your verified period ends'
                        : 'Cancel at the end of the billing period',
                    icon: Icons.cancel_outlined,
                    onTap: _cancelling ? () {} : (_data!.cancelAtPeriodEnd
                        ? _resumeSubscription : _cancelSubscription),
                  ),
                ],
              ],
            ],
          ),
        ),
      ))),
    ])),
    bottomNavigationBar: Sign2DigitalBottomNavigationBar(
      selectedIndex: 4,
      onSelected: _navigation,
    ),
  );
}
