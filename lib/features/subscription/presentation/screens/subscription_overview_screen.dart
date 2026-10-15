import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/sign2digital_bottom_navigation_bar.dart';
import '../../../../core/widgets/sign2digital_dashboard_header.dart';
import '../../../../core/widgets/sign2digital_outlined_button.dart';
import '../../../../core/widgets/sign2digital_primary_button.dart';
import '../../../clients/presentation/widgets/sign2digital_status_badge.dart';
import '../../../quotes/presentation/widgets/sign2digital_quote_shadow_panel.dart';
import '../../data/subscription_overview_repository.dart';
import '../../domain/subscription_plan.dart';
import '../widgets/subscription_feature_list.dart';
import 'choose_plan_screen.dart';

/// Subscription module entry point. Manage Plan opens Choose Plan;
/// Payment Details remains a separate upcoming feature.
class SubscriptionOverviewScreen extends StatefulWidget {
  const SubscriptionOverviewScreen({
    super.key,
    this.repository,
    this.onViewBilling,
    this.onManagePlan,
    this.onViewUsage,
    this.onNavigationSelected,
    this.onNotificationTap,
    this.onProfileTap,
  });

  final SubscriptionOverviewRepository? repository;
  final VoidCallback? onViewBilling;
  final VoidCallback? onManagePlan;
  final VoidCallback? onViewUsage;
  final ValueChanged<int>? onNavigationSelected;
  final VoidCallback? onNotificationTap;
  final VoidCallback? onProfileTap;

  @override
  State<SubscriptionOverviewScreen> createState() =>
      _SubscriptionOverviewScreenState();
}

