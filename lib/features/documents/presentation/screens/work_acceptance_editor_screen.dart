import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sign2digital_bottom_navigation_bar.dart';
import '../../../../core/widgets/sign2digital_header.dart';
import '../../../../core/widgets/sign2digital_input_field.dart';
import '../../../../core/widgets/sign2digital_primary_button.dart';
import '../../../../core/widgets/sign2digital_outlined_button.dart';
import '../../../../core/widgets/sign2digital_selection_sheet.dart';
import '../../../jobs/data/remote_job_repository.dart';
import '../../../jobs/data/remote_job_media_repository.dart';
import '../../../jobs/domain/job_model.dart';
import '../../data/remote_work_acceptance_repository.dart';
import '../../domain/document_record.dart';

/// Existing Sign2Digital fields; M13 records must reference a real company job.
class WorkAcceptanceEditorScreen extends StatefulWidget {
  const WorkAcceptanceEditorScreen({
    super.key, this.initial, this.initialJobId, this.repository,
  });
  final WorkAcceptanceDraft? initial;
  final String? initialJobId;
  final RemoteWorkAcceptanceRepository? repository;

  @override
  State<WorkAcceptanceEditorScreen> createState() => _WorkAcceptanceEditorScreenState();
}

class _WorkAcceptanceEditorScreenState extends State<WorkAcceptanceEditorScreen> {
  final _work=TextEditingController(),_issues=TextEditingController(),
      _remedial=TextEditingController();
  JobModel? _job;
  DateTime _completed=DateTime.now();
  String _cleaning='cleaned';
  final Set<int> _photoIds={};
  bool _busy=false;
  String? _error;
  late final RemoteWorkAcceptanceRepository _repo;

