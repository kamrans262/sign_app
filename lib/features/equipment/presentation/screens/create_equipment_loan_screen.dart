import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sign2digital_ai_voice_button.dart';
import '../../../../core/widgets/sign2digital_header.dart';
import '../../../../core/widgets/sign2digital_primary_button.dart';
import '../../../../core/widgets/sign2digital_selection_sheet.dart';
import '../../../auth/data/mobile_auth_repository.dart';
import '../../../clients/domain/client_profile.dart';
import '../../../jobs/presentation/widgets/ai_voice_flow_dialog.dart';
import '../../../jobs/services/voice_job_extraction_service.dart';
import '../../../jobs/services/voice_recorder_service.dart';
import '../../data/demo_equipment_repository.dart';
import '../../data/remote_equipment_repository.dart';
import '../../data/remote_equipment_loan_repository.dart';
import '../../domain/equipment_record.dart';
import '../../domain/equipment_loan_record.dart';

/// Original Q61. Manual entry is independent of voice/AI credits.
class CreateEquipmentLoanScreen extends StatefulWidget {
  const CreateEquipmentLoanScreen({super.key,required this.repository,
    this.equipmentRepository,this.initialAsset});
  final EquipmentLoanRepository repository;
  final EquipmentRepository? equipmentRepository;
  final EquipmentRecord? initialAsset;

  @override
  State<CreateEquipmentLoanScreen> createState()=>_CreateEquipmentLoanScreenState();
}

class _CreateEquipmentLoanScreenState extends State<CreateEquipmentLoanScreen> {
  late final EquipmentRepository _equipment;
  final _borrower=TextEditingController();
  final _email=TextEditingController();
  final _notes=TextEditingController();
  List<EquipmentRecord> _assets=[];
  EquipmentRecord? _selectedAsset;
  ClientProfile? _selectedClient;
  DateTime _loanDate=DateTime.now();
  DateTime _returnDate=DateTime.now().add(const Duration(days:1));
  String _borrowerType='external';
  late final String _retryKey;
  bool _loading=true,_saving=false,_voiceOpen=false;
  String? _error;

  @override
  void initState(){
    super.initState();
    _retryKey='equipment-loan-'+DateTime.now().microsecondsSinceEpoch.toString();
    _equipment=widget.equipmentRepository??(
      MobileAuthRepository.shared.isSignedIn
        ?RemoteEquipmentRepository.shared
        :const DemoEquipmentRepository());
    _selectedAsset=widget.initialAsset;
    _load();
  }
  @override
  void dispose(){
    _borrower.dispose();_email.dispose();_notes.dispose();
    super.dispose();
  }
  Future<void> _load() async{
    if(!mounted)return;
    setState((){
      _loading=true;_error=null;
    });
    try{
      final items=await _equipment.listEquipment();
      if(mounted)setState((){
        _assets=items;
        if(_selectedAsset!=null){
          for(final entry in items){
            if(entry.id==_selectedAsset!.id)_selectedAsset=entry;
          }
        }
        _loading=false;
      });
    }catch(_){
      if(mounted)setState((){
        _loading=false;
        _error='Unable to load registered equipment. Retry.';
      });
    }
  }

  Future<void> _assetPicker() async{
    if(_saving||_loading)return;
    final selected=await Sign2DigitalSelectionSheet.showCustom<EquipmentRecord>(
      context:context,title:'Select Equipment',
      icon:Icons.handyman_outlined,
      subtitle:'Choose an available company asset',
      builder:(sheet)=>SafeArea(child:ConstrainedBox(
        constraints:const BoxConstraints(maxHeight:400),
        child:ListView(shrinkWrap:true,children:[
          for(final asset in _assets.where((item)=>
              item.status!=EquipmentStatus.maintenance&&
              item.currentLoanId==null))
            ListTile(
              key:Key('equipment-loan-asset-'+asset.id),
              title:Text(asset.name),subtitle:Text(asset.id),
              trailing:asset.id==_selectedAsset?.id
                ?const Icon(Icons.check,color:AppColors.primary):null,
              onTap:()=>Navigator.pop(sheet,asset)),
          if(!_assets.any((item)=>
              item.status!=EquipmentStatus.maintenance&&
              item.currentLoanId==null))
            const ListTile(title:Text('No equipment available to loan')),
        ]))));
    if(selected!=null&&mounted)setState((){
      _selectedAsset=selected;_error=null;
    });
  }

