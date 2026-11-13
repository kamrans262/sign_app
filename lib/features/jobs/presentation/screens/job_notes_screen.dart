import '../../../../core/widgets/sign2digital_form_dialog.dart';
import '../../../../core/navigation/sign2digital_navigation.dart';
import '../../../../core/services/active_company_session.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sign2digital_bottom_navigation_bar.dart';
import '../../../../core/widgets/sign2digital_header.dart';
import '../../../../core/widgets/sign2digital_primary_button.dart';
import '../../../clients/presentation/widgets/sign2digital_details_tabs.dart';
import '../../data/job_note_local_store.dart';
import '../../data/remote_job_media_repository.dart';
import '../../services/voice_recorder_service.dart';
import '../../domain/job_model.dart';
import '../../domain/job_note_model.dart';
import '../widgets/sign2digital_job_info_banner.dart';
import '../widgets/sign2digital_job_note_card.dart';
import '../widgets/sign2digital_note_visibility_card.dart';
import 'convert_document_screen.dart';
import 'add_job_note_screen.dart';

/// Handoff for a future Add Notes editor. Selection is user preference,
/// not a replacement for server-side permissions.
typedef AddJobNoteCallback = void Function(
  String jobId,
  JobNoteVisibility visibility,
  JobNoteType type,
);

class JobNotesScreen extends StatefulWidget {
  const JobNotesScreen({
    super.key,
    required this.job,
    this.notes,
    this.onNoteTap,
    this.onAddNotes,
    this.onTabSelected,
    this.store,
    this.voiceRecorderFactory,
  });

  final JobModel job;
  final List<JobNoteModel>? notes;
  final ValueChanged<JobNoteModel>? onNoteTap;
  final AddJobNoteCallback? onAddNotes;
  final ValueChanged<int>? onTabSelected;
  final JobNoteLocalStore? store;
  final VoiceRecorderService Function()? voiceRecorderFactory;

  @override
  State<JobNotesScreen> createState() => _JobNotesScreenState();
}

class _JobNotesScreenState extends State<JobNotesScreen> {
  int _selectedTab = 0;
  JobNoteVisibility _visibility = JobNoteVisibility.privateNote;
  bool _showBanner = true;
  late final JobNoteLocalStore _store;
  List<JobNoteModel>? _remoteNotes;
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool get _remote => widget.store == null && widget.notes == null &&
      RemoteJobMediaRepository.isLiveJob(widget.job.id);

