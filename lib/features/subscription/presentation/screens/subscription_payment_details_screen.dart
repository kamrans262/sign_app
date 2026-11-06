import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sign2digital_header.dart';
import '../../../../core/widgets/sign2digital_primary_button.dart';
import '../../../quotes/presentation/widgets/sign2digital_quote_shadow_panel.dart';
import '../../data/remote_subscription_repository.dart';
import '../../domain/subscription_plan.dart';
import '../widgets/subscription_feature_list.dart';

/// M23 Stripe-hosted payment review. Flutter NEVER collects credit cards,
/// treats a redirect as payment, or fabricates paid entitlement.
class SubscriptionPaymentDetailsScreen extends StatefulWidget {
  const SubscriptionPaymentDetailsScreen({
    super.key, required this.plan, this.repository,
    this.browserLauncher, this.changeExistingPlan = false,
  });

  final SubscriptionPlanOption plan;
  final RemoteSubscriptionRepository? repository;
  final Future<bool> Function(Uri)? browserLauncher;
  final bool changeExistingPlan;

  @override
  State<SubscriptionPaymentDetailsScreen> createState() =>
      _SubscriptionPaymentDetailsScreenState();
}

class _SubscriptionPaymentDetailsScreenState
    extends State<SubscriptionPaymentDetailsScreen> {
  late final RemoteSubscriptionRepository _repository;
  String? _requestId;
  String? _error;
  String? _status;
  bool _opened = false;
  bool _working = false;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? RemoteSubscriptionRepository();
  }

  Future<bool> _open(Uri url) =>
      widget.browserLauncher?.call(url) ??
      launchUrl(url, mode: LaunchMode.externalApplication);

  Future<void> _proceed() async {
    final planId=widget.plan.serverPlanId;
    if (_working || !widget.plan.canCheckout || planId==null || planId<1) {
      return;
    }
    setState(() { _working=true; _error=null; });
    try {
      if (widget.changeExistingPlan) {
        final preview=await _repository.previewChange(planId);
        if (!mounted) return;
        final amount=preview['amount_due_minor'];
        final currency=preview['currency'];
        if (amount is! num || currency is! String) {
          throw const FormatException('Provider preview was incomplete.');
        }
        final confirm=await showDialog<bool>(context:context,
          builder:(dialog)=>AlertDialog(
            title:const Text('Confirm Plan Change'),
            content:Text('Stripe estimates $currency '
                '${(amount/100).toStringAsFixed(2)} due for this change. '
                'Proration is disabled. Your provider may require an '
                'additional payment before activating the new plan.'),
            actions:[
              TextButton(onPressed:()=>Navigator.of(dialog).pop(false),
                child:const Text('Keep Current Plan')),
              TextButton(key:const Key('m23-confirm-plan-change'),
                onPressed:()=>Navigator.of(dialog).pop(true),
                child:const Text('Confirm Change')),
            ],
          ),
        );
        if(confirm!=true || !mounted)return;
        _requestId ??= RemoteSubscriptionRepository.newRequestId();
        final result=await _repository.changePlan(
            planId,requestId:_requestId!);
        if(!mounted)return;
        setState(()=>_status='Stripe plan change request: '
            '${result['status']??'pending'}. '
            'Only verified billing updates can change access.');
      } else {
        _requestId ??= RemoteSubscriptionRepository.newRequestId();
        final attempt=await _repository.startCheckout(
          planId,requestId:_requestId);
        if(!mounted)return;
        _requestId=attempt.intentId;
        final opened=await _open(attempt.url);
        if(!mounted)return;
        if(!opened){
          throw const FormatException('Secure Stripe Checkout did not open.');
        }
        setState(() {
          _opened=true;
          _status='Checkout opened securely in your browser. '
              'After returning, verify the payment status below.';
        });
      }
    } catch (_) {
      if(!mounted)return;
      setState(()=>_error='Unable to complete the billing request. '
          'No payment or plan change has been confirmed.');
    } finally {
      if(mounted)setState(()=>_working=false);
    }
  }

  Future<void> _verify() async {
    final intent=_requestId;
    if(intent==null || !_opened || _working)return;
    setState(() { _working=true; _error=null; });
    try {
      final response=await _repository.checkoutStatus(intent);
      if(!mounted)return;
      setState(()=>_status=response.verified
          ? 'Provider verified subscription: ${response.status}.'
          : 'Payment is not confirmed yet (${response.status}). '
            'You can check again after completing Stripe Checkout.');
      // Keep screen visible with explicit provider-confirmed result.
    } catch (_) {
      if(!mounted)return;
      setState(()=>_error='Unable to verify Checkout yet. '
          'Your subscription has not been marked active in the app.');
    } finally {
      if(mounted)setState(()=>_working=false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled=widget.plan.canCheckout &&
        widget.plan.serverPlanId!=null &&
        widget.plan.serverPlanId!>0;
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(bottom:false,child:Column(children:[
        const Sign2DigitalHeader(title:'Payment Details'),
        Expanded(child:Center(child:ConstrainedBox(
          constraints:BoxConstraints(maxWidth:
            MediaQuery.orientationOf(context)==Orientation.landscape
                ? double.infinity:720),
          child:ListView(
            key:const Key('m23-payment-review-scroll'),
            padding:const EdgeInsets.fromLTRB(20,20,20,30),
            children:[
              Sign2DigitalQuoteShadowPanel(
                padding:const EdgeInsets.all(20),
                child:Column(crossAxisAlignment:CrossAxisAlignment.start,
                  children:[
                    const Text('Selected Plan',style:TextStyle(
                      fontFamily:'Inter',fontWeight:FontWeight.w700,
                      fontSize:18,color:AppColors.dark)),
                    const SizedBox(height:14),
                    Text(widget.plan.name,key:const Key('m23-review-plan-name'),
                      style:const TextStyle(fontFamily:'Inter',fontSize:16,
                        fontWeight:FontWeight.w600,color:AppColors.dark)),
                    const SizedBox(height:8),
                    Text(widget.plan.priceLabel,key:const Key('m23-review-price'),
                      style:const TextStyle(fontFamily:'Inter',fontSize:20,
                        fontWeight:FontWeight.w600,color:AppColors.primary)),
                    const SizedBox(height:12),
                    Text(widget.plan.period.label,style:const TextStyle(
                      fontFamily:'Inter',color:AppColors.placeholder)),
                    const SizedBox(height:18),
                    SubscriptionFeatureList(items:[
                      for(final label in widget.plan.featureLabels)
                        SubscriptionFeatureItem(label:label),
                    ]),
                ]),
              ),
              const SizedBox(height:20),
              Sign2DigitalQuoteShadowPanel(
                padding:const EdgeInsets.all(20),
                child:Column(crossAxisAlignment:CrossAxisAlignment.start,
                  children:[
                    Text(enabled
                        ? (widget.changeExistingPlan
                            ? 'Review plan change' : 'Secure Stripe Checkout')
                        : 'Payment setup is pending',
                      key:const Key('m23-stripe-disabled'),
                      style:const TextStyle(fontFamily:'Inter',fontSize:16,
                        fontWeight:FontWeight.w600,color:AppColors.dark)),
                    const SizedBox(height:10),
                    Text(enabled
                      ? (widget.changeExistingPlan
                          ? 'Review the Stripe billing preview and explicitly '
                            'confirm before changing the subscription.'
                          : 'You will enter payment details only on the '
                            'official Stripe Checkout page. Returning to '
                            'the app does not confirm payment.')
                      : 'Stripe is not connected yet. No payment details are '
                        'collected, no subscription is activated, and no '
                        'charge will be made. You can review this plan now '
                        'and complete checkout once billing is configured.',
                      style:const TextStyle(fontFamily:'Inter',fontSize:14,
                        color:AppColors.placeholder)),
                ]),
              ),
              if(_status!=null)...[
                const SizedBox(height:20),
                Text(_status!,key:const Key('m23-provider-status'),
                  style:const TextStyle(fontFamily:'Inter',fontSize:14,
                    color:AppColors.dark)),
              ],
              if(_error!=null)...[
                const SizedBox(height:20),
                Text(_error!,key:const Key('m23-billing-error'),
                  style:const TextStyle(fontFamily:'Inter',fontSize:14,
                    color:AppColors.placeholder)),
              ],
              if(_opened)...[
                const SizedBox(height:12),
                TextButton(
                  key:const Key('m23-verify-checkout'),
                  onPressed:_working?null:_verify,
                  child:const Text('Verify Payment Status'),
                ),
              ],
            ],
          ),
        ))),
      ])),
      bottomNavigationBar:SafeArea(top:false,child:Center(heightFactor:1,
        child:ConstrainedBox(
          constraints:BoxConstraints(maxWidth:
            MediaQuery.orientationOf(context)==Orientation.landscape
                ? double.infinity:720),
          child:Padding(padding:const EdgeInsets.fromLTRB(20,10,20,20),
            child:Sign2DigitalPrimaryButton(
              key:const Key('m23-checkout-unavailable'),
              label:widget.changeExistingPlan
                  ? 'Review and Confirm Plan Change'
                  : 'Continue to Secure Checkout',
              enabled:enabled && !_working,
              loading:_working,
              onPressed:_proceed,
            )),
        ),
      )),
    );
  }
}