class _SubscriptionOverviewScreenState
    extends State<SubscriptionOverviewScreen> {
  late final SubscriptionOverviewRepository _repository;
  SubscriptionOverview? _overview;
  bool _loading = true;
  String? _error;
  final SubscriptionPlanFlowState _planDraft = SubscriptionPlanFlowState();

  Future<void> _openManagePlan() async {
    await Navigator.of(context).push<void>(MaterialPageRoute<void>(
      builder: (_) => ChoosePlanScreen(flowState: _planDraft),
    ));
  }

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? const DemoSubscriptionOverviewRepository();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final value = await _repository.load();
      if (!mounted) return;
      setState(() { _overview = value; _loading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _overview = null;
        _error = 'Subscription information could not be loaded.';
        _loading = false;
      });
    }
  }

  void _unavailable(String action) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('$action is not connected yet.'),
      ));
  }

  void _onNavigation(int index) {
    if (index == 4) {
      Navigator.of(context).maybePop();
      return;
    }
    final onSelected = widget.onNavigationSelected;
    if (onSelected == null) {
      _unavailable('Navigation');
      return;
    }
    Navigator.of(context).maybePop();
    onSelected(index);
  }

  static const _sectionStyle = TextStyle(
    fontFamily: 'Inter',
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: AppColors.dark,
    letterSpacing: -0.3,
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.white,
    body: SafeArea(
      bottom: false,
      child: Column(children: [
        Sign2DigitalDashboardHeader(
          onNotificationTap: widget.onNotificationTap ??
              () => _unavailable('Notifications'),
          onProfileTap: widget.onProfileTap ??
              () => _unavailable('Profile'),
        ),
        Expanded(child: Center(child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              key: const Key('subscription-scroll'),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              children: [
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: Center(child: CircularProgressIndicator(
                      key: Key('subscription-loading'),
                    )),
                  )
                else if (_error != null)
                  Center(child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 30),
                    child: TextButton(
                      key: const Key('subscription-retry'),
                      onPressed: _load,
                      child: Text('$_error Tap to retry.'),
                    ),
                  ))
                else if (_overview != null) ...[
                  _currentPlan(_overview!),
                  const SizedBox(height: 20),
                  const Text('Plan Features', style: _sectionStyle),
                  const SizedBox(height: 20),
                  if (_overview!.features == null)
                    const Text('Plan features are unavailable.',
                      style: AppTextStyles.subtitle)
                  else
                    SubscriptionFeatureList(items: [
                      for (final feature in SubscriptionFeature.values)
                        SubscriptionFeatureItem(
                          label: feature.label,
                          included: _overview!.features!.contains(feature),
                        ),
                    ]),
                  const SizedBox(height: 20),
                  Row(children: [
                    const Expanded(child: Text('Usage This Month',
                      style: _sectionStyle)),
                    TextButton(
                      key: const Key('subscription-view-details'),
                      onPressed: widget.onViewUsage ??
                          () => _unavailable('Usage details'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 40),
                      ),
                      child: const Text('View Details',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w500,
                          color: AppColors.primary,
                          fontSize: 14,
                        )),
                    ),
                  ]),
                  const SizedBox(height: 20),
                  Row(children: [
                    Expanded(child: _usageCard(
                      key: const Key('subscription-usage-documents'),
                      icon: Icons.description_outlined,
                      value: _overview!.usage.documents,
                      label: 'Documents',
                    )),
                    const SizedBox(width: 15),
                    Expanded(child: _usageCard(
                      key: const Key('subscription-usage-clients'),
                      icon: Icons.people_outline_rounded,
                      value: _overview!.usage.clients,
                      label: 'Clients',
                    )),
                    const SizedBox(width: 15),
                    Expanded(child: _usageCard(
                      key: const Key('subscription-usage-equipment'),
                      icon: Icons.build_outlined,
                      value: _overview!.usage.equipment,
                      label: 'Equipments',
                    )),
                  ]),
                ],
              ],
            ),
          ),
        ))),
      ]),
    ),
    bottomNavigationBar: Sign2DigitalBottomNavigationBar(
      selectedIndex: 4,
      onSelected: _onNavigation,
    ),
  );

  Widget _currentPlan(SubscriptionOverview data) =>
      Sign2DigitalQuoteShadowPanel(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Current Plan', style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.3,
                    color: AppColors.dark,
                  )),
                  const SizedBox(height: 2),
                  Text(data.planName ?? 'Plan unavailable',
                    key: const Key('subscription-plan-name'),
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.3,
                      color: AppColors.dark,
                    )),
                  const SizedBox(height: 7),
                  Text(data.priceLabel ?? 'Price unavailable',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.placeholder,
                    )),
                  const SizedBox(height: 4),
                  Text(data.billingDescription ?? 'Billing date unavailable',
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
            const SizedBox(height: 25),
            Row(children: [
              Expanded(child: Sign2DigitalOutlinedButton(
                key: const Key('subscription-view-billing'),
                label: 'View Billing',
                primaryOutline: true,
                onPressed: widget.onViewBilling ??
                    () => _unavailable('Billing'),
              )),
              const SizedBox(width: 10),
              Expanded(child: Sign2DigitalPrimaryButton(
                key: const Key('subscription-manage-plan'),
                label: 'Manage Plan',
                height: 52,
                onPressed: widget.onManagePlan ?? _openManagePlan,
              )),
            ]),
            if (data.demoOnly) ...[
              const SizedBox(height: 12),
              const Text(
                'Demo preview · Sample subscription and usage; no billing connected.',
                key: Key('subscription-demo-notice'),
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  color: AppColors.placeholder,
                ),
              ),
            ],
          ],
        ),
      );

  Widget _usageCard({
    required Key key,
    required IconData icon,
    required int? value,
    required String label,
  }) => Sign2DigitalQuoteShadowPanel(
    key: key,
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 16),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 24, color: AppColors.primary),
      const SizedBox(height: 10),
      Text(value?.toString() ?? '—', style: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppColors.dark,
      )),
      const SizedBox(height: 6),
      FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(label, maxLines: 1, style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.placeholder,
        )),
      ),
    ]),
  );
}
