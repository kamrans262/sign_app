import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sign2digital_header.dart';
import '../../../../core/widgets/sign2digital_input_field.dart';
import '../../../../core/widgets/sign2digital_primary_button.dart';
import '../../../clients/presentation/widgets/sign2digital_details_tabs.dart';
import '../../data/job_note_local_store.dart';
import '../../domain/job_model.dart';
import '../../domain/job_note_model.dart';
import '../../services/voice_job_extraction_service.dart';
import '../../services/voice_recorder_service.dart';
import '../widgets/ai_voice_flow_dialog.dart';
import '../widgets/sign2digital_note_visibility_card.dart';

/// Session-only editor: recordings are local and notes never auto-publish.
class AddJobNoteScreen extends StatefulWidget {
  const AddJobNoteScreen({
    super.key,
    required this.job,
    required this.store,
    required this.initialType,
    required this.initialVisibility,
    this.voiceRecorderFactory,
  });

  final JobModel job;
  final JobNoteLocalStore store;
  final JobNoteType initialType;
  final JobNoteVisibility initialVisibility;
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

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    _visibility = widget.initialVisibility;
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
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

  void _save() {
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
    try {
      widget.store.add(JobNoteModel(
        id: 'local-note-${widget.job.id}-${now.microsecondsSinceEpoch}',
        jobId: widget.job.id,
        title: title,
        body: body,
        createdAt: now,
        type: _type == JobNoteType.voice && body.isNotEmpty
            ? JobNoteType.textWithAudio : _type,
        visibility: _visibility,
        audioPath: _audioPath,
      ));
      Navigator.of(context).pop(true);
    } catch (error) {
      _message('Unable to save note: $error');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.white,
    resizeToAvoidBottomInset: true,
    body: SafeArea(child: Column(children: [
      Sign2DigitalHeader(title: 'Job Notes',
          onBack: () => Navigator.of(context).maybePop()),
      Expanded(child: SingleChildScrollView(
        key: const Key('add-job-note-scroll'),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 25),
        child: Center(child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Add Notes', style: TextStyle(
                fontFamily: 'Inter', fontSize: 24,
                fontWeight: FontWeight.w700, color: AppColors.dark)),
              const SizedBox(height: 20),
              Sign2DigitalDetailsTabs(
                labels: const ['Text Note', 'Voice Note'],
                selectedIndex: _type == JobNoteType.text ? 0 : 1,
                onSelected: (value) => setState(() {
                  _type = value == 0 ? JobNoteType.text : JobNoteType.voice;
                }),
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
              if (_type != JobNoteType.text) ...[
                const SizedBox(height: 15),
                OutlinedButton.icon(
                  key: const Key('job-note-record'),
                  onPressed: _recording ? null : _record,
                  icon: const Icon(Icons.mic_none_rounded),
                  label: Text(_audioPath == null
                      ? 'Record Voice Note' : 'Replace Recording'),
                ),
                if (_audioPath != null)
                  const Text('Audio recorded locally and ready to attach.',
                    key: Key('job-note-audio-ready'),
                    style: TextStyle(color: AppColors.primary)),
              ],
              const SizedBox(height: 20),
              const Text('Visibility', style: TextStyle(
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
              Sign2DigitalPrimaryButton(
                key: const Key('job-note-save'),
                label: 'Save Note', onPressed: _save),
            ],
          ),
        )),
      )),
    ])),
  );
}
