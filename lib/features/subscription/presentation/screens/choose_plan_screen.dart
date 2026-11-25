import '../../../../core/navigation/sign2digital_navigation.dart';
import 'package:flutter/material.dart';

import '../../../auth/data/mobile_auth_repository.dart';
import '../../data/remote_subscription_repository.dart';
import 'subscription_payment_details_screen.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sign2digital_header.dart';
import '../../../../core/widgets/sign2digital_primary_button.dart';
import '../../../clients/presentation/widgets/sign2digital_details_tabs.dart';
import '../../../quotes/presentation/widgets/sign2digital_quote_shadow_panel.dart';
import '../../domain/subscription_plan.dart';
import '../widgets/subscription_feature_list.dart';

/// Second screen of Subscription Overview -> Choose Plan -> Payment Details.
/// Payment Details is intentionally not manufactured while that route is absent.
class ChoosePlanScreen extends StatefulWidget {
  const ChoosePlanScreen({
    super.key,
    this.catalog,
    this.flowState,
    this.onContinue,
    this.billingRepository,
    this.changeExistingPlan = false,
  });

  final SubscriptionPlanCatalog? catalog;
  final SubscriptionPlanFlowState? flowState;
  final ValueChanged<SubscriptionPlanOption>? onContinue;
  final RemoteSubscriptionRepository? billingRepository;
  final bool changeExistingPlan;

  @override
  State<ChoosePlanScreen> createState() => _ChoosePlanScreenState();
}

