import 'package:flutter/material.dart';
import 'package:sign2digital/core/localization/app_strings.dart';
import 'package:sign2digital/core/localization/localized_ui_text.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sign2digital_header.dart';
import '../../../../core/widgets/sign2digital_input_field.dart';
import '../../../../core/widgets/sign2digital_primary_button.dart';
import '../../../clients/presentation/widgets/sign2digital_details_tabs.dart';
import '../../data/job_note_local_store.dart';
import '../../data/remote_job_media_repository.dart';
import '../../domain/job_model.dart';
import '../../domain/job_note_model.dart';
import '../../services/voice_job_extraction_service.dart';
import '../../services/voice_recorder_service.dart';
import '../widgets/ai_voice_flow_dialog.dart';
import '../widgets/sign2digital_note_visibility_card.dart';

/// Existing editor; persisted jobs upload explicitly via the M11 Laravel API.
class AddJobNoteScreen extends StatefulWidget {
  const AddJobNoteScreen({
    super.key,
    required this.job,
    this.store,
    required this.initialType,
    required this.initialVisibility,
    this.existingNote,
    this.voiceRecorderFactory,
  });

  final JobModel job;
  final JobNoteLocalStore? store;
  final JobNoteType initialType;
  final JobNoteVisibility initialVisibility;
  final JobNoteModel? existingNote;
  final VoiceRecorderService Function()? voiceRecorderFactory;

  @override
  State<AddJobNoteScreen> createState() => _AddJobNoteScreenState();
}

