import 'dart:io';
import '../../../../core/widgets/sign2digital_selection_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sign2digital_ai_voice_button.dart';
import '../../../../core/widgets/sign2digital_checkbox.dart';
import '../../../../core/widgets/sign2digital_header.dart';
import '../../../../core/widgets/sign2digital_outlined_container.dart';
import '../../../../core/widgets/sign2digital_primary_button.dart';
import '../../../../core/widgets/sign2digital_selection_field.dart';
import '../../../jobs/data/mock_jobs.dart';
import '../../../jobs/data/remote_job_repository.dart';
import '../../../auth/data/mobile_auth_repository.dart';
import '../../data/remote_general_document_repository.dart';
import 'general_document_editor_screen.dart';
import '../../../jobs/domain/job_model.dart';
import '../../../jobs/models/extracted_job_details.dart';
import '../../../jobs/presentation/screens/job_notes_screen.dart';
import '../../../jobs/presentation/widgets/ai_voice_flow_dialog.dart';
import '../../../jobs/services/voice_job_extraction_service.dart';
import '../../../jobs/services/voice_recorder_service.dart';
import '../../domain/document_record.dart';
import 'document_details_screen.dart';

enum AiDocumentSection {
  projectDetails('Project details'),
  workPerformed('Work Performed'),
  materialUsed('Material Used'),
  photos('Photos'),
  labourAndTime('Labour & Time Summary'),
  clientComments('Client Comments (if any)');

  const AiDocumentSection(this.label);
  final String label;
}

class AiDocumentGenerationRequest {
  const AiDocumentGenerationRequest({
    required this.documentDate,
    required this.job,
    required this.sections,
    required this.instructions,
  });

  final DateTime documentDate;
  final JobModel job;
  final List<AiDocumentSection> sections;
  final String instructions;
}

/// Must generate AND persist a real result before returning a DocumentRecord.
/// An absent callback never produces a fictitious Generated document.
typedef AiDocumentGenerator = Future<DocumentRecord> Function(
    AiDocumentGenerationRequest request);

/// Figma-aligned form reusing existing voice, header, fields, checkboxes and
/// primary action. This screen intentionally has no bottom navigation.
class GenerateAiDocumentScreen extends StatefulWidget {
  const GenerateAiDocumentScreen({
    super.key,
    this.jobs,
    this.initialJob,
    this.documentGenerator,
    this.voiceRecorderFactory,
    this.voiceExtractionService,
    this.datePicker,
  });

  final List<JobModel>? jobs;
  final JobModel? initialJob;
  final AiDocumentGenerator? documentGenerator;
  final VoiceRecorderService Function()? voiceRecorderFactory;
  final VoiceJobExtractionService? voiceExtractionService;
  final Future<DateTime?> Function(BuildContext, DateTime)? datePicker;

  @override
  State<GenerateAiDocumentScreen> createState() =>
      _GenerateAiDocumentScreenState();
}

class _GenerateAiDocumentScreenState extends State<GenerateAiDocumentScreen> {
  final _instructions = TextEditingController();
  final _selected = <AiDocumentSection>{...AiDocumentSection.values};
  DateTime? _date;
  JobModel? _job;
  String? _error;
  bool _generating = false;
  bool _voiceOpen = false;
  List<JobModel>? _liveJobs;
  final _creationKey='m18-project-'+DateTime.now().microsecondsSinceEpoch.toString();

  List<JobModel> get _jobs=>widget.jobs??_liveJobs??(
    MobileAuthRepository.shared.isSignedIn?const <JobModel>[]
      :MockJobsData.jobs);

  Future<void> _loadLiveJobs() async{
    try{
      final jobs=await RemoteJobRepository.shared.listJobs();
      if(mounted)setState(()=>_liveJobs=jobs.where(
        (j)=>j.category!=JobCategory.archived).toList());
    }catch(_){
      if(mounted)setState(()=>_error='Unable to load current company jobs.');
    }
  }

  @override
  void initState() {
    super.initState();
    _job = widget.initialJob;
    if(widget.jobs==null&&MobileAuthRepository.shared.isSignedIn){
      _loadLiveJobs();
    }
  }

  @override
  void dispose() {
    _instructions.dispose();
    super.dispose();
  }

  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  static String _dateText(DateTime value) =>
      '${_months[value.month - 1]} ${value.day}, ${value.year}';

