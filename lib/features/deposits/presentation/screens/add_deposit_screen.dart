import '../../../../core/widgets/sign2digital_selection_sheet.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sign2digital_ai_voice_button.dart';
import '../../../../core/widgets/sign2digital_bottom_navigation_bar.dart';
import '../../../../core/widgets/sign2digital_header.dart';
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
import '../../domain/deposit_record.dart';
import '../../services/deposit_voice_extraction_service.dart';

/// Create a deposit using the same inputs, photos and AI dialogs as Labour.
/// Returns a typed pending deposit for the listing repository to save.
class AddDepositScreen extends StatefulWidget {
  const AddDepositScreen({
    super.key,
    required this.jobs,
    this.initialJob,
    this.initialDeposit,
    this.selectedNavigationIndex = 4,
    this.onNavigationSelected,
    this.photoSource,
    this.voiceRecorderFactory,
    this.voiceExtractionService,
    this.requestTemporaryApiKey,
    this.datePicker,
  });

  final List<JobModel> jobs;
  final JobModel? initialJob;
  final DepositRecord? initialDeposit;
  final int selectedNavigationIndex;
  final ValueChanged<int>? onNavigationSelected;
  final JobPhotoSource? photoSource;
  final VoiceRecorderService Function()? voiceRecorderFactory;
  final DepositVoiceExtractionService? voiceExtractionService;
  final Future<String?> Function(BuildContext)? requestTemporaryApiKey;
  final Future<DateTime?> Function(BuildContext, DateTime)? datePicker;

  @override
  State<AddDepositScreen> createState() => _AddDepositScreenState();
}

class _AddDepositScreenState extends State<AddDepositScreen> {
  final _client = TextEditingController();
  final _amount = TextEditingController();
  final _method = TextEditingController();
  final _reference = TextEditingController();
  final _notes = TextEditingController();
  final _photos = <LocalJobPhotoSelection>[];
  JobModel? _job;
  DateTime? _date;
  bool _saving = false;
  bool _photoBusy = false;
  bool _voiceOpen = false;
  String? _error;
  String? _voiceJobHint;

  @override
  void initState() {
    super.initState();
    final original = widget.initialDeposit;
    _job = widget.initialJob;
    if (original != null) {
      for (final job in widget.jobs) {
        if (job.id == original.jobId || job.title == original.title) {
          _job = job;
          break;
        }
      }
      _client.text = original.clientName;
      _amount.text = original.amount.toStringAsFixed(2);
      _date = original.date;
      _method.text = original.paymentMethod;
      _reference.text = original.referenceNumber;
      _notes.text = original.notes;
      _photos.addAll(original.photos);
      if (_job == null) { _voiceJobHint = original.title; }
    }
  }

