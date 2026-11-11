import 'dart:typed_data';

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
import '../../../jobs/data/local_job_photo_source.dart';
import '../../../jobs/domain/job_photo_model.dart';
import '../../../jobs/presentation/widgets/sign2digital_photo_preview.dart';
import '../../../jobs/domain/job_model.dart';
import '../../data/remote_work_acceptance_repository.dart';

/// Existing Sign2Digital fields; M13 records must reference a real company job.
class WorkAcceptanceEditorScreen extends StatefulWidget {
  const WorkAcceptanceEditorScreen({
    super.key, this.initial, this.initialJobId, this.repository,
    this.photoSource, this.mediaRepository, this.jobLoader,
  });
  final WorkAcceptanceDraft? initial;
  final String? initialJobId;
  final RemoteWorkAcceptanceRepository? repository;
  final JobPhotoSource? photoSource;
  final RemoteJobMediaRepository? mediaRepository;
  final Future<List<JobModel>> Function()? jobLoader;

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
  final List<LocalJobPhotoSelection> _newPhotos=[];
  final Map<int,Uint8List> _savedPhotoPreviews={};
  final Map<String,int> _uploadedPhotoIds={};
  bool _picking=false;
  bool _busy=false;
  String? _error;
  late final RemoteWorkAcceptanceRepository _repo;
  late final RemoteJobMediaRepository _media;

  @override
  void initState() {
    super.initState();
    _repo=widget.repository??RemoteWorkAcceptanceRepository.shared;
    _media=widget.mediaRepository??RemoteJobMediaRepository.shared;
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
          final jobs=await (widget.jobLoader?.call() ??
              RemoteJobRepository.shared.listJobs());
          if(mounted) {
            final matching=jobs.where((x)=>x.id==selected);
            setState(() { _job=matching.isEmpty?null:matching.first; });
            if (_job != null && _photoIds.isNotEmpty) {
              await _restoreSelectedPreviews();
            }
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
      final jobs=await (widget.jobLoader?.call() ??
              RemoteJobRepository.shared.listJobs());
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
      if(result!=null&&mounted) {
        setState(() { _job=result;_photoIds.clear();
          _savedPhotoPreviews.clear();_newPhotos.clear();
          _uploadedPhotoIds.clear();_error=null; });
      }
    }catch(error){
      if(mounted)setState(()=>_error='Unable to select company job: $error');
    }
  }

  /// Only already-linked acceptance images are reloaded for draft editing.
  /// The user is never shown the Job Photos library as a picker.
  Future<void> _restoreSelectedPreviews() async {
    final job=_job;
    if(job==null||_photoIds.isEmpty)return;
    try {
      final saved=await _media.listPhotos(job.id);
      if(!mounted)return;
      setState(() {
        for(final photo in saved) {
          final id=int.tryParse(photo.id);
          if(id!=null && _photoIds.contains(id) && photo.bytes!=null) {
            _savedPhotoPreviews[id]=photo.bytes!;
          }
        }
      });
    }catch(error) {
      if(mounted) {
        setState(()=>_error=
            'Some saved acceptance photos could not be previewed: $error');
      }
    }
  }

  Future<void> _choosePhotos() async {
    if(_busy||_picking)return;
    if(_job==null) {
      setState(()=>_error='Select a job before adding photos.');
      return;
    }
    final camera=await Sign2DigitalSelectionSheet.showCustom<bool>(
      context:context,title:'Select Photos',
      icon:Icons.photo_library_outlined,
      subtitle:'Take a photo or choose from your device',
      builder:(sheet)=>Column(mainAxisSize:MainAxisSize.min,children:[
        ListTile(
          key:const Key('acceptance-choose-camera'),
          leading:const Icon(Icons.photo_camera_outlined),
          title:const Text('Camera'),
          onTap:()=>Navigator.of(sheet).pop(true),
        ),
        ListTile(
          key:const Key('acceptance-choose-gallery'),
          leading:const Icon(Icons.photo_library_outlined),
          title:const Text('Gallery'),
          onTap:()=>Navigator.of(sheet).pop(false),
        ),
      ]),
    );
    if(camera==null||!mounted)return;
    setState(()=>_picking=true);
    try {
      final source=widget.photoSource??DeviceJobPhotoSource();
      final files=<LocalJobPhotoSelection>[];
      if(camera) {
        final item=await source.camera();
        if(item!=null)files.add(item);
      }else{
        files.addAll(await source.upload());
      }
      if(!mounted||files.isEmpty)return;
      for(final file in files) {
        DeviceJobPhotoSource.validate(file.name,file.bytes);
      }
      final seen=_newPhotos.map((p)=>p.sourceKey).toSet();
      final additional=<LocalJobPhotoSelection>[];
      for(final photo in files) {
        if(seen.add(photo.sourceKey))additional.add(photo);
      }
      if(_photoIds.length+_newPhotos.length+additional.length>8) {
        throw const FormatException('Select no more than eight photos.');
      }
      setState(() {
        _newPhotos.addAll(additional);
        _error=null;
      });
    }catch(error) {
      if(mounted)setState(()=>_error='Unable to select photos: $error');
    }finally{
      if(mounted)setState(()=>_picking=false);
    }
  }

