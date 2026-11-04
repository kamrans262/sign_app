import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sign2digital_bottom_navigation_bar.dart';
import '../../../../core/widgets/sign2digital_header.dart';
import '../../../../core/widgets/sign2digital_input_field.dart';
import '../../../../core/widgets/sign2digital_primary_button.dart';
import '../../../../core/widgets/sign2digital_selection_sheet.dart';
import '../../../jobs/data/mock_jobs.dart';
import '../../../jobs/data/remote_job_repository.dart';
import '../../../jobs/domain/job_model.dart';
import '../../domain/document_record.dart';
import '../../data/remote_site_report_repository.dart';

/// Dedicated M12 meeting-minute editor, reusing existing Sign2Digital fields.
class MeetingMinutesEditorScreen extends StatefulWidget {
  const MeetingMinutesEditorScreen({
    super.key, this.initial, this.initialJobId, this.reportGenerator, this.jobs,
    this.onNavigationSelected,
  });

  final DocumentRecord? initial;
  final String? initialJobId;
  final Future<DocumentRecord> Function(DocumentRecord draft)? reportGenerator;
  final List<JobModel>? jobs;
  final ValueChanged<int>? onNavigationSelected;

  @override
  State<MeetingMinutesEditorScreen> createState() => _MeetingMinutesEditorScreenState();
}