  Future<void> _borrowerPicker() async{
    final selected=await Sign2DigitalSelectionSheet.showCustom<String>(
      context:context,title:'Borrower Type',icon:Icons.person_outline,
      subtitle:'Choose an existing client or another person',
      builder:(sheet)=>SafeArea(child:Column(
        mainAxisSize:MainAxisSize.min,children:[
          ListTile(
            key:const Key('equipment-loan-borrower-external'),
            title:const Text('Other Person'),
            onTap:()=>Navigator.pop(sheet,'external')),
          ListTile(
            key:const Key('equipment-loan-borrower-client'),
            title:const Text('Existing Client'),
            onTap:()=>Navigator.pop(sheet,'client')),
        ])));
    if(selected!=null&&mounted)setState((){
      _borrowerType=selected;_selectedClient=null;
      _error=null;
    });
    if(selected=='client'&&mounted)await _clientPicker();
  }

  Future<void> _clientPicker() async{
    if(widget.repository is! RemoteEquipmentLoanRepository){
      setState(()=>_error='Sign in to select a saved client.');
      return;
    }
    try{
      final clients=await (widget.repository
        as RemoteEquipmentLoanRepository).clients();
      if(!mounted)return;
      final selected=await Sign2DigitalSelectionSheet.showCustom<ClientProfile>(
        context:context,title:'Choose Client',icon:Icons.people_outline,
        subtitle:'Clients in the selected company',
        builder:(sheet)=>SafeArea(child:ConstrainedBox(
          constraints:const BoxConstraints(maxHeight:400),
          child:ListView(shrinkWrap:true,children:[
            for(final c in clients)
              ListTile(
                title:Text(c.fullName.isEmpty?c.companyName:c.fullName),
                subtitle:Text(c.email),
                onTap:()=>Navigator.pop(sheet,c)),
            if(clients.isEmpty)
              const ListTile(title:Text('No clients available')),
          ]))));
      if(selected!=null&&mounted)setState((){
        _selectedClient=selected;
        _borrower.text=selected.fullName.isEmpty
          ?selected.companyName:selected.fullName;
        _email.text=selected.email;_error=null;
      });
    }catch(_){
      if(mounted)setState(()=>_error='Unable to load company clients.');
    }
  }

  Future<void> _pickDate(bool due) async{
    final initial=due?_returnDate:_loanDate;
    final selected=await showDatePicker(
      context:context,initialDate:initial,
      firstDate:DateTime(2000),
      lastDate:DateTime(2100));
    if(selected!=null&&mounted)setState((){
      if(due){_returnDate=selected;}else{_loanDate=selected;}
    });
  }

  static String _displayDate(DateTime d)=>[
    d.day.toString().padLeft(2,'0'),
    d.month.toString().padLeft(2,'0'),
    d.year.toString(),
  ].join('/');