class _AddJobNoteScreenState extends State<AddJobNoteScreen> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  late JobNoteVisibility _visibility;
  late JobNoteType _type;
  String? _audioPath;
  bool _recording = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _type = widget.existingNote?.type ?? widget.initialType;
    _visibility = widget.existingNote?.visibility ?? widget.initialVisibility;
    if (widget.existingNote != null) {
      _title.text = widget.existingNote!.title;
      _body.text = widget.existingNote!.body;
      _audioPath = widget.existingNote!.audioPath;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.of(context).tr(value))));
  }

  Future<void> _record() async {
    if (_recording) return;
    setState(() => _recording = true);
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AiVoiceFlowDialog(
          recorder: widget.voiceRecorderFactory?.call() ??
              LocalVoiceRecorderService(),
          extraction: OpenAiVoiceJobExtractionService(),
          recordingTitle: 'Record Job Note',
          rawAudioMode: true,
          onQuoteAudioSaved: (path) {
            if (mounted) setState(() => _audioPath = path);
          },
        ),
      );
    } catch (_) {
      _message('Unable to record audio. Check microphone permission.');
    } finally {
      if (mounted) setState(() => _recording = false);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final title = _title.text.trim();
    final body = _body.text.trim();
    if (title.isEmpty) {
      _message('Enter a note title.');
      return;
    }
    if (_type == JobNoteType.voice && _audioPath == null) {
      _message('Record and save audio before adding a voice note.');
      return;
    }
    if (_type == JobNoteType.text && body.isEmpty) {
      _message('Enter note text before saving.');
      return;
    }
    final now = DateTime.now();
    setState(() => _saving = true);
    try {
      if (widget.store == null &&
          RemoteJobMediaRepository.isLiveJob(widget.job.id)) {
        if (widget.existingNote != null) {
          await RemoteJobMediaRepository.shared.updateNote(
            widget.existingNote!, title: title, body: body,
            visibility: _visibility);
        } else {
          await RemoteJobMediaRepository.shared.createNote(
            jobId: widget.job.id, title: title, body: body,
            type: _type, visibility: _visibility, audioPath: _audioPath);
        }
      } else {
        final changed = JobNoteModel(
          id: widget.existingNote?.id ??
              'local-note-${widget.job.id}-${now.microsecondsSinceEpoch}',
          jobId: widget.job.id,
          title: title, body: body,
          createdAt: widget.existingNote?.createdAt ?? now,
          type: _type, visibility: _visibility, audioPath: _audioPath);
        if (widget.existingNote != null) {
          widget.store!.replace(changed);
        } else {
          widget.store!.add(changed);
        }
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      _message('Unable to save note: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.white,
    resizeToAvoidBottomInset: true,
    body: SafeArea(child: Column(children: [
      Sign2DigitalHeader(translateTitle: true, title: 'Job Notes',
          onBack: () => Navigator.of(context).maybePop()),
      Expanded(child: SingleChildScrollView(
        key: const Key('add-job-note-scroll'),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 25),
        child: Center(child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.existingNote == null ? 'Add Notes' : 'Edit Note', style: const TextStyle(
                fontFamily: 'Inter', fontSize: 24,
                fontWeight: FontWeight.w700, color: AppColors.dark)),
              const SizedBox(height: 20),
              Sign2DigitalDetailsTabs(
                labels: const ['Text Note', 'Voice Note'],
                selectedIndex: _type == JobNoteType.text ? 0 : 1,
                onSelected: (value) {
                  if (widget.existingNote != null) return;
                  setState(() {
                    _type = value == 0 ? JobNoteType.text : JobNoteType.voice;
                  });
                },
              ),
              const SizedBox(height: 20),
              Sign2DigitalInputField(
                label: 'Title', hintText: 'e.g. Site meeting',
                iconAsset: 'assets/icons/description.svg',
                controller: _title),
              const SizedBox(height: 20),
              Sign2DigitalInputField(
                label: 'Note', hintText: 'Enter job observations or a transcript',
                iconAsset: 'assets/icons/description.svg',
                controller: _body, minLines: 3, maxLines: 6),
              if (_type != JobNoteType.text && widget.existingNote == null) ...[
                const SizedBox(height: 15),
                OutlinedButton.icon(
                  key: const Key('job-note-record'),
                  onPressed: _recording ? null : _record,
                  icon: const Icon(Icons.mic_none_rounded),
                  label: Text(_audioPath == null
                      ? 'Record Voice Note' : 'Replace Recording'),
                ),
                if (_audioPath != null)
                  const LocalizedUiText('Audio recorded locally and ready to attach.',
                    key: Key('job-note-audio-ready'),
                    style: TextStyle(color: AppColors.primary)),
              ],
              const SizedBox(height: 20),
              const LocalizedUiText('Visibility', style: TextStyle(
                fontFamily: 'Inter', fontSize: 18,
                fontWeight: FontWeight.w600, color: AppColors.dark)),
              const SizedBox(height: 10),
              LayoutBuilder(builder: (context, constraints) {
                final cards = [
                  Sign2DigitalNoteVisibilityCard(
                    visibility: JobNoteVisibility.privateNote,
                    selected: _visibility == JobNoteVisibility.privateNote,
                    onTap: () => setState(() =>
                        _visibility = JobNoteVisibility.privateNote)),
                  Sign2DigitalNoteVisibilityCard(
                    visibility: JobNoteVisibility.customerFacing,
                    selected: _visibility == JobNoteVisibility.customerFacing,
                    onTap: () => setState(() =>
                        _visibility = JobNoteVisibility.customerFacing)),
                ];
                if (constraints.maxWidth < 270) {
                  return Column(children: [
                    cards.first, const SizedBox(height: 12), cards.last,
                  ]);
                }
                return Row(children: [
                  Expanded(child: cards.first), const SizedBox(width: 12),
                  Expanded(child: cards.last),
                ]);
              }),
              const SizedBox(height: 10),
              const Text('Customer-facing is a label only. This note is not '
                  'sent or visible to customers until a secure backend '
                  'explicitly publishes it.',
                style: TextStyle(fontSize: 12, color: AppColors.placeholder)),
              const SizedBox(height: 25),
            ],
          ),
        )),
      )),
    ])),
    bottomNavigationBar: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        child: Align(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Sign2DigitalPrimaryButton(
              key: const Key('job-note-save'),
              label: widget.existingNote == null ? 'Save Note' : 'Save Changes',
              onPressed: _save, enabled: !_saving,
            ),
          ),
        ),
      ),
    ),
  );
}
