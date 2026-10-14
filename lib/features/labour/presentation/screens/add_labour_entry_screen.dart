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
    this.selectedNavigationIndex = 4,
    this.onNavigationSelected,
    this.photoSource,
    this.voiceRecorderFactory,
    this.voiceExtractionService,
    this.requestTemporaryApiKey,
  });

  final LabourEntryKind kind;
  final List<JobModel> jobs;
  final JobModel? initialJob;
  final int selectedNavigationIndex;
  final ValueChanged<int>? onNavigationSelected;
  final JobPhotoSource? photoSource;
  final VoiceRecorderService Function()? voiceRecorderFactory;
  final LabourVoiceExtractionService? voiceExtractionService;
  final Future<String?> Function(BuildContext)? requestTemporaryApiKey;

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
    if (_start == null || _end == null) return null;
    return LabourTimeRange.durationMinutes(
      _minutes(_start!), _minutes(_end!));
  }

  @override
  void initState() {
    super.initState();
    _job = widget.initialJob;
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
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _selectJob() async {
    final search = TextEditingController();
    try {
      final chosen = await showModalBottomSheet<JobModel>(
        context: context,
        isScrollControlled: true,
        builder: (sheet) => StatefulBuilder(
          builder: (sheet, update) => SafeArea(
            child: SizedBox(
              height: MediaQuery.sizeOf(sheet).height * 0.65,
              child: Column(children: [
                const ListTile(title: Text('Select Job / Project')),
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
          _job = chosen;
          _voiceJobHint = null;
          _error = null;
        });
      }
    } finally {
      search.dispose();
    }
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _date ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date != null && mounted) {
      setState(() { _date = date; _error = null; });
    }
  }

  Future<void> _pickTime({required bool start}) async {
    final time = await showTimePicker(
      context: context,
      initialTime: (start ? _start : _end) ?? _start ?? TimeOfDay.now(),
    );
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
    if (_photoBusy || _saving) return;
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
    if (camera == null || !mounted) return;
    setState(() => _photoBusy = true);
    try {
      final source = widget.photoSource ?? DeviceJobPhotoSource();
      final chosen = camera
          ? <LocalJobPhotoSelection>[
              if (await source.camera() case final photo?) photo,
            ]
          : await source.upload();
      for (final photo in chosen) {
        DeviceJobPhotoSource.validate(photo.name, photo.bytes);
      }
      if (!mounted) return;
      setState(() {
        final sources = _photos.map((p) => p.sourceKey).toSet();
        for (final photo in chosen) {
          if (sources.add(photo.sourceKey)) _photos.add(photo);
        }
      });
    } on FormatException catch (error) {
      _notice(error.message);
    } catch (_) {
      _notice('Unable to access photos. Please try again.');
    } finally {
      if (mounted) setState(() => _photoBusy = false);
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

  Future<String?> _askApiKey(BuildContext parent) {
    String value = '';
    return showDialog<String>(
      context: parent,
      builder: (dialog) => AlertDialog(
        title: const Text('Connect Labour AI'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'For personal testing, enter a temporary OpenAI API key. '
              'The key is not saved. A production app needs a secure backend.',
            ),
            TextField(
              key: const Key('labour-ai-key'),
              obscureText: true,
              onChanged: (text) => value = text,
              decoration: const InputDecoration(labelText: 'OpenAI API key'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            key: const Key('labour-ai-extract'),
            onPressed: () {
              if (value.trim().isNotEmpty) {
                Navigator.of(dialog).pop(value.trim());
              }
            },
            child: const Text('Process recording'),
          ),
        ],
      ),
    );
  }

  void _applyVoice(LabourVoiceSuggestion suggestion) {
    if (!mounted) return;
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
      if (matched != null) _job = matched;
      if (suggestion.worker != null) _worker.text = suggestion.worker!;
      if (suggestion.date != null) _date = suggestion.date;
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
    if (_voiceOpen || _saving) return;
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
            final key = await (widget.requestTemporaryApiKey?.call(context) ??
                _askApiKey(context));
            if (key == null) {
              throw StateError('AI processing was cancelled.');
            }
            final result = await (widget.voiceExtractionService ??
                const OpenAiLabourVoiceExtractionService()).extract(path, key);
            _applyVoice(result);
          },
        ),
      );
    } finally {
      _voiceOpen = false;
    }
  }

  void _cancel() {
    if (_saving) return;
    Navigator.of(context).pop();
  }

  void _save() {
    if (_saving) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final minutes = _duration;
    final rate = double.tryParse(
      _rate.text.trim().replaceAll(',', '.'),
    );
    if (_job == null || _worker.text.trim().isEmpty ||
        _date == null || _start == null || _end == null ||
        minutes == null || minutes <= 0 ||
        _role.text.trim().isEmpty || rate == null ||
        !rate.isFinite || rate < 0) {
      setState(() => _error =
        'Select a job, worker, date, start and end time, '
        'labour type and valid hourly rate.');
      return;
    }
    setState(() { _saving = true; _error = null; });
    final now = DateTime.now();
    Navigator.of(context).pop(LabourEntry(
      id: 'local-time-${now.microsecondsSinceEpoch}',
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
      task: _description.text.trim(),
      photos: List.unmodifiable(_photos),
      status: LabourEntryStatus.pending,
    ));
  }

  void _navigate(int index) {
    if (index == widget.selectedNavigationIndex || _saving) return;
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
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
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
                          label: 'Save Labour Entry',
                          loading: _saving,
                          onPressed: _save,
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
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