  @override
  void initState() {
    super.initState();
    _repo=widget.repository??RemoteWorkAcceptanceRepository.shared;
    final v=widget.initial;
    if(v!=null) {
      _work.text=v.completedWork;_issues.text=v.outstandingIssues;
      _remedial.text=v.remedialWork;_completed=v.completionDate;
      _cleaning=v.cleaningStatus;_photoIds.addAll(v.photoIds);
    }
    final selected=v?.jobId??widget.initialJobId;
    if(selected!=null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          final jobs=await RemoteJobRepository.shared.listJobs();
          if(mounted) {
            final matching=jobs.where((x)=>x.id==selected);
            setState(() { _job=matching.isEmpty?null:matching.first; });
          }
        }catch(error) {
          if(mounted)setState(()=>_error='Unable to load linked job: $error');
        }
      });
    }
  }

  @override
  void dispose() {
    _work.dispose();_issues.dispose();_remedial.dispose();
    super.dispose();
  }

  Future<void> _chooseJob() async {
    try {
      final jobs=await RemoteJobRepository.shared.listJobs();
      if(!mounted)return;
      final result=await Sign2DigitalSelectionSheet.showCustom<JobModel>(
        context:context,title:'Choose Job / Project',
        icon:Icons.work_outline_rounded,
        subtitle:'Select a real saved job and its customer',
        builder:(sheet)=>ListView(shrinkWrap:true,children:[
          for(final job in jobs)
            ListTile(title:Text(job.title),subtitle:Text(job.clientName),
              trailing:_job?.id==job.id
                  ?const Icon(Icons.check_circle,color:AppColors.primary):null,
              onTap:()=>Navigator.of(sheet).pop(job)),
        ]),
      );
      if(result!=null&&mounted)setState(() {
        _job=result;_photoIds.clear();_error=null;
      });
    }catch(error){
      if(mounted)setState(()=>_error='Unable to select company job: $error');
    }
  }

  Future<void> _choosePhotos() async {
    if(_job==null) { setState(()=>_error='Select a job before photos.');return; }
    try {
      final photos=await RemoteJobMediaRepository.shared.listPhotos(_job!.id);
      if(!mounted)return;
      final chosen=<int>{..._photoIds};
      final selected=await Sign2DigitalSelectionSheet.showCustom<bool>(
        context:context,title:'Select Job Photos',
        icon:Icons.photo_library_outlined,subtitle:'Up to 8 saved job photos',
        builder:(sheet)=>StatefulBuilder(builder:(context,update)=>Column(
          mainAxisSize:MainAxisSize.min,children:[
            Flexible(child:ListView(shrinkWrap:true,children:[
              for(final photo in photos)CheckboxListTile(
                title:Text(photo.title),
                subtitle:Text(photo.caption??photo.category.name),
                secondary:photo.bytes==null?null:Image.memory(photo.bytes!,
                  width:50,height:50,fit:BoxFit.cover),
                value:chosen.contains(int.tryParse(photo.id)),
                onChanged:(value) {
                  final id=int.tryParse(photo.id);
                  if(id==null)return;
                  if(value==true&&chosen.length>=8&&!chosen.contains(id))return;
                  update(() { if(value==true) {chosen.add(id);} else {chosen.remove(id);} });
                },
              ),
            ])),
            Padding(padding:const EdgeInsets.all(20),
              child:Sign2DigitalPrimaryButton(label:'Use Selected Photos',
                onPressed:()=>Navigator.of(sheet).pop(true))),
          ],
        )),
      );
      if(selected==true&&mounted)setState(() {
        _photoIds..clear()..addAll(chosen);
      });
    }catch(error) {
      if(mounted)setState(()=>_error='Unable to load job photos: $error');
    }
  }

  Future<void> _chooseCleaning() async {
    const types={'cleaned':'Cleaned / Restored',
      'pending':'Pending','not_applicable':'Not Applicable'};
    final value=await Sign2DigitalSelectionSheet.showCustom<String>(
      context:context,title:'Cleaning / Restoration',
      icon:Icons.cleaning_services_outlined,
      builder:(sheet)=>Column(mainAxisSize:MainAxisSize.min,children:[
        for(final entry in types.entries)ListTile(
          title:Text(entry.value),
          trailing:entry.key==_cleaning?const Icon(Icons.check_circle,
            color:AppColors.primary):null,
          onTap:()=>Navigator.of(sheet).pop(entry.key)),
      ]),
    );
    if(value!=null&&mounted)setState(()=>_cleaning=value);
  }

  Future<void> _chooseDate() async {
    final value=await showDatePicker(context:context,initialDate:_completed,
      firstDate:DateTime(2000),lastDate:DateTime(2100));
    if(value!=null&&mounted)setState(()=>_completed=value);
  }

  Future<void> _save() async {
    if(_busy)return;
    if(_job==null||_work.text.trim().isEmpty) {
      setState(()=>_error='Choose a saved job and describe completed work.');
      return;
    }
    setState(() { _busy=true;_error=null; });
    try {
      final existing=widget.initial;
      final result=await _repo.saveDraft(WorkAcceptanceDraft(
        id:existing?.id,revision:existing?.revision??1,
        jobId:_job!.id,completedWork:_work.text,
        completionDate:_completed,cleaningStatus:_cleaning,
        outstandingIssues:_issues.text,remedialWork:_remedial.text,
        photoIds:_photoIds.toList(),
      ));
      if(mounted)Navigator.of(context).pop(result);
    }catch(error){
      if(mounted)setState(()=>_error='Unable to save draft: $error');
    }finally{if(mounted)setState(()=>_busy=false);}
  }

  Widget _input(String label,TextEditingController controller) =>
    Padding(padding:const EdgeInsets.only(bottom:15),
      child:Sign2DigitalInputField(label:label,
        hintText:label,iconAsset:'assets/icons/description.svg',
        controller:controller,minLines:3,maxLines:6));

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor:AppColors.white,
    body:SafeArea(bottom:false,child:Column(children:[
      Sign2DigitalHeader(title:widget.initial==null
          ?'Create Work Acceptance':'Edit Work Acceptance'),
      Expanded(child:Center(child:ConstrainedBox(
        constraints:const BoxConstraints(maxWidth:720),
        child:ListView(padding:const EdgeInsets.fromLTRB(20,0,20,24),children:[
          ListTile(key:const Key('acceptance-select-job'),
            title:Text(_job?.title??'Select Job / Project'),
            subtitle:Text(_job?.clientName??'Choose a saved job and customer'),
            trailing:const Icon(Icons.chevron_right),
            onTap:widget.initial==null?_chooseJob:null),
          const SizedBox(height:15),
          _input('Completed Work',_work),
          ListTile(title:const Text('Completion Date'),
            subtitle:Text([_completed.year.toString(),
              _completed.month.toString().padLeft(2,'0'),
              _completed.day.toString().padLeft(2,'0')].join('-')),
            trailing:const Icon(Icons.calendar_today_outlined),
            onTap:_chooseDate),
          ListTile(title:const Text('Cleaning / Restoration Status'),
            subtitle:Text(_cleaning.replaceAll('_',' ')),
            trailing:const Icon(Icons.chevron_right),
            onTap:_chooseCleaning),
          const SizedBox(height:15),
          _input('Outstanding Issues',_issues),
          _input('Required Remedial Work',_remedial),
          Sign2DigitalOutlinedButton(
            label:'Select Job Photos ('+_photoIds.length.toString()+'/8)',
            onPressed:_choosePhotos),
          const SizedBox(height:15),
          if(_error!=null)Padding(padding:const EdgeInsets.only(bottom:15),
            child:Text(_error!,style:const TextStyle(
              fontFamily:'Inter',color:Color(0xFFB42318)))),
          Sign2DigitalPrimaryButton(
            key:const Key('acceptance-save-draft'),
            label:'Save Acceptance Draft',loading:_busy,onPressed:_save),
        ]),
      ))),
    ])),
    bottomNavigationBar:Sign2DigitalBottomNavigationBar(
      selectedIndex:2,onSelected:(_)=>Navigator.of(context).maybePop()),
  );
}
