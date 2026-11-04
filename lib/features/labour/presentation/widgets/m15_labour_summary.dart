import 'package:flutter/material.dart';

import '../../../../core/services/active_company_session.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../jobs/presentation/widgets/sign2digital_job_financial_card.dart';
import '../../data/remote_labour_repository.dart';

class M15LabourSummary extends StatefulWidget {
  const M15LabourSummary({
    super.key,required this.jobId,this.asFinancialCard=false,
    this.refreshKey,
  });
  final String jobId;
  final bool asFinancialCard;
  final Object? refreshKey;

  @override
  State<M15LabourSummary> createState()=>_M15LabourSummaryState();
}

class _M15LabourSummaryState extends State<M15LabourSummary> {
  Future<Map<String,dynamic>>? _summary;

  @override
  void initState(){
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant M15LabourSummary oldWidget){
    super.didUpdateWidget(oldWidget);
    if(widget.jobId!=oldWidget.jobId||
        widget.refreshKey!=oldWidget.refreshKey) {
      _load();
    }
  }

  void _load(){
    _summary=ActiveCompanySession.companyId==null?null:
        RemoteLabourRepository.shared.summary(widget.jobId);
  }

  static int? _integer(Object? raw) {
    if(raw==null) {
      return null;
    }
    return raw is int?raw:int.tryParse('$raw');
  }

  static String _money(int? cents) {
    if(cents==null)return 'Not available';
    final absolute=cents.abs();
    final prefix=cents<0?'-':'';
    return '${prefix}CHF ${absolute~/100}.'
      '${(absolute%100).toString().padLeft(2,'0')}';
  }

  @override
  Widget build(BuildContext context){
    final future=_summary;
    if(future==null) {
      return widget.asFinancialCard
        ? const Sign2DigitalJobFinancialCard(
            label:'Labour cost',amountChf:0,showAmount:false,
            icon:Icons.groups_outlined)
        : const SizedBox.shrink();
    }
    return FutureBuilder<Map<String,dynamic>>(
      future:future,builder:(context,state){
        final d=state.data;
        if(widget.asFinancialCard){
          final cost=_integer(d?['approved_labour_cost_minor']);
          return Sign2DigitalJobFinancialCard(
            label:'Labour cost',amountChf:0,
            showAmount:state.hasData&&!state.hasError&&cost!=null,
            amountLabel:cost==null?null:_money(cost),
            icon:Icons.groups_outlined,
            iconAsset:'assets/icons/team_members.svg',
          );
        }
        if(state.hasError) {
          return TextButton(
            key:const Key('m15-summary-retry'),
            onPressed:()=>setState(_load),
            child:const Text('Unable to load job cost summary. Retry.'));
        }
        if(d==null) {
          return const Center(child:CircularProgressIndicator());
        }
        final approved=_integer(d['approved_minutes'])??0;
        final pending=_integer(d['pending_minutes'])??0;
        final actual=_integer(d['overall_actual_cost_minor']);
        return Container(
          key:const Key('m15-labour-summary'),
          padding:const EdgeInsets.all(16),
          decoration:BoxDecoration(
            color:AppColors.white,
            borderRadius:BorderRadius.circular(10),
            border:Border.all(color:AppColors.lightBorder),
          ),
          child:Column(crossAxisAlignment:CrossAxisAlignment.start,
            children:[
              const Text('Job Labour Summary',style:TextStyle(
                fontFamily:'Inter',fontSize:16,fontWeight:FontWeight.w600,
                color:AppColors.dark)),
              const SizedBox(height:12),
              Text('Approved time: ${approved~/60}h ${approved%60}m',
                style:const TextStyle(fontFamily:'Inter',fontSize:14)),
              Text('Pending review: ${pending~/60}h ${pending%60}m',
                style:const TextStyle(fontFamily:'Inter',fontSize:14)),
              const SizedBox(height:8),
              Text('Approved labour: ${_money(_integer(d['approved_labour_cost_minor']))}'),
              Text('Approved purchases: ${_money(_integer(d['approved_purchase_minor']))}'),
              Text('Overall job cost: ${_money(actual)}',
                style:const TextStyle(fontWeight:FontWeight.w600,
                  color:AppColors.primary,fontFamily:'Inter')),
              if((_integer(d['approved_missing_rate_count'])??0)>0)
                const Text('Some approved time has no rate; actual cost is not available.',
                  style:TextStyle(fontFamily:'Inter',fontSize:12,color:AppColors.secondaryText)),
              if((_integer(d['unreconciled_external_labour_expense_minor'])??0)>0)
                Text('External labour invoices ${_money(
                  _integer(d['unreconciled_external_labour_expense_minor']))} '
                  'excluded pending reconciliation.',
                  style:const TextStyle(fontFamily:'Inter',fontSize:12,
                    color:AppColors.secondaryText)),
            ],
          ),
        );
      },
    );
  }
}
