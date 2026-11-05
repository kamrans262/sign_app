import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sign2digital_header.dart';
import '../../../../core/widgets/sign2digital_information_table.dart';
import '../../../../core/widgets/sign2digital_outlined_button.dart';
import '../../../../core/widgets/sign2digital_primary_button.dart';
import '../../domain/equipment_loan_record.dart';

/// Original Q62: immutable loan history, confirmed return and extension.
class EquipmentLoanDetailsScreen extends StatefulWidget {
  const EquipmentLoanDetailsScreen({super.key,
    required this.loan,required this.repository});
  final EquipmentLoanRecord loan;
  final EquipmentLoanRepository repository;
  @override
  State<EquipmentLoanDetailsScreen> createState()=>
      _EquipmentLoanDetailsScreenState();
}

class _EquipmentLoanDetailsScreenState
    extends State<EquipmentLoanDetailsScreen> {
  late EquipmentLoanRecord _record;
  bool _loading=true,_busy=false;
  String? _error;
  @override
  void initState(){
    super.initState();
    _record=widget.loan;
    _load();
  }

  @override
  void didUpdateWidget(covariant EquipmentLoanDetailsScreen previous){
    super.didUpdateWidget(previous);
    if(previous.loan.id!=widget.loan.id){
      _record=widget.loan;
      _load();
    }
  }

  Future<void> _load() async{
    final id=_record.id;
    if(id==null)return;
    if(mounted)setState(()=>_loading=true);
    try{
      final current=await widget.repository.detail(id);
      if(mounted)setState((){
        _record=current;
        _error=null;
      });
    }catch(_){
      if(mounted)setState(()=>_error=
        'Unable to load latest loan history. Retry.');
    }finally{
      if(mounted)setState(()=>_loading=false);
    }
  }

  static String _date(DateTime? d){
    if(d==null)return 'Not returned';
    return [
      d.day.toString().padLeft(2,'0'),
      d.month.toString().padLeft(2,'0'),
      d.year.toString()
    ].join('/');
  }

  void _notice(String message){
    if(!mounted)return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content:Text(message)));
  }

  Future<void> _extend() async{
    if(_busy||_loading||_record.status==EquipmentLoanStatus.returned)return;
    final tomorrow=_record.expectedReturnDate.add(const Duration(days:1));
    final date=await showDatePicker(
      context:context,initialDate:tomorrow,
      firstDate:tomorrow,lastDate:DateTime(2100));
    if(date==null||!mounted)return;
    final confirm=await showDialog<bool>(
      context:context,builder:(dialog)=>AlertDialog(
        title:const Text('Extend Return Date?'),
        content:Text('Change expected return from '+
          _date(_record.expectedReturnDate)+' to '+_date(date)+'?'),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(dialog,false),
            child:const Text('Cancel')),
          TextButton(onPressed:()=>Navigator.pop(dialog,true),
            child:const Text('Confirm Extension')),
        ]));
    if(confirm!=true||!mounted)return;
    setState(()=>_busy=true);
    try{
      final updated=await widget.repository.extend(
        _record.id!,_record.lockVersion,date);
      if(mounted)setState((){
        _record=updated;_error=null;
      });
      _notice('Expected return date extended. History preserved.');
    }catch(_){
      if(mounted)setState(()=>_error=
        'Return date could not be extended. Refresh and retry.');
    }finally{
      if(mounted)setState(()=>_busy=false);
    }
  }

  Future<void> _returned() async{
    if(_busy||_loading||_record.status==EquipmentLoanStatus.returned)return;
    final now=DateTime.now();
    final day=await showDatePicker(
      context:context,initialDate:now,
      firstDate:_record.loanDate.isAfter(now)?now:_record.loanDate,
      lastDate:now);
    if(day==null||!mounted)return;
    final confirm=await showDialog<bool>(
      context:context,builder:(dialog)=>AlertDialog(
        title:const Text('Mark Equipment Returned?'),
        content:Text('Confirm that '+_record.equipmentName+
          ' was returned by '+_record.borrowerName+
          ' on '+_date(day)+'? This creates a permanent history event.'),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(dialog,false),
            child:const Text('Cancel')),
          TextButton(onPressed:()=>Navigator.pop(dialog,true),
            child:const Text('Mark Returned')),
        ]));
    if(confirm!=true||!mounted)return;
    setState(()=>_busy=true);
    try{
      final result=await widget.repository.markReturned(
        _record.id!,_record.lockVersion,day);
      if(mounted)setState((){
        _record=result;_error=null;
      });
      _notice('Equipment returned and recorded in history.');
    }catch(_){
      if(mounted)setState(()=>_error='Return could not be recorded. '
        'Refresh the loan before retrying.');
    }finally{
      if(mounted)setState(()=>_busy=false);
    }
  }

  @override
  Widget build(BuildContext context){
    final r=_record;
    return Scaffold(
      backgroundColor:AppColors.white,
      body:SafeArea(child:Column(children:[
        Sign2DigitalHeader(title:'Equipment Loan Details',
          onBack:()=>Navigator.of(context).maybePop()),
        Expanded(child:Center(child:ConstrainedBox(
          constraints:const BoxConstraints(maxWidth:720),
          child:ListView(
            key:const Key('equipment-loan-details-scroll'),
            padding:const EdgeInsets.fromLTRB(20,16,20,36),
            children:[
              if(_loading)const LinearProgressIndicator(),
              if(_error!=null)Padding(
                padding:const EdgeInsets.only(bottom:8),
                child:Text(_error!,
                  key:const Key('equipment-loan-details-error'),
                  style:const TextStyle(color:Color(0xFFB42318),fontSize:13))),
              Row(children:[
                const CircleAvatar(radius:20,
                  backgroundColor:Color(0xFFE3ECF0),
                  child:Icon(Icons.handyman_outlined,color:AppColors.primary)),
                const SizedBox(width:12),
                Expanded(child:Column(
                  crossAxisAlignment:CrossAxisAlignment.start,
                  children:[
                    Text(r.equipmentName,
                      style:const TextStyle(fontFamily:'Inter',fontSize:18,
                        fontWeight:FontWeight.w600,color:AppColors.dark)),
                    Text(r.equipmentCode,style:const TextStyle(
                      color:AppColors.placeholder,fontSize:13)),
                  ])),
                Text(r.status.label,
                  key:const Key('equipment-loan-detail-status'),
                  style:const TextStyle(color:AppColors.primary,
                    fontFamily:'Inter',fontSize:14,
                    fontWeight:FontWeight.w600)),
              ]),
              const SizedBox(height:20),
              Sign2DigitalInformationTable(
                key:const Key('equipment-loan-information'),
                rows:[
                  Sign2DigitalInformationRow('Borrower',r.borrowerName),
                  Sign2DigitalInformationRow('Borrower Type',
                    r.borrowerType=='client'?'Existing Client':'Other Person'),
                  Sign2DigitalInformationRow('Loan Date',_date(r.loanDate)),
                  Sign2DigitalInformationRow(
                    'Expected Return',_date(r.expectedReturnDate)),
                  Sign2DigitalInformationRow(
                    'Actual Return',_date(r.actualReturnDate)),
                  Sign2DigitalInformationRow('Status',r.status.label,isStatus:true),
                  if(r.borrowerEmail.isNotEmpty)
                    Sign2DigitalInformationRow('Contact Email',r.borrowerEmail),
                  if(r.notes.isNotEmpty)
                    Sign2DigitalInformationRow('Notes',r.notes),
                ]),
              const SizedBox(height:22),
              if(r.status!=EquipmentLoanStatus.returned)...[
                Sign2DigitalPrimaryButton(
                  key:const Key('equipment-loan-return-action'),
                  label:'Mark Returned',onPressed:_returned,
                  enabled:!_busy&&!_loading),
                const SizedBox(height:12),
                Sign2DigitalOutlinedButton(
                  key:const Key('equipment-loan-extend-action'),
                  label:'Extend Return Date',onPressed:_extend,
                  enabled:!_busy&&!_loading),
                const SizedBox(height:12),
                Sign2DigitalOutlinedButton(
                  label:'Send Reminder (Stage 2)',
                  enabled:false,
                  onPressed:(){}),
              ],
              const SizedBox(height:22),
              const Text('Loan History',style:TextStyle(
                fontFamily:'Inter',fontSize:17,
                fontWeight:FontWeight.w600,color:AppColors.dark)),
              const SizedBox(height:10),
              if(r.events.isEmpty)
                const Text('No recorded loan events.',
                  key:Key('equipment-loan-history-empty'),
                  style:TextStyle(color:AppColors.placeholder))
              else for(final event in r.events)
                Padding(padding:const EdgeInsets.only(bottom:14),
                  child:ListTile(
                    key:Key('equipment-loan-event-'+event.id.toString()),
                    contentPadding:EdgeInsets.zero,
                    leading:const Icon(Icons.history,
                      color:AppColors.primary),
                    title:Text(event.type.replaceAll('_',' ')),
                    subtitle:Text([
                      _date(event.date),
                      if(event.oldDate!=null&&event.newDate!=null)
                        'Due date: '+event.oldDate!+' → '+event.newDate!,
                      if(event.actorId!=null)
                        'User #'+event.actorId.toString(),
                    ].join(' · ')))),
              const SizedBox(height:12),
              TextButton.icon(
                onPressed:_loading?_load:_load,
                icon:const Icon(Icons.refresh),
                label:const Text('Refresh Loan Details')),
            ],
          )))),
      ])),
    );
  }
}