  Widget _photoGrid() {
    final existing=_photoIds.toList()..sort();
    final count=existing.length+_newPhotos.length;
    if(count==0)return const SizedBox.shrink();
    return Padding(
      padding:const EdgeInsets.only(bottom:15),
      child:GridView.builder(
        key:const Key('acceptance-photo-grid'),
        shrinkWrap:true,
        physics:const NeverScrollableScrollPhysics(),
        gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount:2,
          mainAxisSpacing:10,
          crossAxisSpacing:15,
          childAspectRatio:188/118,
        ),
        itemCount:count,
        itemBuilder:(context,index) {
          final saved=index<existing.length;
          final id=saved?existing[index]:null;
          final photo=saved?null:_newPhotos[index-existing.length];
          return Sign2DigitalPhotoPreview(
            key:Key('acceptance-photo-$index'),
            bytes:saved?_savedPhotoPreviews[id]:photo!.bytes,
            showDemo:false,compactTile:true,
            onRemove:()=>setState(() {
              if(saved) {
                _photoIds.remove(id);
                _savedPhotoPreviews.remove(id);
              } else {
                _newPhotos.removeAt(index-existing.length);
              }
            }),
          );
        },
      ),
    );
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
      // Upload only new device captures and retain each verified ID before
      // persisting the Work Acceptance relationship. A retry reuses these IDs.
      for(final photo in List<LocalJobPhotoSelection>.of(_newPhotos)) {
        final known=_uploadedPhotoIds[photo.sourceKey];
        if(known!=null) {
          _photoIds.add(known);
          _savedPhotoPreviews[known]=photo.bytes;
          _newPhotos.remove(photo);
          continue;
        }
        final uploaded=await _media.uploadPhoto(
          _job!.id,photo,JobPhotoCategory.after,'Work acceptance photo');
        final id=int.tryParse(uploaded.id);
        if(id==null||id<=0) {
          throw StateError('Acceptance photo upload was not verified.');
        }
        _uploadedPhotoIds[photo.sourceKey]=id;
        _photoIds.add(id);
        _savedPhotoPreviews[id]=photo.bytes;
        _newPhotos.remove(photo);
      }
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
      child:Sign2DigitalInputField(
        key: label == 'Completed Work'
            ? const Key('acceptance-completed-work') : null,
        label:label,
        hintText:label,iconAsset:'assets/icons/description.svg',
        controller:controller,minLines:3,maxLines:6));

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor:AppColors.white,
    body:SafeArea(bottom:false,child:Column(children:[
      Sign2DigitalHeader(title:widget.initial==null
          ?'Create Work Acceptance':'Edit Work Acceptance'),
      Expanded(child:ListView(padding:const EdgeInsets.fromLTRB(20,0,20,24),children:[
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
            key:const Key('acceptance-select-photos'),
            label:'Select Photos (${_photoIds.length+_newPhotos.length}/8)',
            enabled:!_busy&&!_picking,
            onPressed:_choosePhotos),
          const SizedBox(height:15),
          _photoGrid(),
          if(_error!=null)Padding(padding:const EdgeInsets.only(bottom:15),
            child:Text(_error!,style:const TextStyle(
              fontFamily:'Inter',color:Color(0xFFB42318)))),
          Sign2DigitalPrimaryButton(
            key:const Key('acceptance-save-draft'),
            label:'Save Acceptance Draft',loading:_busy,onPressed:_save),
        ])),
    ])),
    bottomNavigationBar:Sign2DigitalBottomNavigationBar(
      selectedIndex:2,onSelected:(_)=>Navigator.of(context).maybePop()),
  );
}
