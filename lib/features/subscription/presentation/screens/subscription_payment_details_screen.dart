import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sign2digital_header.dart';
import '../../../../core/widgets/sign2digital_primary_button.dart';
import '../../../quotes/presentation/widgets/sign2digital_quote_shadow_panel.dart';
import '../../domain/subscription_plan.dart';
import '../widgets/subscription_feature_list.dart';

/// Genuine plan review. Stripe-hosted checkout will be wired in M23 Stage 2;
/// Stage 1 never collects card data or reports payment success.
class SubscriptionPaymentDetailsScreen extends StatelessWidget {
  const SubscriptionPaymentDetailsScreen({
    super.key, required this.plan,
  });

  final SubscriptionPlanOption plan;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.white,
    body: SafeArea(bottom: false,child:Column(children:[
      const Sign2DigitalHeader(title:'Payment Details'),
      Expanded(child:Center(child:ConstrainedBox(
        constraints: BoxConstraints(maxWidth:
          MediaQuery.orientationOf(context)==Orientation.landscape
              ? double.infinity : 720),
        child:ListView(
          key:const Key('m23-payment-review-scroll'),
          padding:const EdgeInsets.fromLTRB(20,20,20,30),
          children:[
            Sign2DigitalQuoteShadowPanel(
              padding:const EdgeInsets.all(20),
              child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                const Text('Selected Plan',style:TextStyle(
                  fontFamily:'Inter',fontWeight:FontWeight.w700,
                  fontSize:18,color:AppColors.dark)),
                const SizedBox(height:14),
                Text(plan.name,key:const Key('m23-review-plan-name'),
                  style:const TextStyle(fontFamily:'Inter',fontSize:16,
                    fontWeight:FontWeight.w600,color:AppColors.dark)),
                const SizedBox(height:8),
                Text(plan.priceLabel,key:const Key('m23-review-price'),
                  style:const TextStyle(fontFamily:'Inter',fontSize:20,
                    fontWeight:FontWeight.w600,color:AppColors.primary)),
                const SizedBox(height:12),
                Text(plan.period.label,style:const TextStyle(
                  fontFamily:'Inter',color:AppColors.placeholder)),
                const SizedBox(height:18),
                SubscriptionFeatureList(items:[
                  for(final label in plan.featureLabels)
                    SubscriptionFeatureItem(label:label),
                ]),
              ]),
            ),
            const SizedBox(height:20),
            Sign2DigitalQuoteShadowPanel(
              padding:const EdgeInsets.all(20),
              child:const Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Text('Payment setup is pending',
                  key:Key('m23-stripe-disabled'),
                  style:TextStyle(fontFamily:'Inter',fontSize:16,
                    fontWeight:FontWeight.w600,color:AppColors.dark)),
                SizedBox(height:10),
                Text(
                  'Stripe is not connected yet. No payment details are '
                  'collected, no subscription is activated, and no charge '
                  'will be made. You can review this plan now and complete '
                  'checkout once secure billing is configured.',
                  style:TextStyle(fontFamily:'Inter',fontSize:14,
                    color:AppColors.placeholder)),
              ]),
            ),
          ],
        ),
      ))),
    ])),
    bottomNavigationBar:SafeArea(top:false,child:Center(heightFactor:1,
      child:ConstrainedBox(
        constraints:BoxConstraints(maxWidth:
          MediaQuery.orientationOf(context)==Orientation.landscape
              ? double.infinity : 720),
        child:Padding(padding:const EdgeInsets.fromLTRB(20,10,20,20),
          child:Sign2DigitalPrimaryButton(
            key:const Key('m23-checkout-unavailable'),
            label:'Continue to Secure Checkout',
            enabled:false,onPressed:(){},
          )),
      ),
    )),
  );
}
