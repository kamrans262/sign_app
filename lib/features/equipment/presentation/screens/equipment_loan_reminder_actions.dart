import 'package:flutter/material.dart';
import '../../../../core/widgets/sign2digital_approved_confirmation.dart';

import '../../../../core/services/active_company_session.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sign2digital_outlined_button.dart';
import '../../data/remote_equipment_loan_repository.dart';
import '../../domain/equipment_loan_record.dart';
import '../../domain/equipment_reminder_record.dart';

/// Real M19 borrower follow-up: opt-in, explicit consent and audited results.
/// No demo transport and no claim that email reached the recipient inbox.
class EquipmentLoanReminderActions extends StatefulWidget {
  const EquipmentLoanReminderActions({
    super.key,required this.loan,required this.repository,
    this.onLoanUpdated,
  });
  final EquipmentLoanRecord loan;
  final EquipmentLoanRepository repository;
  final Future<void> Function()? onLoanUpdated;
  @override
  State<EquipmentLoanReminderActions> createState()=>
      _EquipmentLoanReminderActionsState();
}

class _EquipmentLoanReminderActionsState
    extends State<EquipmentLoanReminderActions> {
  EquipmentReminderPreview? _preview;
  String? _error,_retryKey;
  bool _loading=true,_busy=false;
  int _generation=0;

  RemoteEquipmentLoanRepository? get _remote=>
      widget.repository is RemoteEquipmentLoanRepository
        ?widget.repository as RemoteEquipmentLoanRepository:null;

  @override
  void initState(){
    super.initState();
    ActiveCompanySession.selected.addListener(_load);
    _load();
  }

  @override
  void didUpdateWidget(covariant EquipmentLoanReminderActions old){
    super.didUpdateWidget(old);
    if(widget.loan.id!=old.loan.id||
        widget.loan.lockVersion!=old.loan.lockVersion||
        widget.loan.borrowerEmail!=old.loan.borrowerEmail||
        widget.loan.status!=old.loan.status){
      _load();
    }
  }

  @override
  void dispose(){
    _generation++;
    ActiveCompanySession.selected.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final repo=_remote,id=widget.loan.id;
    final generation=++_generation;
    if(repo==null||id==null)return;
    if(!mounted)return;
    setState((){
      _loading=true;_preview=null;_error=null;
    });
    try{
      final value=await repo.reminderPreview(id);
      if(!mounted||generation!=_generation)return;
      setState((){
        _preview=value;_loading=false;
      });
    }catch(_){
      if(!mounted||generation!=_generation)return;
      setState((){
        _preview=null;
        _loading=false;
        _error='Unable to load reminder settings or delivery history.';
      });
    }
  }

  void _notice(String message){
    if(!mounted)return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content:Text(message)));
  }

  Future<void> _send() async {
    if(_busy||_loading||_remote==null)return;
    final id=widget.loan.id;
    if(id==null)return;
    setState(()=>_busy=true);
    try{
      // Refresh server recipient and version before each proposed message.
      final current=await _remote!.reminderPreview(id);
      if(!mounted)return;
      if(!current.sendAvailable){
        setState((){
          _preview=current;
          _error=current.notAvailableReason??'Email sending is unavailable.';
        });
        return;
      }
      var confirmed=false;
      final approved=await showDialog<bool>(
        context:context,
        builder:(dialog)=>StatefulBuilder(
          builder:(context,refresh)=>Sign2DigitalApprovedConfirmation(
            title:const Text('Send Equipment Return Reminder?'),
            content:SizedBox(width:320,child:Column(
              mainAxisSize:MainAxisSize.min,
              crossAxisAlignment:CrossAxisAlignment.start,
              children:[
                Text('Borrower: '+current.borrowerName),
                const SizedBox(height:6),
                Text('Email: '+current.borrowerEmail),
                const SizedBox(height:6),
                Text('Equipment: '+current.equipmentName),
                const SizedBox(height:6),
                Text('Return due: '+current.expectedReturnDate),
                const SizedBox(height:10),
                const Text('This sends an email to the configured transport. '
                  'Inbox delivery is not confirmed.'),
                CheckboxListTile(
                  key:const Key('equipment-reminder-consent'),
                  value:confirmed,contentPadding:EdgeInsets.zero,
                  title:const Text('I confirm this is the intended '
                    'borrower email address.'),
                  controlAffinity:ListTileControlAffinity.leading,
                  onChanged:(v)=>refresh(()=>confirmed=v??false)),
              ])),
            actions:[
              TextButton(onPressed:()=>Navigator.pop(dialog,false),
                child:const Text('Cancel')),
              TextButton(
                key:const Key('equipment-reminder-confirm-send'),
                onPressed:confirmed
                  ?()=>Navigator.pop(dialog,true):null,
                child:const Text('Submit Email')),
            ],
          )));
      if(approved!=true||!mounted)return;
      _retryKey??='m19-reminder-'+DateTime.now()
          .microsecondsSinceEpoch.toString();
      final receipt=await _remote!.sendReminder(id,
        lockVersion:current.loanVersion,requestKey:_retryKey!);
      if(!mounted)return;
      if(receipt.status=='submitted'){
        _retryKey=null;
        _notice('Submitted to email transport. Inbox delivery not confirmed.');
      }else{
        _notice(receipt.deliveryNote);
      }
      await _load();
    }catch(_){
      if(mounted)setState(()=>_error=
        'Email submission could not be confirmed. Review history before '
        'retrying with the same request.');
    }finally{
      if(mounted)setState(()=>_busy=false);
    }
  }

  Future<void> _policy() async{
    if(_busy||_loading||_remote==null)return;
    final id=widget.loan.id,p=_preview;
    if(id==null||p==null)return;
    final enable=!p.automaticEnabled;
    var approved=false;
    var frequency=p.frequencyDays;
    final result=await showDialog<int>(
      context:context,
      builder:(dialog)=>StatefulBuilder(
        builder:(context,refresh)=>Sign2DigitalApprovedConfirmation(
          title:Text(enable?'Enable Overdue Reminders?':
            'Disable Overdue Reminders?'),
          content:SizedBox(width:320,child:Column(
            mainAxisSize:MainAxisSize.min,
            crossAxisAlignment:CrossAxisAlignment.start,
            children:[
              Text('Borrower: '+p.borrowerName),
              const SizedBox(height:6),
              Text('Email: '+p.borrowerEmail),
              const SizedBox(height:10),
              Text(enable
                ?'Only this loan opts in. Automatic sending also requires '
                    'the company server scheduler to be enabled.'
                :'This stops future automatic overdue reminders for this loan.'),
              if(enable)DropdownButton<int>(
                key:const Key('equipment-reminder-frequency'),
                value:const [1,3,7,14,30].contains(frequency)
                  ?frequency:7,
                items:[
                  for(final days in [1,3,7,14,30])
                    DropdownMenuItem<int>(
                      value:days,child:Text('Every '+days.toString()+' days')),
                ],
                onChanged:(value){
                  if(value!=null)refresh(()=>frequency=value);
                }),
              CheckboxListTile(
                key:const Key('equipment-reminder-policy-confirm'),
                value:approved,contentPadding:EdgeInsets.zero,
                controlAffinity:ListTileControlAffinity.leading,
                title:Text(enable
                  ?'I confirm this is the recipient email and opt in '
                      'to overdue notices.'
                  :'I confirm I want to stop automatic notices.'),
                onChanged:(v)=>refresh(()=>approved=v??false)),
            ])),
          actions:[
            TextButton(onPressed:()=>Navigator.pop(dialog),
              child:const Text('Cancel')),
            TextButton(
              key:const Key('equipment-reminder-policy-save'),
              onPressed:approved?()=>Navigator.pop(dialog,frequency):null,
              child:Text(enable?'Enable Reminders':'Disable Reminders')),
          ],
        )));
    if(result==null||!mounted)return;
    setState((){
      _busy=true;_error=null;
    });
    try{
      final saved=await _remote!.updateReminderPolicy(id,
        lockVersion:p.loanVersion,enabled:enable,
        recipientConfirmed:enable,frequencyDays:result);
      if(!mounted)return;
      setState(()=>_preview=saved);
      if(widget.onLoanUpdated!=null)await widget.onLoanUpdated!();
      if(!mounted)return;
      _notice(enable?'Loan opted in. Server sending still requires enablement.':
        'Automatic borrower reminders disabled for this loan.');
      await _load();
    }catch(_){
      if(mounted)setState(()=>_error=
        'Reminder policy could not be saved. Refresh the loan details.');
    }finally{
      if(mounted)setState(()=>_busy=false);
    }
  }

  @override
  Widget build(BuildContext context){
    final p=_preview;
    if(_remote==null||widget.loan.id==null)return const SizedBox.shrink();
    if(widget.loan.companyId!=null &&
        ActiveCompanySession.companyId!=widget.loan.companyId){
      return const Text('Company changed. Reopen this loan.',
        style:TextStyle(color:AppColors.placeholder));
    }
    return Column(
      crossAxisAlignment:CrossAxisAlignment.stretch,
      children:[
        const SizedBox(height:12),
        if(_loading)const LinearProgressIndicator(),
        if(_error!=null)
          Padding(padding:const EdgeInsets.symmetric(vertical:10),
            child:Text(_error!,
              key:const Key('equipment-reminder-error'),
              style:const TextStyle(color:Color(0xFFB42318),fontSize:13))),
        if(p==null)TextButton(
          key:const Key('equipment-reminder-retry'),
          onPressed:_busy?null:_load,
          child:const Text('Refresh Reminder Settings'))
        else ...[
          if(widget.loan.status!=EquipmentLoanStatus.returned)...[
            Sign2DigitalOutlinedButton(
              key:const Key('equipment-reminder-send'),
              label:'Send Reminder',
              enabled:p.sendAvailable&&!_busy&&!_loading,
              onPressed:_send),
            if(!p.sendAvailable)
              Padding(padding:const EdgeInsets.only(top:8),
                child:Text(p.notAvailableReason??'Reminder unavailable.',
                  style:const TextStyle(color:AppColors.placeholder,fontSize:12))),
            const SizedBox(height:12),
            TextButton.icon(
              key:const Key('equipment-reminder-policy'),
              onPressed:_busy||_loading?null:_policy,
              icon:const Icon(Icons.notifications_outlined,
                color:AppColors.primary),
              label:Text(p.automaticEnabled
                ?'Overdue Reminders: On ('+p.frequencyDays.toString()+' days)'
                :'Overdue Reminders: Off')),
            if(!p.automaticGlobalEnabled)
              const Text('Automatic sending is disabled on the server.',
                style:TextStyle(color:AppColors.placeholder,fontSize:12)),
          ],
          const SizedBox(height:20),
          const Text('Reminder Delivery History',
            style:TextStyle(fontFamily:'Inter',fontSize:17,
              fontWeight:FontWeight.w600,color:AppColors.dark)),
          const SizedBox(height:8),
          if(p.deliveryHistory.isEmpty)
            const Text('No borrower emails have been submitted.',
              key:Key('equipment-reminder-history-empty'),
              style:TextStyle(color:AppColors.placeholder,fontSize:13))
          else for(final item in p.deliveryHistory)
            ListTile(
              key:Key('equipment-reminder-delivery-'+item.id.toString()),
              contentPadding:EdgeInsets.zero,
              leading:const Icon(Icons.history,color:AppColors.primary),
              title:Text(item.kind+' · '+item.status),
              subtitle:Text(item.dueDate+' · '+item.createdAt+'\n'+
                item.deliveryNote),
            ),
        ],
      ],
    );
  }
}
