import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sign2digital_bottom_navigation_bar.dart';
import '../../../../core/widgets/sign2digital_header.dart';
import '../../../../core/widgets/sign2digital_primary_button.dart';
import '../../../clients/presentation/widgets/sign2digital_details_tabs.dart';
import '../../data/demo_job_notes.dart';
import '../../domain/job_model.dart';
import '../../domain/job_note_model.dart';
import '../widgets/sign2digital_job_info_banner.dart';
import '../widgets/sign2digital_job_note_card.dart';
import '../widgets/sign2digital_note_visibility_card.dart';

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
  });

  final JobModel job;
  final List<JobNoteModel>? notes;
  final ValueChanged<JobNoteModel>? onNoteTap;
  final AddJobNoteCallback? onAddNotes;
  final ValueChanged<int>? onTabSelected;

  @override
  State<JobNotesScreen> createState() => _JobNotesScreenState();
}

class _JobNotesScreenState extends State<JobNotesScreen> {
  int _selectedTab = 0;
  JobNoteVisibility _visibility = JobNoteVisibility.privateNote;
  bool _showBanner = true;

  List<JobNoteModel> get _filteredNotes {
    final source = widget.notes ?? DemoJobNotes.forJob(widget.job.id);
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
      builder: (dialogContext) => AlertDialog(
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
              if (note.type != JobNoteType.text && note.audioPath == null) ...[
                const SizedBox(height: 12),
                const Text('No playable audio is attached to this demo note.'),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _addNotes() {
    final callback = widget.onAddNotes;
    if (callback != null) {
      callback(
        widget.job.id,
        _visibility,
        _selectedTab == 0 ? JobNoteType.text : JobNoteType.voice,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add Notes editor is not connected yet.')),
      );
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
