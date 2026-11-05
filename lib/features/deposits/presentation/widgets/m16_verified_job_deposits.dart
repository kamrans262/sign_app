import 'package:flutter/material.dart';

import '../../../../core/services/active_company_session.dart';
import '../../../jobs/presentation/widgets/sign2digital_job_financial_card.dart';
import '../../data/remote_deposit_repository.dart';

/// Server-confirmed deposit money only: pending and refunded funds are excluded.
class M16VerifiedJobDeposits extends StatefulWidget {
  const M16VerifiedJobDeposits({super.key,required this.jobId});
  final int jobId;
  @override
  State<M16VerifiedJobDeposits> createState()=>_M16VerifiedJobDepositsState();
}

class _M16VerifiedJobDepositsState extends State<M16VerifiedJobDeposits> {
  Future<Map<String,dynamic>>? _result;
  int? _company;
  @override
  void initState(){
    super.initState();
    _company=ActiveCompanySession.companyId;
    ActiveCompanySession.selected.addListener(_companyChanged);
    _refresh();
  }
  @override
  void didUpdateWidget(covariant M16VerifiedJobDeposits old){
    super.didUpdateWidget(old);
    if(old.jobId!=widget.jobId)_refresh();
  }
  void _companyChanged(){
    if(!mounted||_company==ActiveCompanySession.companyId)return;
    setState((){
      _company=ActiveCompanySession.companyId;
      _refresh();
    });
  }
  void _refresh(){
    _result=ActiveCompanySession.companyId==null?null:
      RemoteDepositRepository.shared.jobSummary(widget.jobId);
  }
  @override
  void dispose(){
    ActiveCompanySession.selected.removeListener(_companyChanged);
    super.dispose();
  }
  @override
  Widget build(BuildContext context){
    final request=_result;
    if(request==null){
      return const Sign2DigitalJobFinancialCard(
        label:'Deposits',amountChf:0,showAmount:false,
        icon:Icons.savings_outlined);
    }
    return FutureBuilder<Map<String,dynamic>>(
      key:ValueKey('m16-deposits-'+_company.toString()+'-'+widget.jobId.toString()),
      future:request,builder:(context,snapshot){
        final row=snapshot.connectionState==ConnectionState.done?
          snapshot.data:null;
        final amount=row?['net_received_minor'];
        final cents=amount is int?amount:int.tryParse('$amount');
        final valid=snapshot.hasData&&!snapshot.hasError&&
            cents!=null&&cents>=0;
        final label=valid?'CHF '+(cents/100).toStringAsFixed(2):null;
        return Sign2DigitalJobFinancialCard(
          label:'Deposits',amountChf:0,
          showAmount:valid,amountLabel:label,
          icon:Icons.savings_outlined);
      },
    );
  }
}
