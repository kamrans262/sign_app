import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sign2digital_header.dart';
import '../../../../core/widgets/sign2digital_outlined_container.dart';
import '../../../../core/widgets/sign2digital_outlined_button.dart';
import '../../../../core/widgets/sign2digital_primary_button.dart';
import '../../../../core/widgets/sign2digital_selection_field.dart';
import '../../../auth/data/mobile_auth_repository.dart';
import '../../../clients/data/remote_client_repository.dart';
import '../../../clients/domain/client_profile.dart';
import '../../../jobs/data/remote_job_repository.dart';
import '../../../jobs/domain/job_model.dart';
import '../../data/remote_general_document_repository.dart';
import '../../domain/general_document_draft.dart';

/// M18 authoring inside the established Sign2Digital document UI system.
class GeneralDocumentEditorScreen extends StatefulWidget {
  const GeneralDocumentEditorScreen({super.key,this.documentId,this.repository});
  final int? documentId;
  final RemoteGeneralDocumentRepository? repository;
  @override
  State<GeneralDocumentEditorScreen> createState()=>_GeneralDocumentEditorScreenState();
}

class _GeneralDocumentEditorScreenState extends State<GeneralDocumentEditorScreen> {
  late final RemoteGeneralDocumentRepository _repository;
  final _title=TextEditingController();
  final _instructions=TextEditingController();
  final _paragraphs=<TextEditingController>[TextEditingController()];
  final _kinds=<String>['paragraph'],_bold=<bool>[false],_italic=<bool>[false];
  final _createKey='m18-draft-'+DateTime.now().microsecondsSinceEpoch.toString();
  GeneralDocumentDraft? _saved;
  List<ClientProfile> _clients=const [];
  List<JobModel> _jobs=const [];
  List<Map<String,dynamic>> _files=const [];
  String _type='letter',_locale='en',_source='manual';
  int? _clientId,_jobId;
  bool _busy=false,_loading=false;
  String? _error;
  static const _types={
    'letter':'Business Letter','statement':'Statement',
    'power_of_attorney':'Power of Attorney',
    'acceptance':'Acceptance Document','custom':'Custom Document',
  };
  static const _languages={
    'en':'English','fr':'French','de':'German','it':'Italian',
  };
  static const _styles={
    'paragraph':'Paragraph','heading':'Heading',
    'bullet':'Bullet','numbered':'Numbered',
  };

