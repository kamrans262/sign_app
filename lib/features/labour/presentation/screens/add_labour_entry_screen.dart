import '../../../../core/widgets/sign2digital_selection_sheet.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sign2digital_ai_voice_button.dart';
import '../../../../core/widgets/sign2digital_bottom_navigation_bar.dart';
import '../../../../core/widgets/sign2digital_header.dart';
import '../../../../core/widgets/sign2digital_info_banner.dart';
import '../../../../core/widgets/sign2digital_input_field.dart';
import '../../../../core/widgets/sign2digital_outlined_button.dart';
import '../../../../core/widgets/sign2digital_primary_button.dart';
import '../../../../core/widgets/sign2digital_selection_field.dart';
import '../../../expenses/presentation/widgets/sign2digital_expense_upload_tile.dart';
import '../../../jobs/data/local_job_photo_source.dart';
import '../../../jobs/domain/job_model.dart';
import '../../../jobs/presentation/widgets/ai_voice_flow_dialog.dart';
import '../../../jobs/presentation/widgets/sign2digital_photo_preview.dart';
import '../../../jobs/services/voice_job_extraction_service.dart';
import '../../../jobs/services/voice_recorder_service.dart';
import '../../domain/labour_entry.dart';
import '../../data/remote_labour_repository.dart';
import '../../services/remote_labour_voice_extraction_service.dart';
import '../../../auth/data/mobile_auth_repository.dart';
import '../../../../core/services/active_company_session.dart';
import '../../services/labour_voice_extraction_service.dart';

/// Create a labour entry and return it to TimeLabourScreen for saving.
/// The reusable recorder, upload widgets, header, fields and navigation are
/// deliberately shared with Expenses and Create Job.
class AddLabourEntryScreen extends StatefulWidget {
  const AddLabourEntryScreen({
    super.key,
    required this.kind,
    required this.jobs,
    this.initialJob,
    this.initialEntry,
    this.selectedNavigationIndex = 4,
    this.onNavigationSelected,
    this.photoSource,
    this.voiceRecorderFactory,
    this.voiceExtractionService,
    this.requestTemporaryApiKey,
    this.timePicker,
    this.datePicker,
  });

  final LabourEntryKind kind;
  final List<JobModel> jobs;
  final JobModel? initialJob;
  final LabourEntry? initialEntry;
  final int selectedNavigationIndex;
  final ValueChanged<int>? onNavigationSelected;
  final JobPhotoSource? photoSource;
  final VoiceRecorderService Function()? voiceRecorderFactory;
  final LabourVoiceExtractionService? voiceExtractionService;
  final Future<String?> Function(BuildContext)? requestTemporaryApiKey;
  final Future<TimeOfDay?> Function(BuildContext, TimeOfDay)? timePicker;
  final Future<DateTime?> Function(BuildContext, DateTime)? datePicker;

  @override
  State<AddLabourEntryScreen> createState() => _AddLabourEntryScreenState();
}

class _AddLabourEntryScreenState extends State<AddLabourEntryScreen> {
  final _worker = TextEditingController();
  final _role = TextEditingController();
  final _rate = TextEditingController();
  final _description = TextEditingController();
  final _photos = <LocalJobPhotoSelection>[];
  JobModel? _job;
  int? _workerId;

  bool get _remote => MobileAuthRepository.shared.isSignedIn ||
      ActiveCompanySession.companyId != null;
  DateTime? _date;
  TimeOfDay? _start;
  TimeOfDay? _end;
  bool _saving = false;
  bool _photoBusy = false;
  bool _voiceOpen = false;
  String? _error;
  String? _voiceJobHint;

  static int _minutes(TimeOfDay time) => time.hour * 60 + time.minute;

  int? get _duration {
    if (_start == null || _end == null) { return null; }
    return LabourTimeRange.durationMinutes(
      _minutes(_start!), _minutes(_end!));
  }