class _ChoosePlanScreenState extends State<ChoosePlanScreen> {
  late final SubscriptionPlanFlowState _draft;
  late final SubscriptionPlanCatalog _catalog;
  bool _loading = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _draft = widget.flowState ?? SubscriptionPlanFlowState();
    _catalog = widget.catalog ??
        (widget.billingRepository != null
            ? RemoteSubscriptionPlanCatalog.fromRepository(
                widget.billingRepository!)
            : MobileAuthRepository.shared.isSignedIn
                ? RemoteSubscriptionPlanCatalog()
                : const DemoSubscriptionPlanCatalog());
    if (_catalog is RemoteSubscriptionPlanCatalog) _loadPlans();
  }

  Future<void> _loadPlans() async {
    setState(() { _loading = true; _loadError = null; });
    try {
      await (_catalog as RemoteSubscriptionPlanCatalog).load();
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (_) {
      if (!mounted) return;
      setState(() { _loading = false;
        _loadError = 'Unable to load published subscription plans.'; });
    }
  }

  SubscriptionPlanOption? _optionFor(SubscriptionBillingPeriod period) {
    for (final plan in _catalog.options) {
      if (plan.period == period && _draft.selectedPlan?.id == plan.id) return plan;
    }
    for (final plan in _catalog.options) {
      if (plan.period == period) return plan;
    }
    return null;
  }

  SubscriptionPlanOption? get _current => _optionFor(_draft.period);

  String? _yearlySavings(SubscriptionPlanOption plan) {
    if (plan.period != SubscriptionBillingPeriod.yearly ||
        plan.amountMinor == null || plan.currency == null) {
      return null;
    }
    for (final monthly in _catalog.options) {
      if (monthly.id != plan.id ||
          monthly.period != SubscriptionBillingPeriod.monthly ||
          monthly.currency != plan.currency || monthly.amountMinor == null) {
        continue;
      }
      final saved = monthly.amountMinor! * 12 - plan.amountMinor!;
      if (saved <= 0) {
        return null;
      }
      final francs = saved / 100;
      final formatted = francs == francs.roundToDouble()
          ? francs.toStringAsFixed(0) : francs.toStringAsFixed(2);
      return 'Save ${plan.currency} $formatted per year';
    }
    return null;
  }

  bool _isSelected(SubscriptionPlanOption plan) {
    final chosen = _draft.selectedPlan;
    return chosen != null &&
        chosen.id == plan.id && chosen.period == plan.period;
  }

  void _changePeriod(SubscriptionBillingPeriod period) {
    setState(() => _draft.changePeriod(period, _optionFor(period)));
  }

  void _select(SubscriptionPlanOption plan) {
    setState(() => _draft.select(plan));
  }

  void _notice(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  void _continue() {
    final current = _current;
    if (current == null) {
      _notice('No configured plan is available for this billing period.');
      return;
    }
    if (!_isSelected(current)) {
      _notice('Select the ${current.name} to continue.');
      return;
    }
    // Refresh the draft to the catalog value, preserving price and benefits
    // from the selected billing period across any downstream navigation.
    _draft.select(current);
    if (widget.onContinue != null) {
      widget.onContinue!(current);
      return;
    }
    if (current.demoOnly) {
      _notice('Payment Details is not connected yet. Your selection is saved.');
      return;
    }
    Sign2DigitalNavigation.push<void>(context,MaterialPageRoute<void>(
      builder: (_) => SubscriptionPaymentDetailsScreen(
        plan: current,
        repository: widget.billingRepository,
        changeExistingPlan: widget.changeExistingPlan,
      ),
    ));
  }

  static const _sectionStyle = TextStyle(
    fontFamily: 'Inter',
    fontSize: 20,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    color: AppColors.dark,
  );

  @override
  Widget build(BuildContext context) {
    final option = _current;
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          const Sign2DigitalHeader(title: 'Subscription'),
          Expanded(child: Center(child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth:
              MediaQuery.orientationOf(context) == Orientation.landscape
                  ? double.infinity : 720),
            child: ListView(
              key: const Key('choose-plan-scroll'),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              children: [
                Stack(children: [
                  const Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Divider(
                      height: 1,
                      thickness: 1,
                      color: AppColors.lightBorder,
                    ),
                  ),
                  Sign2DigitalDetailsTabs(
                    labels: const ['Monthly', 'Yearly'],
                    horizontalPadding: 15,
                    selectedIndex: _draft.period.index,
                    onSelected: (index) =>
                        _changePeriod(SubscriptionBillingPeriod.values[index]),
                  ),
                ]),
                const SizedBox(height: 20),
                if (_loading)
                  const Center(child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(key: Key('m23-plans-loading')),
                  ))
                else if (_loadError != null)
                  TextButton(key: const Key('m23-plans-retry'),
                    onPressed: _loadPlans, child: Text(_loadError!))
                else if (option == null)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'There is no configured plan for this billing period.',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color: AppColors.placeholder,
                      ),
                    ),
                  )
                else ...[
                  _planCard(option),
                  if (option.demoOnly) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Demo preview · Pricing and benefits are not a payment offer.',
                      key: Key('choose-plan-demo-notice'),
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        color: AppColors.placeholder,
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ))),
        ]),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              child: Sign2DigitalPrimaryButton(
                key: const Key('choose-plan-continue'),
                label: 'Continue',
                height: 48,
                onPressed: _continue,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _planCard(SubscriptionPlanOption plan) {
    final selected = _isSelected(plan);
    return Sign2DigitalQuoteShadowPanel(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            checked: selected,
            inMutuallyExclusiveGroup: true,
            label: '${plan.name}, ${plan.priceLabel}',
            child: InkWell(
              key: const Key('choose-plan-select'),
              borderRadius: BorderRadius.circular(8),
              onTap: () => _select(plan),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(plan.name, style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.3,
                        height: 1.0,
                        color: AppColors.dark,
                      )),
                      const SizedBox(height: 2),
                      Text(plan.priceLabel,
                        key: const Key('choose-plan-price'),
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.3,
                          height: 1.0,
                          color: AppColors.dark,
                        )),
                      if (_yearlySavings(plan) != null) ...[
                        const SizedBox(height: 6),
                        Text(_yearlySavings(plan)!,
                          key: const Key('m23-yearly-savings'),
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          )),
                      ],
                      const SizedBox(height: 5),
                      Text(plan.description, style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        letterSpacing: -0.3,
                        height: 1.0,
                        color: AppColors.placeholder,
                      )),
                    ],
                  )),
                  const SizedBox(width: 8),
                  ExcludeSemantics(child: SizedBox(
                    width: 40,
                    child: RadioGroup<SubscriptionPlanOption>(
                      groupValue: selected ? plan : null,
                      onChanged: (value) {
                        if (value != null) _select(value);
                      },
                      child: Radio<SubscriptionPlanOption>(
                        key: const Key('choose-plan-radio'),
                        value: plan,
                        activeColor: AppColors.primary,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  )),
                ],
              ),
            ),
          ),
          const SizedBox(height: 25),
          const Text('Plan Features', style: _sectionStyle),
          const SizedBox(height: 15),
          SubscriptionFeatureList(
            items: [
              for (final name in plan.featureLabels)
                SubscriptionFeatureItem(label: name),
            ],
          ),
        ],
      ),
    );
  }
}