class _MeetingMinutesEditorScreenState extends State<MeetingMinutesEditorScreen> {
  final _title = TextEditingController();
  final _location = TextEditingController();
  final _preparer = TextEditingController();
  final _summary = TextEditingController();
  final _attendees = TextEditingController();
  final _absentees = TextEditingController();
  final _decisions = TextEditingController();
  final _nextSteps = TextEditingController();
  final _outstanding = TextEditingController();
  final _actions = TextEditingController();
  JobModel? _job;
  DateTime _date = DateTime.now();
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _title.text = initial?.title ?? 'Meeting Minutes';
    _date = initial?.timestamp ?? DateTime.now();
    final details = initial?.meetingMinutesDetails;
    if (details != null) {
      _location.text = details.location;
      _preparer.text = details.preparedBy;
      _summary.text = details.summary;
      _attendees.text = details.attendees.join('\n');
      _absentees.text = details.absentees.join('\n');
      _decisions.text = details.decisions.join('\n');
      _nextSteps.text = details.nextSteps.join('\n');
      _outstanding.text = details.outstandingPoints.join('\n');
      _actions.text = details.actionDetails.isNotEmpty
          ? details.actionDetails.map((item) => [
              item.description, item.assignee,
              item.dueDate == null ? '' :
                  RemoteSiteReportRepository.dateValue(item.dueDate!),
            ].join(' | ')).join('\n')
          : details.actionItems.join('\n');
    }
    final known = widget.jobs ?? MockJobsData.jobs;
    for (final job in known) {
      if (job.id == initial?.jobId ||
          (job.title == initial?.project && job.clientName == initial?.customer)) {
        _job = job;
        break;
      }
    }
    final linkedId = initial?.jobId ?? widget.initialJobId;
    if (linkedId != null && int.tryParse(linkedId) != null &&
        widget.jobs == null && widget.reportGenerator != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _resolveLinkedJob(linkedId);
      });
    }
  }

  Future<void> _resolveLinkedJob(String jobId) async {
    try {
      final jobs = await RemoteJobRepository.shared.listJobs();
      if (!mounted || (_job != null && _job!.id != jobId)) return;
      for (final job in jobs) {
        if (job.id == jobId) {
          setState(() { _job = job; _error = null; });
          return;
        }
      }
      setState(() => _error = 'Linked company job is not available.');
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Unable to verify linked job: $error');
      }
    }
  }

  @override
  void dispose() {
    for (final c in [_title,_location,_preparer,_summary,_attendees,
      _absentees,_decisions,_nextSteps,_outstanding,_actions]) {
      c.dispose();
    }
    super.dispose();
  }

  List<String> _lines(String input) => input.split('\n')
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty).toList();

  Future<void> _chooseJob() async {
    try {
      final jobs = widget.jobs ?? (widget.reportGenerator == null
          ? MockJobsData.jobs : await RemoteJobRepository.shared.listJobs());
      if (!mounted) {
        return;
      }
      final selected = await Sign2DigitalSelectionSheet.showCustom<JobModel>(
        context: context, title: 'Select Job / Project',
        subtitle: 'Select a saved job and its linked client',
        icon: Icons.work_outline_rounded,
        isScrollControlled: true,
        builder: (sheet) => SafeArea(child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheet).height * .7),
          child: ListView(shrinkWrap: true, children: [
            for (final job in jobs)
              ListTile(
                key: Key('meeting-job-${job.id}'),
                title: Text(job.title),
                subtitle: Text('${job.referenceNumber} • ${job.clientName}'),
                trailing: _job?.id == job.id
                    ? const Icon(Icons.check_circle, color: AppColors.primary)
                    : null,
                onTap: () => Navigator.of(sheet).pop(job),
              ),
          ]),
        )),
      );
      if (selected != null && mounted) {
        setState(() { _job = selected; _error = null; });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Unable to load real jobs: $error');
      }
    }
  }

  Future<void> _pickDate() async {
    final value = await showDatePicker(
      context: context, initialDate: _date,
      firstDate: DateTime(2000), lastDate: DateTime(2100));
    if (value != null && mounted) setState(() => _date = value);
  }

  List<MeetingActionItem> _readActions() {
    final items = <MeetingActionItem>[];
    for (final line in _lines(_actions.text)) {
      final fields = line.split('|').map((item) => item.trim()).toList();
      if (fields.length > 3 || fields.first.isEmpty) {
        throw const FormatException('Use task | owner | YYYY-MM-DD for action items.');
      }
      final dueText = fields.length == 3 ? fields[2] : '';
      final due = dueText.isEmpty ? null : DateTime.tryParse(dueText);
      if (dueText.isNotEmpty &&
          (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(dueText) ||
           due == null)) {
        throw const FormatException('Use YYYY-MM-DD for action due dates.');
      }
      items.add(MeetingActionItem(
        description: fields.first,
        assignee: fields.length >= 2 ? fields[1] : '',
        dueDate: due,
      ));
    }
    return items;
  }

  DocumentRecord _draft() {
    final job = _job!;
    final actionDetails = _readActions();
    final details = MeetingMinutesDetails(
      location: _location.text.trim(),
      preparedBy: _preparer.text.trim(),
      summary: _summary.text.trim(),
      attendees: _lines(_attendees.text),
      absentees: _lines(_absentees.text),
      decisions: _lines(_decisions.text),
      nextSteps: _lines(_nextSteps.text),
      outstandingPoints: _lines(_outstanding.text),
      actionItems: actionDetails.map((item) => item.description).toList(),
      actionDetails: actionDetails,
    );
    return DocumentRecord(
      id: widget.initial?.id ??
          'local-meeting-${DateTime.now().microsecondsSinceEpoch}',
      category: DocumentCategory.reports,
      number: widget.initial?.number ?? 'Meeting Minutes',
      title: _title.text.trim(),
      project: job.title, customer: job.clientName,
      jobId: job.id, timestamp: _date, status: 'Draft',
      reportKind: ReportKind.meetingMinutes,
      createdBy: details.preparedBy,
      meetingMinutesDetails: details,
      demoOnly: widget.reportGenerator == null,
    );
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_job == null || _title.text.trim().isEmpty ||
        _location.text.trim().isEmpty || _preparer.text.trim().isEmpty ||
        (_summary.text.trim().isEmpty && _attendees.text.trim().isEmpty &&
        _decisions.text.trim().isEmpty && _actions.text.trim().isEmpty)) {
      setState(() => _error =
          'Select a job and enter title, location, preparer, and meeting content.');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      final draft = _draft();
      final saved = widget.reportGenerator == null
          ? draft : await widget.reportGenerator!(draft);
      if (!mounted) {
        return;
      }
      if (widget.reportGenerator != null &&
          (saved.demoOnly || !saved.id.startsWith('report-'))) {
        throw const FormatException('The server did not save meeting minutes.');
      }
      Navigator.of(context).pop(saved);
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Unable to save meeting minutes: $error');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field(String label, TextEditingController controller,
      {bool multiline = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 15),
    child: Sign2DigitalInputField(
      label: label,
      hintText: 'Enter ${label.toLowerCase()}',
      iconAsset: '', leadingIcon: Icons.edit_note_outlined,
      controller: controller,
      minLines: multiline ? 3 : 1,
      maxLines: multiline ? 6 : 1,
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.white,
    body: SafeArea(bottom: false, child: Column(children: [
      const Sign2DigitalHeader(title: 'Meeting Minutes'),
      Expanded(child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            ListTile(
              key: const Key('meeting-select-job'),
              title: Text(_job?.title ?? 'Select Job / Project'),
              subtitle: Text(_job?.clientName ?? 'Choose a real job and client'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _chooseJob,
            ),
            _field('Title', _title),
            ListTile(
              key: const Key('meeting-date'),
              title: const Text('Meeting Date'),
              subtitle: Text('${_date.year}-${_date.month.toString().padLeft(2,'0')}-${_date.day.toString().padLeft(2,'0')}'),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: _pickDate,
            ),
            _field('Prepared By', _preparer),
            _field('Location', _location),
            _field('Summary', _summary, multiline: true),
            _field('Attendees (one per line)', _attendees, multiline: true),
            _field('Absentees (one per line)', _absentees, multiline: true),
            _field('Decisions (one per line)', _decisions, multiline: true),
            _field('Next Steps (one per line)', _nextSteps, multiline: true),
            _field('Outstanding Points (one per line)', _outstanding, multiline: true),
            _field('Action Items (task | owner | YYYY-MM-DD)', _actions, multiline: true),
            if (_error != null)
              Padding(padding: const EdgeInsets.only(bottom: 12),
                child: Text(_error!, style: const TextStyle(
                  fontFamily: 'Inter', color: Color(0xFFB42318)))),
            Sign2DigitalPrimaryButton(
              key: const Key('meeting-save-draft'),
              label: 'Save Meeting Minutes',
              loading: _saving, onPressed: _save,
            ),
          ],
        ),
      ))),
    ])),
    bottomNavigationBar: Sign2DigitalBottomNavigationBar(
      selectedIndex: 2,
      onSelected: widget.onNavigationSelected ??
          (_) => Navigator.of(context).maybePop(),
    ),
  );
}