  @override
  void initState() {
    super.initState();
    final previous = widget.initialEntry;
    _job = widget.initialJob;
    if (previous != null) {
      for (final job in widget.jobs) {
        if (job.id == previous.jobId) {
          _job = job;
          break;
        }
      }
      _worker.text = previous.workerName;
      _workerId = previous.workerId;
      _role.text = previous.role;
      _description.text = previous.task;
      _rate.text = previous.hourlyRate?.toStringAsFixed(2) ?? '';
      _date = previous.date;
      if (previous.startMinutes != null) {
        _start = TimeOfDay(
          hour: previous.startMinutes! ~/ 60,
          minute: previous.startMinutes! % 60,
        );
      }
      if (previous.endMinutes != null) {
        _end = TimeOfDay(
          hour: previous.endMinutes! ~/ 60,
          minute: previous.endMinutes! % 60,
        );
      }
      _photos.addAll(previous.photos);
    }
  }

  @override
  void dispose() {
    _worker.dispose();
    _role.dispose();
    _rate.dispose();
    _description.dispose();
    super.dispose();
  }

  static String _dateLabel(DateTime date) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  void _notice(String message) {
    if (!mounted) { return; }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _selectJob() async {
    final search = TextEditingController();
    try {
      final chosen = await Sign2DigitalSelectionSheet.showCustom<JobModel>(
        title: 'Select Job / Project',
        icon: Icons.work_outline_rounded,
        subtitle: 'Search jobs for this labour entry',
        context: context,
        isScrollControlled: true,
        builder: (sheet) => StatefulBuilder(
          builder: (sheet, update) => SafeArea(
            child: SizedBox(
              height: MediaQuery.sizeOf(sheet).height * 0.65,
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: TextField(
                    key: const Key('labour-job-search'),
                    controller: search,
                    onChanged: (_) => update(() {}),
                    decoration: const InputDecoration(hintText: 'Search jobs'),
                  ),
                ),
                Expanded(child: ListView(children: [
                  for (final job in widget.jobs.where(
                    (item) => item.matches(search.text)))
                    ListTile(
                      key: Key('labour-select-job-${job.id}'),
                      selected: _job?.id == job.id,
                      trailing: _job?.id == job.id
                          ? const Icon(Icons.check_circle_rounded,
                              color: AppColors.primary) : null,
                      title: Text(job.title),
                      subtitle: Text(job.referenceNumber),
                      onTap: () => Navigator.of(sheet).pop(job),
                    ),
                ])),
              ]),
            ),
          ),
        ),
      );
      if (chosen != null && mounted) {
        setState(() {
          if (_job?.id != chosen.id && _remote) {
            _workerId = null;
            _worker.clear();
          }
          _job = chosen;
          _voiceJobHint = null;
          _error = null;
        });
      }
    } finally {
      search.dispose();
    }
  }

  Future<void> _selectWorker() async {
    if (_job == null) {
      _notice('Select a saved job before choosing an assigned worker.');
      return;
    }
    try {
      final workers=await RemoteLabourRepository.shared.workers(_job!.id);
      if(!mounted)return;
      final chosen=await Sign2DigitalSelectionSheet.showCustom<LabourWorker>(
        title:'Assigned Team Member',
        icon:Icons.group_outlined,
        subtitle:'Only active workers assigned to this job can log time',
        context:context,isScrollControlled:true,
        builder:(sheet)=>SafeArea(child:ListView(
          shrinkWrap:true,
          children:[
            for(final worker in workers)
              ListTile(
                key:Key('labour-worker-${worker.id}'),
                title:Text(worker.name),
                selected:worker.id==_workerId,
                trailing:worker.id==_workerId?
                    const Icon(Icons.check_circle_rounded,
                      color:AppColors.primary):null,
                onTap:()=>Navigator.of(sheet).pop(worker),
              ),
            if(workers.isEmpty)const ListTile(
              title:Text('No assigned team members found')),
          ],
        )),
      );
      if(chosen!=null&&mounted) {
        setState((){
          _workerId=chosen.id;
          _worker.text=chosen.name;
          _error=null;
        });
      }
    } catch (_) {
      _notice('Unable to load assigned team members.');
    }
  }

  Future<void> _pickDate() async {
    final initial = _date ?? DateTime.now();
    final date = await (widget.datePicker?.call(context, initial) ??
        showDatePicker(
          context: context,
          initialDate: initial,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        ));
    if (date != null && mounted) {
      setState(() { _date = date; _error = null; });
    }
  }

  Future<void> _pickTime({required bool start}) async {
    final initial = (start ? _start : _end) ?? _start ?? TimeOfDay.now();
    final time = await (widget.timePicker?.call(context, initial) ??
        showTimePicker(context: context, initialTime: initial));
    if (time != null && mounted) {
      setState(() {
        if (start) {
          _start = time;
        } else {
          _end = time;
        }
        _error = null;
      });
    }
  }

  Future<void> _addPhotos() async {
    if (_photoBusy || _saving) { return; }
    final camera = await showModalBottomSheet<bool>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            key: const Key('labour-choose-gallery'),
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose from gallery'),
            onTap: () => Navigator.of(sheet).pop(false),
          ),
          ListTile(
            key: const Key('labour-choose-camera'),
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Take a photo'),
            onTap: () => Navigator.of(sheet).pop(true),
          ),
        ]),
      ),
    );
    if (camera == null || !mounted) { return; }
    setState(() => _photoBusy = true);
    try {
      final source = widget.photoSource ?? DeviceJobPhotoSource();
      final chosen = camera
          ? <LocalJobPhotoSelection>[
              ?await source.camera(),
            ]
          : await source.upload();
      for (final photo in chosen) {
        DeviceJobPhotoSource.validate(photo.name, photo.bytes);
      }
      if (!mounted) { return; }
      setState(() {
        final sources = _photos.map((p) => p.sourceKey).toSet();
        for (final photo in chosen) {
          if (sources.add(photo.sourceKey)) { _photos.add(photo); }
        }
      });
    } on FormatException catch (error) {
      _notice(error.message);
    } catch (_) {
      _notice('Unable to access photos. Please try again.');
    } finally {
      if (mounted) { setState(() => _photoBusy = false); }
    }
  }

  Widget _photoGrid() => LayoutBuilder(
    builder: (context, bounds) => GridView.builder(
      key: const Key('labour-photo-grid'),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _photos.isEmpty || bounds.maxWidth < 320 ? 1 : 2,
        mainAxisSpacing: 15,
        crossAxisSpacing: 15,
        mainAxisExtent: 120,
      ),
      itemCount: _photos.length + 1,
      itemBuilder: (context, index) {
        if (index == _photos.length) {
          return Sign2DigitalExpenseUploadTile(
            key: const Key('labour-add-photo'),
            enabled: !_photoBusy && !_saving,
            onTap: _addPhotos,
          );
        }
        return Sign2DigitalPhotoPreview(
          key: Key('labour-photo-$index'),
          bytes: _photos[index].bytes,
          showDemo: false,
          compactTile: true,
          onRemove: () => setState(() => _photos.removeAt(index)),
        );
      },
    ),
  );

  void _applyVoice(LabourVoiceSuggestion suggestion) {
    if (!mounted) { return; }
    JobModel? matched;
    final reference = suggestion.jobReference?.toLowerCase();
    if (reference != null) {
      for (final job in widget.jobs) {
        if (job.id.toLowerCase() == reference ||
            job.title.toLowerCase() == reference ||
            job.referenceNumber.toLowerCase() == reference) {
          matched = job;
          break;
        }
      }
    }
    setState(() {
      if (matched != null) { _job = matched; }
      if (suggestion.worker != null) { _worker.text = suggestion.worker!; }
      if (suggestion.date != null) { _date = suggestion.date; }
      if (suggestion.startMinutes case final minutes?) {
        _start = TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
      }
      if (suggestion.endMinutes case final minutes?) {
        _end = TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
      }
      if (suggestion.labourType != null) {
        _role.text = suggestion.labourType!;
      }
      if (suggestion.hourlyRate != null) {
        _rate.text = suggestion.hourlyRate!.toStringAsFixed(2);
      }
      if (suggestion.description != null) {
        _description.text = suggestion.description!;
      }
      _voiceJobHint = matched == null ? suggestion.jobReference : null;
      _error = null;
    });
    if (reference != null && matched == null) {
      _notice('AI mentioned ${suggestion.jobReference}. '
          'Select the matching job to confirm.');
    }
  }

  Future<void> _voice() async {
    if (_voiceOpen || _saving) { return; }
    _voiceOpen = true;
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        barrierColor: const Color(0x80000000),
        builder: (_) => AiVoiceFlowDialog(
          recorder: widget.voiceRecorderFactory?.call() ??
              LocalVoiceRecorderService(),
          extraction: OpenAiVoiceJobExtractionService(),
          recordingTitle: 'Record labour Details',
          onAudioProcessed: (path) async {
            final key = await widget.requestTemporaryApiKey?.call(context) ?? '';
            final result = await (widget.voiceExtractionService ??
                RemoteLabourVoiceExtractionService()).extract(path, key);
            _applyVoice(result);
          },
        ),
      );
    } finally {
      _voiceOpen = false;
    }
  }

  void _cancel() {
    if (_saving) { return; }
    Navigator.of(context).pop();
  }

  void _save() {
    if (_saving) { return; }
    FocusManager.instance.primaryFocus?.unfocus();
    final minutes = _duration;
    final rate = double.tryParse(
      _rate.text.trim().replaceAll(',', '.'),
    );
    if (_job == null || _worker.text.trim().isEmpty ||
        (_remote && _workerId == null) ||
        _date == null || _start == null || _end == null ||
        minutes == null || minutes <= 0 ||
        _role.text.trim().isEmpty ||
        (!_remote && rate == null) ||
        (rate != null && (!rate.isFinite || rate < 0))) {
      setState(() => _error =
        'Select a job, worker, date, start and end time, '
        'labour type and valid hourly rate.');
      return;
    }
    setState(() { _saving = true; _error = null; });
    final now = DateTime.now();
    final previous = widget.initialEntry;
    if (previous != null && previous.status != LabourEntryStatus.pending) {
      setState(() {
        _saving = false;
        _error = 'Approved entries cannot be edited.';
      });
      return;
    }
    Navigator.of(context).pop(LabourEntry(
      id: previous?.id ?? 'local-time-${now.microsecondsSinceEpoch}',
      kind: widget.kind,
      workerName: _worker.text.trim(),
      role: _role.text.trim(),
      jobId: _job!.id,
      jobName: _job!.title,
      date: _date!,
      hours: minutes / 60,
      startMinutes: _minutes(_start!),
      endMinutes: _minutes(_end!),
      hourlyRate: rate,
      workerId: _workerId ?? previous?.workerId,
      lockVersion: previous?.lockVersion ?? 1,
      source: previous?.source ?? 'manual',
      task: _description.text.trim(),
      photos: List.unmodifiable(_photos),
      status: previous?.status ?? LabourEntryStatus.pending,
      history: previous?.history ?? const [],
      approvedBy: previous?.approvedBy,
      approvedAt: previous?.approvedAt,
      isDemo: previous?.isDemo ?? false,
    ));
  }

  void _navigate(int index) {
    if (index == widget.selectedNavigationIndex || _saving) { return; }
    Navigator.of(context).pop();
    widget.onNavigationSelected?.call(index);
  }

  @override
  Widget build(BuildContext context) {
    final duration = _duration;
    return Scaffold(
      backgroundColor: AppColors.white,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          Sign2DigitalHeader(
            logoAsset: 'assets/header_logo.png',
            onBack: _cancel,
          ),
          Expanded(
            child: ListView(
                  key: const Key('labour-entry-form-scroll'),
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 25),
                  children: [
                    Sign2DigitalAiVoiceButton(onPressed: _voice),
                    const SizedBox(height: 20),
                    Sign2DigitalSelectionField(
                      key: const Key('labour-form-job'),
                      label: 'Job / Project',
                      iconAsset: 'assets/icons/description.svg',
                      hintText: _voiceJobHint ?? 'e.g, Site renovation',
                      value: _job?.title,
                      onTap: _selectJob,
                      trailing: const Icon(Icons.keyboard_arrow_down_rounded,
                          color: AppColors.secondaryText),
                    ),
                    const SizedBox(height: 20),
                    if (_remote)
                      Sign2DigitalSelectionField(
                        key: const Key('labour-form-worker'),
                        label: 'Worker',
                        hintText: 'Select assigned team member',
                        iconAsset: 'assets/icons/user.svg',
                        value: _worker.text.isEmpty ? null : _worker.text,
                        onTap: widget.initialEntry == null
                            ? _selectWorker : () {},
                        trailing: const Icon(Icons.keyboard_arrow_down_rounded,
                          color: AppColors.secondaryText),
                      )
                    else
                      Sign2DigitalInputField(
                        key: const Key('labour-form-worker'),
                        label: 'Worker',
                        hintText: 'e.g, Marc dupont',
                        iconAsset: 'assets/icons/user.svg',
                        controller: _worker,
                        textCapitalization: TextCapitalization.words,
                      ),
                    const SizedBox(height: 20),
                    Sign2DigitalSelectionField(
                      key: const Key('labour-form-date'),
                      label: 'Date',
                      iconAsset: 'assets/icons/calendar-outlined.svg',
                      hintText: 'August 25, 2026',
                      value: _date == null ? null : _dateLabel(_date!),
                      onTap: _pickDate,
                    ),
                    const SizedBox(height: 20),
                    Sign2DigitalSelectionField(
                      key: const Key('labour-form-start'),
                      label: 'Start Time',
                      iconAsset: 'assets/icons/calendar-outlined.svg',
                      leadingIcon: Icons.access_time_rounded,
                      hintText: '10:00 PM',
                      value: _start?.format(context),
                      onTap: () => _pickTime(start: true),
                    ),
                    const SizedBox(height: 20),
                    Sign2DigitalSelectionField(
                      key: const Key('labour-form-end'),
                      label: 'End Time',
                      iconAsset: 'assets/icons/calendar-outlined.svg',
                      leadingIcon: Icons.access_time_rounded,
                      hintText: '10:00 PM',
                      value: _end?.format(context),
                      onTap: () => _pickTime(start: false),
                    ),
                    const SizedBox(height: 20),
                    Sign2DigitalInfoBanner(
                      key: const Key('labour-total-hours'),
                      title: 'Total Hours',
                      message: duration == null
                          ? 'Select start and end time'
                          : LabourTimeRange.display(duration),
                      leadingIcon: Icons.access_time_rounded,
                      titleColor: AppColors.primary,
                      verticalPadding: 14,
                      iconSize: 24,
                      fontSize: 14,
                      textColor: AppColors.placeholder,
                    ),
                    const SizedBox(height: 20),
                    Sign2DigitalInputField(
                      key: const Key('labour-form-role'),
                      label: 'Labour Type',
                      hintText: 'Electrician',
                      iconAsset: 'assets/icons/team_members.svg',
                      controller: _role,
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 20),
                    Sign2DigitalInputField(
                      key: const Key('labour-form-rate'),
                      label: 'Hourly Rate',
                      hintText: '85.00',
                      iconAsset: 'assets/icons/calendar-outlined.svg',
                      leadingIcon: Icons.access_time_rounded,
                      controller: _rate,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    ),
                    const SizedBox(height: 20),
                    Sign2DigitalInputField(
                      key: const Key('labour-form-task'),
                      label: 'Description',
                      hintText: 'Complete renovation of the terrace, including '
                          'new tiles, waterproofing and railings',
                      iconAsset: 'assets/icons/description.svg',
                      controller: _description,
                      textCapitalization: TextCapitalization.sentences,
                      minLines: 2,
                      maxLines: null,
                    ),
                    const SizedBox(height: 20),
                    _photoGrid(),
                    if (_error != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        _error!,
                        key: const Key('labour-form-error'),
                        style: const TextStyle(color: Color(0xFFB42318)),
                      ),
                    ],
                    const SizedBox(height: 25),
                    Row(children: [
                      Expanded(
                        child: Sign2DigitalOutlinedButton(
                          key: const Key('labour-form-cancel'),
                          label: 'Cancel',
                          primaryOutline: true,
                          enabled: !_saving,
                          onPressed: _cancel,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Sign2DigitalPrimaryButton(
                          key: const Key('labour-form-save'),
                          label: widget.initialEntry == null
                              ? 'Save Labour Entry' : 'Save Changes',
                          loading: _saving,
                          onPressed: _save,
                        ),
                      ),
                    ]),
                  ],
                ),
          ),
        ]),
      ),
      bottomNavigationBar: Sign2DigitalBottomNavigationBar(
        selectedIndex: widget.selectedNavigationIndex,
        onSelected: _navigate,
      ),
    );
  }
}