  void _notice(String message){
    if(!mounted)return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(message)));
  }

  Future<void> _voice() async{
    if(_voiceOpen||_saving)return;
    if(widget.repository is! RemoteEquipmentLoanRepository){
      _notice('Voice suggestions require a connected company.');
      return;
    }
    _voiceOpen=true;
    try{
      await showDialog<void>(context:context,
        barrierDismissible:false,
        barrierColor:const Color(0x80000000),
        builder:(_)=>AiVoiceFlowDialog(
          recorder:LocalVoiceRecorderService(),
          extraction:OpenAiVoiceJobExtractionService(),
          recordingTitle:'Record Equipment Loan Details',
          onAudioProcessed:(path) async{
            final suggestion=await (widget.repository
              as RemoteEquipmentLoanRepository).prepareVoice(path);
            if(!mounted)return;
            final apply=await showDialog<bool>(context:context,
              builder:(dialog)=>AlertDialog(
                title:const Text('Use Suggested Loan Details?'),
                content:const Text('Only missing fields will be filled. '
                  'Review the borrower, item and dates before saving.'),
                actions:[
                  TextButton(onPressed:()=>Navigator.pop(dialog,false),
                    child:const Text('Keep My Entries')),
                  TextButton(onPressed:()=>Navigator.pop(dialog,true),
                    child:const Text('Apply Suggestions')),
                ]));
            if(apply!=true||!mounted)return;
            setState((){
              if(_borrower.text.trim().isEmpty){
                _borrower.text=(suggestion['borrower_name']??'').toString();
              }
              if(_email.text.trim().isEmpty){
                _email.text=(suggestion['borrower_email']??'').toString();
              }
              if(_notes.text.trim().isEmpty){
                _notes.text=(suggestion['notes']??'').toString();
              }
              _error=null;
            });
          }));
    }catch(_){
      _notice('Voice extraction was unavailable. Manual fields are preserved.');
    }finally{
      _voiceOpen=false;
    }
  }

  Future<void> _save() async{
    if(_saving||_loading)return;
    final selected=_selectedAsset;
    final name=_borrower.text.trim();
    if(selected==null||selected.serverId==null||
        name.length<2||_returnDate.isBefore(_loanDate)||
        (_borrowerType=='client'&&_selectedClient==null)){
      setState(()=>_error='Choose an equipment asset, borrower and valid '
        'loan/return dates.');
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState((){
      _saving=true;_error=null;
    });
    try{
      final item=EquipmentLoanRecord(
        assetId:selected.serverId!,
        equipmentCode:selected.id,equipmentName:selected.name,
        borrowerName:name,borrowerType:_borrowerType,
        borrowerEmail:_email.text.trim(),
        clientId:_borrowerType=='client'
          ?int.tryParse(_selectedClient!.id):null,
        loanDate:_loanDate,expectedReturnDate:_returnDate,
        notes:_notes.text.trim(),requestKey:_retryKey,
      );
      final saved=await widget.repository.createLoan(item);
      if(mounted)Navigator.of(context).pop(saved);
    }catch(_){
      if(mounted)setState(()=>_error='Unable to save equipment loan. '
        'Check that this equipment is available and dates are valid.');
    }finally{
      if(mounted)setState(()=>_saving=false);
    }
  }

  @override
  Widget build(BuildContext context)=>Scaffold(
    backgroundColor:AppColors.white,
    body:SafeArea(child:Column(children:[
      Sign2DigitalHeader(title:'Equipment Loan',
        onBack:()=>Navigator.of(context).maybePop()),
      Expanded(child:Center(child:ConstrainedBox(
        constraints:const BoxConstraints(maxWidth:720),
        child:ListView(key:const Key('equipment-loan-form-scroll'),
          padding:const EdgeInsets.fromLTRB(20,12,20,32),children:[
          Sign2DigitalAiVoiceButton(
            key:const Key('equipment-loan-ai-voice'),onPressed:_voice),
          const SizedBox(height:20),
          if(_loading)const LinearProgressIndicator(),
          if(_error!=null)Padding(
            padding:const EdgeInsets.symmetric(vertical:8),
            child:Text(_error!,key:const Key('equipment-loan-form-error'),
              style:const TextStyle(color:Color(0xFFB42318),fontSize:13))),
          const Text('Equipment',style:TextStyle(
            fontFamily:'Inter',fontWeight:FontWeight.w600,
            fontSize:14,color:AppColors.dark)),
          const SizedBox(height:8),
          OutlinedButton(
            key:const Key('equipment-loan-pick-asset'),
            onPressed:_loading?null:_assetPicker,
            child:Text(_selectedAsset==null?'Select Equipment':
              _selectedAsset!.name+' · '+_selectedAsset!.id)),
          const SizedBox(height:16),
          const Text('Borrower',style:TextStyle(
            fontFamily:'Inter',fontWeight:FontWeight.w600,
            fontSize:14,color:AppColors.dark)),
          const SizedBox(height:8),
          OutlinedButton(
            key:const Key('equipment-loan-pick-borrower-type'),
            onPressed:_borrowerPicker,
            child:Text(_borrowerType=='client'?'Existing Client':'Other Person')),
          const SizedBox(height:14),
          TextField(
            key:const Key('equipment-loan-borrower-name'),
            controller:_borrower,
            decoration:const InputDecoration(labelText:'Borrower Full Name')),
          const SizedBox(height:12),
          TextField(
            key:const Key('equipment-loan-borrower-email'),
            controller:_email,keyboardType:TextInputType.emailAddress,
            decoration:const InputDecoration(labelText:'Borrower Email (optional)')),
          const SizedBox(height:18),
          TextButton.icon(
            key:const Key('equipment-loan-date'),
            onPressed:()=>_pickDate(false),
            icon:const Icon(Icons.calendar_today_outlined),
            label:Text('Loan Date: '+_displayDate(_loanDate))),
          TextButton.icon(
            key:const Key('equipment-loan-return-date'),
            onPressed:()=>_pickDate(true),
            icon:const Icon(Icons.calendar_today_outlined),
            label:Text('Expected Return: '+_displayDate(_returnDate))),
          const SizedBox(height:12),
          TextField(
            key:const Key('equipment-loan-notes'),
            controller:_notes,maxLines:4,
            decoration:const InputDecoration(labelText:'Notes (optional)')),
          const SizedBox(height:24),
          Sign2DigitalPrimaryButton(
            key:const Key('equipment-loan-save'),
            label:'Create Equipment Loan',loading:_saving,
            enabled:!_saving&&!_loading,onPressed:_save),
        ])),
      ))),
    ])),
  );
}