  @override
  void dispose() {
    _client.dispose();
    _amount.dispose();
    _method.dispose();
    _reference.dispose();
    _notes.dispose();
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
        subtitle: 'Search jobs to link this deposit',
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
                    key: const Key('deposit-job-search'),
                    controller: search,
                    onChanged: (_) => update(() {}),
                    decoration: const InputDecoration(hintText: 'Search jobs'),
                  ),
                ),
                Expanded(child: ListView(children: [
                  for (final job in widget.jobs.where(
                    (item) => item.matches(search.text)))
                    ListTile(
                      key: Key('deposit-select-job-${job.id}'),
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
          _job = chosen;
          if (_client.text.trim().isEmpty) {
            _client.text = chosen.clientName;
          }
          _voiceJobHint = null;
          _error = null;
        });
      }
    } finally {
      search.dispose();
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

  Future<void> _addPhotos() async {
    if (_photoBusy || _saving) { return; }
    final camera = await showModalBottomSheet<bool>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            key: const Key('deposit-choose-gallery'),
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose from gallery'),
            onTap: () => Navigator.of(sheet).pop(false),
          ),
          ListTile(
            key: const Key('deposit-choose-camera'),
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
      key: const Key('deposit-photo-grid'),
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
            key: const Key('deposit-add-photo'),
            enabled: !_photoBusy && !_saving,
            onTap: _addPhotos,
          );
        }
        return Sign2DigitalPhotoPreview(
          key: Key('deposit-photo-$index'),
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
        title: const Text('Connect Deposit AI'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'For personal testing, enter a temporary OpenAI API key. '
              'The key is not saved. A production app needs a secure backend.',
            ),
            TextField(
              key: const Key('deposit-ai-key'),
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
            key: const Key('deposit-ai-extract'),
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

  void _applyVoice(DepositVoiceSuggestion suggestion) {
    if (!mounted) { return; }
    JobModel? matched;
    final reference = suggestion.jobReference?.trim().toLowerCase();
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
      if (suggestion.clientName != null) {
        _client.text = suggestion.clientName!;
      } else if (matched != null && _client.text.trim().isEmpty) {
        _client.text = matched.clientName;
      }
      if (suggestion.amount != null) {
        _amount.text = suggestion.amount!.toStringAsFixed(2);
      }
      if (suggestion.depositDate != null) {
        _date = suggestion.depositDate;
      }
      if (suggestion.paymentMethod != null) {
        _method.text = suggestion.paymentMethod!;
      }
      if (suggestion.referenceNumber != null) {
        _reference.text = suggestion.referenceNumber!;
      }
      if (suggestion.notes != null) {
        _notes.text = suggestion.notes!;
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
          recordingTitle: 'Record Deposit Details',
          onAudioProcessed: (path) async {
            final key = await (widget.requestTemporaryApiKey?.call(context) ??
                _askApiKey(context));
            if (key == null) {
              throw StateError('AI processing was cancelled.');
            }
            final result = await (widget.voiceExtractionService ??
                const OpenAiDepositVoiceExtractionService()).extract(path, key);
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
    final entered = _amount.text.trim();
    final validAmount = RegExp(
      r'^(?:CHF\s*)?\d+(?:[.,]\d{1,2})?$',
      caseSensitive: false,
    ).hasMatch(entered);
    final amount = validAmount
        ? double.tryParse(entered.replaceFirst(
            RegExp(r'^CHF\s*', caseSensitive: false), ''
          ).replaceAll(',', '.'))
        : null;
    if (_job == null || _client.text.trim().isEmpty ||
        _date == null || _method.text.trim().isEmpty ||
        amount == null || !amount.isFinite ||
        amount <= 0 || amount > 999999999) {
      setState(() => _error =
        'Select a job and deposit date, enter a client, '
        'payment method and a positive CHF amount (up to two decimals).');
      return;
    }
    setState(() { _saving = true; _error = null; });
    final original = widget.initialDeposit;
    Navigator.of(context).pop(DepositRecord(
      id: original?.id ??
          'local-deposit-${DateTime.now().microsecondsSinceEpoch}',
      title: _job!.title,
      clientName: _client.text.trim(),
      amount: amount,
      date: _date!,
      status: original?.status ?? DepositStatus.pending,
      jobId: _job!.id,
      jobReference: _job!.referenceNumber,
      paymentMethod: _method.text.trim(),
      referenceNumber: _reference.text.trim(),
      notes: _notes.text.trim(),
      photos: List.unmodifiable(_photos),
      history: original?.history ?? const [],
      receivedAt: original?.receivedAt,
      receivedBy: original?.receivedBy,
      refundedAt: original?.refundedAt,
    ));
  }

  void _navigate(int index) {
    if (index == widget.selectedNavigationIndex || _saving) { return; }
    Navigator.of(context).pop();
    widget.onNavigationSelected?.call(index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          Sign2DigitalHeader(
            title: 'Deposits',
            onBack: _cancel,
          ),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: ListView(
                  key: const Key('deposit-entry-form-scroll'),
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 25),
                  children: [
                    Sign2DigitalAiVoiceButton(onPressed: _voice),
                    const SizedBox(height: 20),
                    Sign2DigitalSelectionField(
                      key: const Key('deposit-form-job'),
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
                      key: const Key('deposit-form-client'),
                      label: 'Client',
                      hintText: 'e.g, Marc dupont',
                      iconAsset: 'assets/icons/user.svg',
                      controller: _client,
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 20),
                    Sign2DigitalInputField(
                      key: const Key('deposit-form-amount'),
                      label: 'Amount',
                      hintText: 'CHF 98.00',
                      iconAsset: 'assets/icons/description.svg',
                      leadingIcon: Icons.monetization_on_outlined,
                      controller: _amount,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    ),
                    const SizedBox(height: 20),
                    Sign2DigitalSelectionField(
                      key: const Key('deposit-form-date'),
                      label: 'Deposit Date',
                      iconAsset: 'assets/icons/calendar-outlined.svg',
                      hintText: 'August 25, 2026',
                      value: _date == null ? null : _dateLabel(_date!),
                      onTap: _pickDate,
                    ),
                    const SizedBox(height: 20),
                    Sign2DigitalInputField(
                      key: const Key('deposit-form-method'),
                      label: 'Payment Method',
                      hintText: 'e.g, Bank transfer',
                      iconAsset: 'assets/icons/description.svg',
                      leadingIcon: Icons.account_balance_outlined,
                      controller: _method,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    const SizedBox(height: 20),
                    Sign2DigitalInputField(
                      key: const Key('deposit-form-reference'),
                      label: 'Reference Number',
                      hintText: 'e.g, A-0005',
                      iconAsset: 'assets/icons/description.svg',
                      leadingIcon: Icons.tag,
                      controller: _reference,
                    ),
                    const SizedBox(height: 20),
                    Sign2DigitalInputField(
                      key: const Key('deposit-form-notes'),
                      label: 'Notes',
                      hintText: 'Complete renovation of the terrace, including '
                          'new tiles, waterproofing and railings',
                      iconAsset: 'assets/icons/description.svg',
                      controller: _notes,
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
                        key: const Key('deposit-form-error'),
                        style: const TextStyle(color: Color(0xFFB42318)),
                      ),
                    ],
                    const SizedBox(height: 25),
                    Row(children: [
                      Expanded(
                        child: Sign2DigitalOutlinedButton(
                          key: const Key('deposit-form-cancel'),
                          label: 'Cancel',
                          primaryOutline: true,
                          enabled: !_saving,
                          onPressed: _cancel,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Sign2DigitalPrimaryButton(
                          key: const Key('deposit-form-save'),
                          label: widget.initialDeposit == null ? 'Save Deposit' : 'Save Changes',
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