  Future<void> _loadRemoteNotes() async {
    if (!_remote) return;
    try {
      final notes = await RemoteJobMediaRepository.shared.listNotes(widget.job.id);
      if (mounted) setState(() => _remoteNotes = notes);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Unable to load saved notes: $error')));
      }
    }
  }

  Future<void> _playNote(JobNoteModel note) async {
    try {
      if (!_remote || !note.audioPath!.startsWith('remote:')) return;
      final audio = await RemoteJobMediaRepository.shared.audioFile(note.jobId, note.id);
      if (!mounted) return;
      final folder = await getTemporaryDirectory();
      final file = File('${folder.path}/sign2digital_job_${note.jobId}_note_${note.id}.${audio.extension}');
      await file.writeAsBytes(audio.bytes, flush: true);
      await _audioPlayer.stop();
      await _audioPlayer.play(DeviceFileSource(file.path));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Unable to play this voice note: $error')));
      }
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _store = widget.store ?? JobNoteLocalStore.shared;
    if (_remote) _loadRemoteNotes();
  }

  List<JobNoteModel> get _filteredNotes {
    final source = widget.notes ?? _remoteNotes ??
        (_remote ? <JobNoteModel>[] : _store.notesFor(widget.job.id));
    return source
        .where((note) {
          if (note.jobId != widget.job.id) {
            return false;
          }
          // A text note with an audio attachment belongs in Text Notes.
          return _selectedTab == 0 ? !note.isVoiceOnly : note.isVoiceOnly;
        })
        .toList(growable: false);
  }

  void _openNote(JobNoteModel note) {
    final callback = widget.onNoteTap;
    if (callback != null) {
      callback(note);
      return;
    }
    showDialog<void>(
      context: context,
      barrierColor: const Color(0x80000000),
      builder: (dialogContext) => Sign2DigitalFormDialog(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(note.title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(note.body),
              const SizedBox(height: 12),
              Text(
                note.timestampLabel(DateTime.now()),
                style: const TextStyle(color: AppColors.placeholder),
              ),
              if (note.audioPath != null) ...[
                const SizedBox(height: 12),
                Text(_remote ? 'Voice recording attached to this job.' :
                    'Voice recording saved on this device.'),
              ],
              if (note.type != JobNoteType.text && note.audioPath == null) ...[
                const SizedBox(height: 12),
                const Text('No playable audio is attached to this demo note.'),
              ],
            ],
          ),
        ),
        actions: [
          if (note.audioPath != null && _remote)
            TextButton(
              onPressed: () => _playNote(note),
              child: const Text('Play Recording'),
            ),
          if (note.visibility == JobNoteVisibility.privateNote)
            TextButton(
              key: const Key('job-note-convert'),
            onPressed: () {
              Navigator.of(dialogContext).pop();
              Sign2DigitalNavigation.push<void>(context,MaterialPageRoute<void>(
                builder: (_) => ConvertDocumentScreen(
                  note: note, onTabSelected: widget.onTabSelected,
                ),
              ));
            },
            child: const Text('Convert to Document'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _addNotes() async {
    final callback = widget.onAddNotes;
    if (callback != null) {
      callback(
        widget.job.id,
        _visibility,
        _selectedTab == 0 ? JobNoteType.text : JobNoteType.voice,
      );
    } else {
      final saved = await Sign2DigitalNavigation.push<bool>(context,
        MaterialPageRoute(builder: (_) => AddJobNoteScreen(
          job: widget.job,
          store: _remote ? null : _store,
          initialType: _selectedTab == 0 ? JobNoteType.text : JobNoteType.voice,
          initialVisibility: _visibility,
          voiceRecorderFactory: widget.voiceRecorderFactory,
        )),
      );
      if (mounted && saved == true) {
        if (_remote) {
          await _loadRemoteNotes();
        } else {
          setState(() {});
        }
      }
    }
  }

  void _selectNavigation(int index) {
    if (index == 1) {
      return;
    }
    Navigator.of(context).maybePop();
    widget.onTabSelected?.call(index);
  }

  Widget _visibilityOptions(double availableWidth) {
    final first = Sign2DigitalNoteVisibilityCard(
      visibility: JobNoteVisibility.privateNote,
      selected: _visibility == JobNoteVisibility.privateNote,
      onTap: () => setState(() => _visibility = JobNoteVisibility.privateNote),
    );
    final second = Sign2DigitalNoteVisibilityCard(
      visibility: JobNoteVisibility.customerFacing,
      selected: _visibility == JobNoteVisibility.customerFacing,
      onTap: () =>
          setState(() => _visibility = JobNoteVisibility.customerFacing),
    );
    if (availableWidth < 270) {
      return Column(children: [first, const SizedBox(height: 12), second]);
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: first),
          const SizedBox(width: 12),
          Expanded(child: second),
        ],
      ),
    );
  }

  Widget _noteList(double width, List<JobNoteModel> notes) {
    if (notes.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 26),
        child: Center(
          child: Text(
            _selectedTab == 0 ? 'No text notes yet.' : 'No voice notes yet.',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: AppColors.placeholder,
            ),
          ),
        ),
      );
    }
    // Two cards can use the additional landscape/tablet width without
    // widening a single line of copy to several hundred pixels.
    final columns = width >= 800 ? 2 : 1;
    if (columns == 1) {
      return Column(
        children: [
          for (var index = 0; index < notes.length; index++) ...[
            if (index != 0) const SizedBox(height: 20),
            Sign2DigitalJobNoteCard(
              note: notes[index],
              onTap: () => _openNote(notes[index]),
            ),
          ],
        ],
      );
    }
    return Column(
      children: [
        for (var index = 0; index < notes.length; index += 2) ...[
          if (index != 0) const SizedBox(height: 20),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Sign2DigitalJobNoteCard(
                    note: notes[index],
                    onTap: () => _openNote(notes[index]),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: index + 1 < notes.length
                      ? Sign2DigitalJobNoteCard(
                          note: notes[index + 1],
                          onTap: () => _openNote(notes[index + 1]),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final notes = _filteredNotes;
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Sign2DigitalHeader(
              title: 'Job Notes',
              onBack: () => Navigator.of(context).maybePop(),
            ),
            Expanded(
              child: SingleChildScrollView(
                key: const Key('job-notes-scroll'),
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_showBanner) ...[
                          Sign2DigitalJobInfoBanner(
                            title: widget.job.title,
                            description: widget.job.description,
                            onDismiss: () =>
                                setState(() => _showBanner = false),
                          ),
                          const SizedBox(height: 20),
                        ],
                        const Text(
                          'Job Notes',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: AppColors.dark,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Keep track of important information',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.secondaryText,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Sign2DigitalDetailsTabs(
                          labels: const ['Text Notes', 'Voice Notes'],
                          selectedIndex: _selectedTab,
                          onSelected: (value) =>
                              setState(() => _selectedTab = value),
                        ),
                        const SizedBox(height: 20),
                        _visibilityOptions(constraints.maxWidth),
                        const SizedBox(height: 20),
                        _noteList(constraints.maxWidth, notes),
                        const SizedBox(height: 36),
                        if (ActiveCompanySession.canWrite('jobs'))
                        Sign2DigitalPrimaryButton(
                          label: '＋ Add Notes',
                          onPressed: _addNotes,
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Sign2DigitalBottomNavigationBar(
        selectedIndex: 1,
        onSelected: _selectNavigation,
      ),
    );
  }
}