  @override
  void initState(){
    super.initState();
    _repository=widget.repository??RemoteGeneralDocumentRepository.shared;
    if(widget.documentId!=null)_load();
    _loadChoices();
  }
  @override
  void dispose(){
    _title.dispose();_instructions.dispose();
    for(final c in _paragraphs)c.dispose();
    super.dispose();
  }
  bool get _editable=>_saved==null||_saved!.editable;
  void _notice(String text){
    if(!mounted)return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content:Text(text)));
  }
  Future<void> _loadChoices() async{
    if(!MobileAuthRepository.shared.isSignedIn)return;
    try{
      final clients=await RemoteClientRepository.shared.listClients();
      final jobs=await RemoteJobRepository.shared.listJobs();
      if(mounted)setState((){
        _clients=clients;
        _jobs=jobs.where((j)=>j.category!=JobCategory.archived).toList();
      });
    }catch(_){
      if(mounted)_notice('Clients and jobs could not be refreshed.');
    }
  }
  void _fill(GeneralDocumentDraft d){
    _saved=d;_title.text=d.title;_type=d.type;_locale=d.locale;
    _clientId=d.clientId;_jobId=d.jobId;_source=d.source;
    for(final c in _paragraphs)c.dispose();
    _paragraphs.clear();_kinds.clear();_bold.clear();_italic.clear();
    for(final block in d.blocks){
      _paragraphs.add(TextEditingController(text:block.text));
      _kinds.add(block.type);_bold.add(block.bold);_italic.add(block.italic);
    }
    if(_paragraphs.isEmpty){
      _paragraphs.add(TextEditingController());
      _kinds.add('paragraph');_bold.add(false);_italic.add(false);
    }
  }
  Future<void> _load() async{
    final id=widget.documentId;
    if(id==null)return;
    setState(()=>_loading=true);
    try{
      final data=await _repository.detail(id);
      if(!mounted)return;
      setState((){
        _fill(data);_error=null;_loading=false;
      });
      await _loadFiles();
    }catch(_){
      if(mounted)setState((){
        _error='Unable to load document or company access changed.';
        _loading=false;
      });
    }
  }
  Future<void> _loadFiles() async{
    final id=_saved?.id;
    if(id==null)return;
    try{
      final files=await _repository.attachments(id);
      if(mounted)setState(()=>_files=files);
    }catch(_){
      if(mounted)setState(()=>_error='Unable to load attachments.');
    }
  }
  List<GeneralTextBlock> get _blocks=>[
    for(var i=0;i<_paragraphs.length;i++)
      GeneralTextBlock(type:_kinds[i],text:_paragraphs[i].text,
        bold:_bold[i],italic:_italic[i]),
  ];
  GeneralDocumentDraft _current()=>GeneralDocumentDraft(
    id:_saved?.id,companyId:_saved?.companyId,number:_saved?.number??'',
    title:_title.text.trim(),type:_type,locale:_locale,
    clientId:_clientId,jobId:_jobId,blocks:_blocks,source:_source,
    status:_saved?.status??'draft',revision:_saved?.revision??0,
    lockVersion:_saved?.lockVersion??0);

  Future<String?> _option(String title,Map<String,String> options) async=>
    showModalBottomSheet<String>(context:context,showDragHandle:true,
      builder:(sheet)=>SafeArea(child:Column(mainAxisSize:MainAxisSize.min,children:[
        Padding(padding:const EdgeInsets.all(16),
          child:Text(title,style:const TextStyle(fontFamily:'Inter',
            fontWeight:FontWeight.w600,fontSize:16))),
        for(final entry in options.entries)ListTile(
          title:Text(entry.value),onTap:()=>Navigator.pop(sheet,entry.key)),
      ])));

  Future<void> _pickClient() async{
    if(!_editable||_clients.isEmpty)return;
    final client=await showModalBottomSheet<ClientProfile>(
      context:context,showDragHandle:true,isScrollControlled:true,
      builder:(sheet)=>SafeArea(child:SizedBox(
        height:MediaQuery.sizeOf(sheet).height*.56,
        child:ListView(children:[
          ListTile(title:const Text('No client'),onTap:()=>Navigator.pop(sheet)),
          for(final c in _clients)ListTile(
            title:Text(c.fullName.isEmpty?c.companyName:c.fullName),
            onTap:()=>Navigator.pop(sheet,c)),
        ]))));
    if(!mounted)return;
    setState((){
      _clientId=client==null?null:int.tryParse(client.id);
      if(_jobId!=null&&_jobs.any((j)=>j.id=='$_jobId'&&j.clientId!=client?.id)){
        _jobId=null;
      }
    });
  }
  Future<void> _pickJob() async{
    if(!_editable||_jobs.isEmpty)return;
    final job=await showModalBottomSheet<JobModel>(
      context:context,showDragHandle:true,isScrollControlled:true,
      builder:(sheet)=>SafeArea(child:SizedBox(
        height:MediaQuery.sizeOf(sheet).height*.56,
        child:ListView(children:[
          ListTile(title:const Text('No job'),onTap:()=>Navigator.pop(sheet)),
          for(final j in _jobs)ListTile(
            title:Text(j.title),subtitle:Text(j.clientName),
            onTap:()=>Navigator.pop(sheet,j)),
        ]))));
    if(!mounted)return;
    setState((){
      _jobId=job==null?null:int.tryParse(job.id);
      if(job!=null)_clientId=int.tryParse(job.clientId);
    });
  }
  Future<void> _save() async{
    if(_busy||!_editable)return;
    setState(()=>_busy=true);
    try{
      final result=await _repository.save(_current(),createRequestKey:_createKey);
      if(!mounted)return;
      setState((){
        _fill(result);_error=null;
      });
      _notice('General document draft saved.');
      await _loadFiles();
    }catch(_){
      if(mounted)setState(()=>_error=
        'Save failed. Review the document, company or revision and retry.');
    }finally{
      if(mounted)setState(()=>_busy=false);
    }
  }
  Future<void> _suggest() async{
    if(_busy||!_editable)return;
    if(_instructions.text.trim().length<3){
      setState(()=>_error='Enter AI instructions to create a suggestion.');
      return;
    }
    setState(()=>_busy=true);
    try{
      final draft=await _repository.suggest(type:_type,locale:_locale,
        instructions:_instructions.text.trim(),
        clientId:_clientId,jobId:_jobId);
      if(!mounted)return;
      final accept=await showModalBottomSheet<bool>(
        context:context,showDragHandle:true,isScrollControlled:true,
        builder:(sheet)=>SafeArea(child:Padding(padding:const EdgeInsets.all(20),
          child:Column(mainAxisSize:MainAxisSize.min,
            crossAxisAlignment:CrossAxisAlignment.stretch,children:[
            const Text('Review AI Suggestion',style:TextStyle(
              fontFamily:'Inter',fontSize:18,fontWeight:FontWeight.w600)),
            const SizedBox(height:12),
            Text(draft.title,style:const TextStyle(fontFamily:'Inter')),
            const SizedBox(height:10),
            SizedBox(height:160,child:SingleChildScrollView(
              child:Text(draft.blocks.map((b)=>b.text).join('\n\n')))),
            const SizedBox(height:16),
            Sign2DigitalPrimaryButton(label:'Use Suggestion',
              onPressed:()=>Navigator.pop(sheet,true)),
            const SizedBox(height:8),
            Sign2DigitalOutlinedButton(label:'Keep Current Draft',
              onPressed:()=>Navigator.pop(sheet,false)),
          ]))));
      if(accept==true&&mounted){
        setState((){
          final current=_saved;
          _fill(GeneralDocumentDraft(
            id:current?.id,companyId:current?.companyId,
            number:current?.number??'',revision:current?.revision??0,
            lockVersion:current?.lockVersion??0,
            status:current?.status??'draft',
            type:_type,locale:_locale,title:draft.title,
            clientId:_clientId,jobId:_jobId,
            source:'ai_draft',blocks:draft.blocks));
          _error=null;
        });
        _notice('AI suggestion added to draft. Save to keep changes.');
      }
    }catch(_){
      if(mounted)setState(()=>_error=
        'AI is unavailable; continue with manual document creation.');
    }finally{
      if(mounted)setState(()=>_busy=false);
    }
  }
  Future<void> _transition(String action) async{
    final record=_saved;
    if(_busy||record?.id==null)return;
    setState(()=>_busy=true);
    try{
      final updated=await _repository.transition(record!.id!,action,
        lockVersion:record.lockVersion);
      if(mounted)setState((){
        _fill(updated);_error=null;
      });
      _notice(action=='approve'?'Document approved and locked.':
        'Document marked reviewed.');
    }catch(_){
      if(mounted)setState(()=>_error=
        'Approval failed. Check permissions and current revision.');
    }finally{
      if(mounted)setState(()=>_busy=false);
    }
  }
  Future<void> _attach() async{
    final id=_saved?.id;
    if(id==null||_busy||!_editable)return;
    final picked=await FilePicker.platform.pickFiles(
      type:FileType.custom,allowedExtensions:['pdf','jpg','jpeg','png'],
      withData:true);
    if(picked==null||picked.files.isEmpty)return;
    final file=picked.files.first;
    if(file.bytes==null)return;
    setState(()=>_busy=true);
    try{
      await _repository.attach(id,file.name,file.bytes!);
      await _loadFiles();
      _notice('Private document attachment saved.');
    }catch(_){
      if(mounted)setState(()=>_error='Attachment could not be stored.');
    }finally{
      if(mounted)setState(()=>_busy=false);
    }
  }

  Widget _label(String value)=>Text(value,style:const TextStyle(
    fontFamily:'Inter',fontSize:14,fontWeight:FontWeight.w600,
    color:AppColors.dark));

  Widget _field(String label,TextEditingController controller,{
    int lines=1})=>Column(
    crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      _label(label),const SizedBox(height:8),
      Sign2DigitalOutlinedContainer(
        padding:const EdgeInsets.all(16),
        child:TextField(controller:controller,enabled:_editable&&!_busy,
          minLines:lines,maxLines:lines==1?1:6,
          decoration:const InputDecoration(
            border:InputBorder.none,isCollapsed:true),
          style:const TextStyle(fontFamily:'Inter',
            fontSize:14,color:AppColors.dark))),
    ]);

  Widget _paragraph(int index)=>Column(
    key:Key('general-document-paragraph-$index'),
    crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      Row(children:[
        Expanded(child:DropdownButton<String>(
          key:Key('general-document-kind-$index'),isExpanded:true,
          value:_kinds[index],
          onChanged:_editable&&!_busy?(v){
            if(v!=null)setState(()=>_kinds[index]=v);
          }:null,
          items:_styles.entries.map((e)=>DropdownMenuItem(
            value:e.key,child:Text(e.value,style:const TextStyle(
              fontFamily:'Inter',fontSize:13)))).toList())),
        IconButton(key:Key('general-document-bold-$index'),
          icon:Icon(Icons.format_bold,color:_bold[index]?
            AppColors.primary:AppColors.secondaryText),
          onPressed:_editable&&!_busy?()=>setState(
            ()=>_bold[index]=!_bold[index]):null),
        IconButton(key:Key('general-document-italic-$index'),
          icon:Icon(Icons.format_italic,color:_italic[index]?
            AppColors.primary:AppColors.secondaryText),
          onPressed:_editable&&!_busy?()=>setState(
            ()=>_italic[index]=!_italic[index]):null),
        if(_paragraphs.length>1&&_editable)IconButton(
          onPressed:_busy?null:()=>setState((){
            _paragraphs.removeAt(index).dispose();
            _kinds.removeAt(index);_bold.removeAt(index);_italic.removeAt(index);
          }),icon:const Icon(Icons.remove_circle_outline)),
      ]),
      Sign2DigitalOutlinedContainer(
        padding:const EdgeInsets.all(16),
        child:TextField(controller:_paragraphs[index],
          key:Key('general-document-text-$index'),
          enabled:_editable&&!_busy,minLines:3,maxLines:6,
          style:TextStyle(fontFamily:'Inter',fontSize:14,
            fontWeight:_bold[index]?FontWeight.w600:FontWeight.w400,
            fontStyle:_italic[index]?FontStyle.italic:FontStyle.normal),
          decoration:const InputDecoration(
            hintText:'Document paragraph...',border:InputBorder.none,
            isCollapsed:true))),
      const SizedBox(height:12),
    ]);

  @override
  Widget build(BuildContext context){
    final client=_clients.where((c)=>c.id=='$_clientId')
      .map((c)=>c.fullName.isEmpty?c.companyName:c.fullName).firstOrNull;
    final job=_jobs.where((j)=>j.id=='$_jobId')
      .map((j)=>j.title).firstOrNull;
    return Scaffold(backgroundColor:AppColors.white,
      body:SafeArea(child:Column(children:[
        Sign2DigitalHeader(title:'AI Document Editor',
          onBack:()=>Navigator.of(context).maybePop()),
        Expanded(child:Center(child:ConstrainedBox(
          constraints:const BoxConstraints(maxWidth:720),
          child:ListView(key:const Key('general-document-scroll'),
            padding:const EdgeInsets.fromLTRB(20,0,20,20),children:[
            if(_loading)const LinearProgressIndicator(),
            if(_saved!=null)...[
              Text(_saved!.number+' · '+_saved!.status.toUpperCase(),
                style:const TextStyle(fontFamily:'Inter',
                  fontSize:12,color:AppColors.placeholder)),
              const SizedBox(height:16)],
            Sign2DigitalSelectionField(
              key:const Key('general-document-type'),
              label:'Document Type',iconAsset:'assets/icons/description.svg',
              hintText:'Choose type',value:_types[_type],
              onTap:() async{
                if(!_editable||_busy)return;
                final v=await _option('Document Type',_types);
                if(mounted&&v!=null)setState(()=>_type=v);
              }),
            const SizedBox(height:18),
            Sign2DigitalSelectionField(label:'Language',
              iconAsset:'assets/icons/description.svg',hintText:'Language',
              value:_languages[_locale],onTap:() async{
                if(!_editable||_busy)return;
                final v=await _option('Language',_languages);
                if(mounted&&v!=null)setState(()=>_locale=v);
              }),
            const SizedBox(height:18),
            _field('Document Title',_title),
            const SizedBox(height:18),
            Sign2DigitalSelectionField(
              key:const Key('general-document-client'),
              label:'Client (optional)',iconAsset:'assets/icons/description.svg',
              hintText:'Select client',value:client??
                (_clientId==null?null:'Client #$_clientId'),
              onTap:_pickClient),
            const SizedBox(height:18),
            Sign2DigitalSelectionField(
              key:const Key('general-document-job'),
              label:'Job (optional)',iconAsset:'assets/icons/description.svg',
              hintText:'Select job',value:job??
                (_jobId==null?null:'Job #$_jobId'),onTap:_pickJob),
            const SizedBox(height:20),
            _label('Document Content'),const SizedBox(height:12),
            for(var i=0;i<_paragraphs.length;i++)_paragraph(i),
            if(_editable)TextButton.icon(
              key:const Key('general-document-add-paragraph'),
              onPressed:_busy?null:()=>setState((){
                _paragraphs.add(TextEditingController());
                _kinds.add('paragraph');_bold.add(false);_italic.add(false);
              }),
              icon:const Icon(Icons.add),label:const Text('Add Paragraph')),
            const SizedBox(height:20),
            _field('AI Instructions (optional)',_instructions,lines:3),
            const SizedBox(height:12),
            Sign2DigitalOutlinedButton(label:'Suggest with AI',
              enabled:_editable&&!_busy,onPressed:_suggest),
            if(_files.isNotEmpty)...[
              const SizedBox(height:18),_label('Attachments'),
              for(final file in _files)ListTile(
                title:Text((file['name']??'Attachment').toString()),
                subtitle:Text((file['mime_type']??'').toString())),
            ],
            if(_saved?.id!=null&&_editable)...[
              const SizedBox(height:12),
              Sign2DigitalOutlinedButton(label:'Attach File',
                enabled:!_busy,onPressed:_attach)],
            if(_error!=null)...[
              const SizedBox(height:14),
              Text(_error!,key:const Key('general-document-error'),
                style:const TextStyle(fontFamily:'Inter',
                  fontSize:12,color:Color(0xFFB42318)))],
            const SizedBox(height:20),
            if(_editable)Sign2DigitalPrimaryButton(
              key:const Key('general-document-save'),
              label:'Save Draft',enabled:!_loading,
              loading:_busy,onPressed:_save),
            if(_saved?.status=='draft')...[
              const SizedBox(height:12),
              Sign2DigitalOutlinedButton(label:'Mark Reviewed',
                enabled:!_busy,onPressed:()=>_transition('review'))],
            if(_saved?.status=='reviewed')...[
              const SizedBox(height:12),
              Sign2DigitalPrimaryButton(label:'Approve Document',
                enabled:!_busy,onPressed:()=>_transition('approve'))],
            if(_saved?.status=='approved')const Padding(
              padding:EdgeInsets.symmetric(vertical:20),
              child:Text('Approved revision is locked. Official PDF, signing '
                'and customer delivery are Stage 2 actions.',
                style:TextStyle(fontFamily:'Inter',fontSize:12,
                  color:AppColors.placeholder))),
          ]),
        ))),
      ])));
  }
}