  void _notice(String message) {
    if (!mounted) { return; }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _chooseDate() async {
    if (_generating) { return; }
    final initial = _date ?? DateTime.now();
    final picked = widget.datePicker != null
        ? await widget.datePicker!(context, initial)
        : await showDatePicker(
            context: context,
            initialDate: initial,
            firstDate: DateTime(2000),
            lastDate: DateTime(2100),
          );
    if (picked != null && mounted) {
      setState(() {
        _date = DateTime(picked.year, picked.month, picked.day);
        _error = null;
      });
    }
  }

  Future<void> _chooseJob() async {
    if (_generating) { return; }
    final chosen = await Sign2DigitalSelectionSheet.showCustom<JobModel>(
      title: 'Select Job / Project',
      icon: Icons.work_outline_rounded,
      subtitle: 'Choose the job for your document',
      context: context,
      isScrollControlled: true,
      builder: (sheet) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheet).height * .7),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Flexible(child: ListView.builder(
              shrinkWrap: true,
              itemCount: _jobs.length,
              itemBuilder: (context, index) {
                final job = _jobs[index];
                return ListTile(
                  key: Key('generate-ai-job-${job.id}'),
                  selected: _job?.id == job.id,
                  trailing: _job?.id == job.id
                      ? const Icon(Icons.check_circle_rounded,
                          color: AppColors.primary) : null,
                  title: Text(job.title, maxLines: 2),
                  subtitle: Text('${job.referenceNumber} • ${job.clientName}'),
                  onTap: () => Navigator.of(sheet).pop(job),
                );
              },
            )),
          ]),
        ),
      ),
    );
    if (chosen != null && mounted) {
      setState(() { _job = chosen; _error = null; });
    }
  }

  Future<void> _remoteVoice() async{
    var transcript='';
    try{
      await showDialog<void>(
        context:context,barrierDismissible:false,
        builder:(_)=>AiVoiceFlowDialog(
          recorder:widget.voiceRecorderFactory?.call()??
            LocalVoiceRecorderService(),
          extraction:OpenAiVoiceJobExtractionService(),
          rawAudioMode:true,recordingTitle:'Record Document Details',
          onAudioProcessed:(path) async {
            final file=File(path);
            transcript=await RemoteGeneralDocumentRepository.shared.transcribe(
              await file.readAsBytes(),'project-document.m4a');
            if(await file.exists())await file.delete();
          },
        ));
      if(!mounted||transcript.isEmpty)return;
      final accepted=await showDialog<bool>(context:context,
        builder:(dialog)=>AlertDialog(
          title:const Text('Use dictated document notes?'),
          content:Text(transcript),
          actions:[
            TextButton(onPressed:()=>Navigator.pop(dialog,false),
              child:const Text('Keep current notes')),
            TextButton(onPressed:()=>Navigator.pop(dialog,true),
              child:const Text('Use transcript')),
          ]));
      if(accepted==true&&mounted){
        setState((){
          _instructions.text=_instructions.text.trim().isEmpty
              ?transcript:_instructions.text.trim()+'\n'+transcript;
          _error=null;
        });
      }
    }catch(_){
      if(mounted)setState(()=>_error=
        'Voice transcription is unavailable. Keep entering notes manually.');
    }
  }

  Future<void> _voice() async {
    if (_voiceOpen || _generating) { return; }
    setState(() => _voiceOpen = true);
    if(MobileAuthRepository.shared.isSignedIn &&
        widget.voiceExtractionService==null){
      try{await _remoteVoice();}
      finally{if(mounted)setState(()=>_voiceOpen=false);}
      return;
    }
    try {
      final result = await showDialog<ExtractedJobDetails>(
        context: context,
        barrierDismissible: false,
        barrierColor: const Color(0x80000000),
        builder: (_) => AiVoiceFlowDialog(
          recorder: widget.voiceRecorderFactory?.call() ??
              LocalVoiceRecorderService(),
          extraction: widget.voiceExtractionService ??
              OpenAiVoiceJobExtractionService(),
          recordingTitle: 'Record Document Details',
        ),
      );
      if (!mounted || result == null) { return; }
      final suggestedText = result.description?.trim();
      final suggestedDate = result.startDate;
      final canFillText = suggestedText != null && suggestedText.isNotEmpty &&
          _instructions.text.trim().isEmpty;
      final canFillDate = suggestedDate != null && _date == null;
      if (!canFillText && !canFillDate) {
        _notice('No empty document fields match the extracted suggestions.');
        return;
      }
      final approved = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: const Text('Use AI suggestions?'),
          content: Text([
            if (canFillDate) 'Document Date: ${_dateText(suggestedDate)}',
            if (canFillText) 'Additional instruction: $suggestedText',
            'Existing entries will not be replaced.',
          ].join('\n\n')),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialog).pop(false),
              child: const Text('Keep my entries'),
            ),
            TextButton(
              key: const Key('generate-ai-accept-voice'),
              onPressed: () => Navigator.of(dialog).pop(true),
              child: const Text('Apply suggestions'),
            ),
          ],
        ),
      );
      if (approved != true || !mounted) { return; }
      setState(() {
        if (canFillDate) { _date = suggestedDate; }
        if (canFillText) { _instructions.text = suggestedText; }
        _error = null;
      });
    } catch (_) {
      _notice('Unable to process the recording. Your form was not changed.');
    } finally {
      if (mounted) { setState(() => _voiceOpen = false); }
    }
  }

  String? _validate() {
    if (_date == null) { return 'Select a document date.'; }
    if (_job == null || !_jobs.any((job) => job.id == _job!.id)) {
      return 'Select a valid Job / Project.';
    }
    if (_selected.isEmpty) { return 'Include at least one section.'; }
    return null;
  }

  AiDocumentGenerationRequest _request() => AiDocumentGenerationRequest(
    documentDate: _date!,
    job: _job!,
    sections: List<AiDocumentSection>.unmodifiable(
      AiDocumentSection.values.where(_selected.contains)),
    instructions: _instructions.text.trim(),
  );

  Future<void> _openExistingWorkflow() async {
    final job = _job;
    if (job == null) { return; }
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => JobNotesScreen(job: job),
      ),
    );
  }

  /// Project form is a human-reviewed AI suggestion, never an auto-approval.
  Future<DocumentRecord> _generateLive(AiDocumentGenerationRequest request) async{
    final repo=RemoteGeneralDocumentRepository.shared;
    final job=int.tryParse(request.job.id);
    final client=int.tryParse(request.job.clientId);
    if(job==null||client==null)throw StateError('Select an authorized job.');
    final sections=request.sections.map((s)=>s.label).join(', ');
    final instructions='Prepare a project document draft with these requested '+
      'sections: '+sections+'. Date requested: '+
      request.documentDate.toIso8601String().substring(0,10)+
      '. User notes: '+request.instructions+
      '. Where no evidence is present, mark the section [Needs review].';
    final suggestion=await repo.suggest(
      type:'custom',locale:'en',instructions:instructions,
      clientId:client,jobId:job);
    if(!mounted)throw StateError('Editor is closed.');
    final approved=await showDialog<bool>(context:context,
      builder:(dialog)=>AlertDialog(
        title:const Text('Review Document Suggestion'),
        content:SizedBox(height:240,child:SingleChildScrollView(
          child:Text(suggestion.title+'\n\n'+
            suggestion.blocks.map((b)=>b.text).join('\n\n')))),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(dialog,false),
            child:const Text('Keep Editing')),
          TextButton(onPressed:()=>Navigator.pop(dialog,true),
            child:const Text('Save Draft')),
        ]));
    if(approved!=true)throw StateError('Suggestion was not accepted.');
    final saved=await repo.save(suggestion,createRequestKey:_creationKey);
    return saved.toDocumentRecord();
  }

  Future<void> _generate() async {
    if (_generating) { return; }
    FocusManager.instance.primaryFocus?.unfocus();
    final issue = _validate();
    if (issue != null) { setState(() => _error = issue); return; }

    final generator=widget.documentGenerator??(
      MobileAuthRepository.shared.isSignedIn?_generateLive:null);
    if (generator == null) {
      final openNotes = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: const Text('AI document generation not connected'),
          content: const Text(
            'This six-section document form has no connected AI generator. '
            'The existing Job Notes → Convert Document workflow can prepare '
            'an AI quote from a real note. Your selections will remain here.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialog).pop(false),
              child: const Text('Keep editing'),
            ),
            TextButton(
              key: const Key('generate-ai-open-existing'),
              onPressed: () => Navigator.of(dialog).pop(true),
              child: const Text('Open Job Notes'),
            ),
          ],
        ),
      );
      if (openNotes == true && mounted) {
        await _openExistingWorkflow();
      }
      return;
    }

    setState(() { _generating = true; _error = null; });
    try {
      final generated = await generator(_request());
      final liveGeneral=generated.id.startsWith('general-') &&
          generated.status.toLowerCase()=='draft';
      if (generated.id.trim().isEmpty || generated.demoOnly ||
          (!liveGeneral && (generated.project.trim().isEmpty ||
            generated.category != DocumentCategory.reports ||
            generated.status.toLowerCase() != 'generated'))) {
        throw StateError('The AI service did not return a saved document.');
      }
      if (!mounted) { return; }
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => liveGeneral
              ? GeneralDocumentEditorScreen(
                  documentId:int.parse(generated.id.substring(8)))
              : DocumentDetailsScreen(
                  documentId:generated.id,document:generated),
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(() => _error =
          'Document generation failed. Your entries are preserved. Retry when ready.');
      }
    } finally {
      if (mounted) { setState(() => _generating = false); }
    }
  }

  Widget _sectionCheckbox(AiDocumentSection section) => Row(
    key: Key('generate-ai-section-${section.name}'),
    children: [
      Sign2DigitalCheckbox(
        value: _selected.contains(section),
        label: section.label,
        showLabel: false,
        boxSize: 16,
        onChanged: (value) => setState(() {
          if (value) { _selected.add(section); }
          else { _selected.remove(section); }
          _error = null;
        }),
      ),
      const SizedBox(width: 10),
      Expanded(child: InkWell(
        onTap: () => setState(() {
          if (!_selected.add(section)) { _selected.remove(section); }
          _error = null;
        }),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Text(section.label, style: const TextStyle(
            fontFamily: 'Inter', fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.placeholder,
          )),
        ),
      )),
    ],
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.white,
    resizeToAvoidBottomInset: true,
    body: SafeArea(child: Column(children: [
      Sign2DigitalHeader(
        title: 'AI Document',
        onBack: () => Navigator.of(context).maybePop(),
      ),
      Expanded(child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          key: const Key('generate-ai-document-scroll'),
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          children: [
            Sign2DigitalAiVoiceButton(
              key: const Key('generate-ai-voice'),
              onPressed: _voice,
            ),
            const SizedBox(height: 20),
            Sign2DigitalSelectionField(
              key: const Key('generate-ai-date'),
              label: 'Document Date',
              iconAsset: 'assets/icons/calendar-outlined.svg',
              hintText: 'August 25, 2026',
              value: _date == null ? null : _dateText(_date!),
              onTap: _chooseDate,
            ),
            const SizedBox(height: 20),
            Sign2DigitalSelectionField(
              key: const Key('generate-ai-job'),
              label: 'Job / Project',
              iconAsset: 'assets/icons/description.svg',
              hintText: 'e.g, Site renovation',
              value: _job?.title,
              trailing: const Icon(Icons.keyboard_arrow_down_rounded,
                color: AppColors.secondaryText),
              onTap: _chooseJob,
            ),
            const SizedBox(height: 20),
            const Text('Include Sections', style: TextStyle(
              fontFamily: 'Inter', fontSize: 16,
              fontWeight: FontWeight.w600, color: AppColors.dark)),
            const SizedBox(height: 15),
            for (var i = 0; i < AiDocumentSection.values.length; i++) ...[
              _sectionCheckbox(AiDocumentSection.values[i]),
              if (i < AiDocumentSection.values.length - 1)
                const SizedBox(height: 15),
            ],
            const SizedBox(height: 20),
            const Text('Additional Instruction (optional)',
              style: TextStyle(fontFamily: 'Inter', fontSize: 16,
                fontWeight: FontWeight.w600, color: AppColors.dark)),
            const SizedBox(height: 10),
            Sign2DigitalOutlinedContainer(
              constraints: const BoxConstraints(minHeight: 84),
              padding: const EdgeInsets.all(20),
              child: TextField(
                key: const Key('generate-ai-instructions'),
                controller: _instructions,
                minLines: 3,
                maxLines: 6,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Kitchen renovations, processes of renovating, '
                    'color selection, and labour work',
                  border: InputBorder.none,
                  isCollapsed: true,
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                key: const Key('generate-ai-validation'),
                style: const TextStyle(fontFamily: 'Inter', fontSize: 12,
                  color: Color(0xFFB42318))),
            ],
          ],
        ),
      ))),
      Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: Sign2DigitalPrimaryButton(
            key: const Key('generate-ai-submit'),
            label: 'Generate Document',
            leading: SvgPicture.asset('assets/icons/stars.svg',
              width: 20, height: 20,
              colorFilter: const ColorFilter.mode(
                Colors.white, BlendMode.srcIn)),
            loading: _generating,
            enabled: !_voiceOpen,
            onPressed: _generate,
          ),
        ),
      )),
    ])),
  );
}
