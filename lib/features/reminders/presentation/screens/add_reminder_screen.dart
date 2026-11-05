import '../../../../core/widgets/sign2digital_selection_sheet.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sign2digital_ai_voice_button.dart';
import '../../../../core/widgets/sign2digital_header.dart';
import '../../../../core/widgets/sign2digital_input_field.dart';
import '../../../../core/widgets/sign2digital_outlined_button.dart';
import '../../../../core/widgets/sign2digital_primary_button.dart';
import '../../../../core/widgets/sign2digital_selection_field.dart';
import '../../../jobs/presentation/widgets/ai_voice_flow_dialog.dart';
import '../../../jobs/services/voice_job_extraction_service.dart';
import '../../../jobs/services/voice_recorder_service.dart';
import '../../data/existing_reminder_reference_source.dart';
import '../../data/remote_reminder_reference_source.dart';
import '../../../auth/data/mobile_auth_repository.dart';
import '../../domain/reminder_record.dart';
import '../../services/reminder_voice_extraction_service.dart';

class AddReminderScreen extends StatefulWidget {
  const AddReminderScreen({
    super.key, this.initialReminder, this.referenceSource,
    this.voiceRecorderFactory, this.voiceExtractionService,
    this.requestTemporaryApiKey, this.datePicker, this.timePicker,
  });

  final ReminderRecord? initialReminder;
  final ReminderReferenceSource? referenceSource;
  final VoiceRecorderService Function()? voiceRecorderFactory;
  final ReminderVoiceExtractionService? voiceExtractionService;
  final Future<String?> Function(BuildContext)? requestTemporaryApiKey;
  final Future<DateTime?> Function(BuildContext, DateTime)? datePicker;
  final Future<TimeOfDay?> Function(BuildContext, TimeOfDay)? timePicker;

  @override
  State<AddReminderScreen> createState() => _AddReminderScreenState();
}

class _AddReminderScreenState extends State<AddReminderScreen> {
  final _title = TextEditingController();
  final _notes = TextEditingController();
  late final ReminderReferenceSource _references;
  ReminderType? _type;
  ReminderRelatedItem? _related;
  DateTime? _date;
  TimeOfDay? _time;
  bool _notify = true, _completed = false, _busy = false, _voiceOpen = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _references = widget.referenceSource ??
        (MobileAuthRepository.shared.isSignedIn
          ? RemoteReminderReferenceSource()
          : ExistingReminderReferenceSource());
    final original = widget.initialReminder;
    if (original != null) {
      _title.text = original.title;
      _notes.text = original.notes;
      _type = original.type;
      _related = original.relatedItem;
      _date = DateTime(original.remindAt.year,
          original.remindAt.month, original.remindAt.day);
      _time = TimeOfDay.fromDateTime(original.remindAt);
      _notify = original.sendNotification;
      _completed = original.completed;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  static String _dateText(DateTime value) {
    const m = ['January','February','March','April','May','June','July',
      'August','September','October','November','December'];
    return '${m[value.month - 1]} ${value.day}, ${value.year}';
  }

  static String _timeText(TimeOfDay value) {
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    return '$hour:${value.minute.toString().padLeft(2, '0')} '
        '${value.hour < 12 ? 'AM' : 'PM'}';
  }

  Future<void> _selectTitle() async {
    if (_busy) return;
    final suggestion = await Sign2DigitalSelectionSheet.showCustom<String>(
      title: 'Reminder Title',
      icon: Icons.notifications_active_outlined,
      subtitle: 'Choose a suggested reminder title',
      context: context,
      builder: (sheet) => SafeArea(child: Column(
        mainAxisSize: MainAxisSize.min, children: [
          for (final value in [
            'Client Meeting', 'Send Invoice', 'Follow Up',
            'Site Inspection', 'Review Document',
          ])
            ListTile(
              key: Key('reminder-title-template-${value.replaceAll(' ', '-')}'),
              selected: _title.text == value,
              trailing: _title.text == value
                  ? const Icon(Icons.check_circle_rounded,
                      color: AppColors.primary) : null,
              title: Text(value),
              onTap: () => Navigator.pop(sheet, value)),
        ],
      )),
    );
    if (mounted && suggestion != null) {
      setState(() { _title.text = suggestion; _error = null; });
    }
  }

  Future<void> _selectType() async {
    if (_busy) return;
    final choice = await Sign2DigitalSelectionSheet.showCustom<ReminderType>(
      title: 'Select Reminder Type',
      icon: Icons.category_outlined,
      subtitle: 'Choose the kind of reminder',
      context: context,
      builder: (sheet) => SafeArea(child: Column(
        mainAxisSize: MainAxisSize.min, children: [
          for (final option in ReminderType.values)
            ListTile(
              key: Key('reminder-type-${option.name}'),
              selected: _type == option,
              trailing: _type == option
                  ? const Icon(Icons.check_circle_rounded,
                      color: AppColors.primary) : null,
              title: Text(option.label),
              onTap: () => Navigator.pop(sheet, option)),
        ])),
    );
    if (choice != null && mounted) {
      setState(() {
        if (_type != choice) _related = null;
        _type = choice;
        _error = null;
      });
    }
  }

  Future<void> _selectRelated() async {
    if (_busy) return;
    if (_type == null || _type == ReminderType.other) {
      _notice('Select an Invoice, Job, Client or Document type first.');
      return;
    }
    List<ReminderRelatedItem> options;
    try {
      options = await _references.listForType(_type!);
    } catch (_) {
      _notice('Unable to load related items. Try again.');
      return;
    }
    if (!mounted) return;
    if (options.isEmpty) {
      _notice('No related ${_type!.label.toLowerCase()} records are available.');
      return;
    }
    final result = await Sign2DigitalSelectionSheet.showCustom<ReminderRelatedItem>(
      title: 'Select Related Item',
      icon: Icons.account_tree_outlined,
      subtitle: 'Link this reminder to an existing item',
      context: context, isScrollControlled: true,
      builder: (sheet) => SafeArea(child: SizedBox(
        height: MediaQuery.sizeOf(sheet).height * .55,
        child: Column(children: [
          Expanded(child: ListView.builder(
            itemCount: options.length,
            itemBuilder: (context, i) => ListTile(
              key: Key('reminder-related-${options[i].id}'),
              selected: _related?.id == options[i].id,
              trailing: _related?.id == options[i].id
                  ? const Icon(Icons.check_circle_rounded,
                      color: AppColors.primary) : null,
              title: Text(options[i].title, maxLines: 2),
              subtitle: options[i].project.isNotEmpty
                  ? Text(options[i].project) : null,
              onTap: () => Navigator.pop(sheet, options[i])),
          )),
        ]),
      )),
    );
    if (mounted && result != null) {
      setState(() { _related = result; _error = null; });
    }
  }

  Future<void> _selectDate() async {
    if (_busy) return;
    final initial = _date ?? DateTime.now();
    final date = widget.datePicker != null
        ? await widget.datePicker!(context, initial)
        : await showDatePicker(context: context, initialDate: initial,
          firstDate: DateTime(2000), lastDate: DateTime(2100));
    if (mounted && date != null) {
      setState(() {
        _date = DateTime(date.year, date.month, date.day);
        _error = null;
      });
    }
  }

  Future<void> _selectTime() async {
    if (_busy) return;
    final initial = _time ?? const TimeOfDay(hour: 22, minute: 0);
    final time = widget.timePicker != null
        ? await widget.timePicker!(context, initial)
        : await showTimePicker(context: context, initialTime: initial);
    if (mounted && time != null) {
      setState(() { _time = time; _error = null; });
    }
  }

  void _notice(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<String?> _askApiKey(BuildContext context) async {
    final input = TextEditingController();
    try {
      return await showDialog<String>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: const Text('Connect Reminder AI'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Enter a temporary OpenAI API key to process your '
                'voice recording. Audio is sent to OpenAI; charges may apply.'),
            TextField(
              key: const Key('reminder-voice-api-key'),
              controller: input, obscureText: true,
              decoration: const InputDecoration(labelText: 'OpenAI API key')),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialog),
              child: const Text('Cancel')),
            TextButton(
              key: const Key('reminder-voice-process'),
              onPressed: () => Navigator.pop(dialog, input.text.trim()),
              child: const Text('Process recording')),
          ],
        ),
      );
    } finally {
      input.dispose();
    }
  }

  Future<void> _applyVoice(ReminderVoiceSuggestion result) async {
    if (!mounted) return;
    // Link only a real existing record that matches the speech; don't create
    // invented invoices, clients, jobs or documents.
    ReminderRelatedItem? matched;
    final targetType = _type ?? result.type;
    if (_related == null && targetType != null &&
        targetType != ReminderType.other &&
        result.relatedItem != null) {
      try {
        final options = await _references.listForType(targetType);
        final term = result.relatedItem!.trim().toLowerCase();
        for (final item in options) {
          if (item.id.toLowerCase() == term ||
              item.title.toLowerCase() == term ||
              item.title.toLowerCase().contains(term)) {
            matched = item;
            break;
          }
        }
      } catch (_) {
        // Other suggestions remain usable if linked records are unavailable.
      }
    }
    if (!mounted) return;
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Use extracted reminder details?'),
        content: const Text('Fill only empty fields or missing selections. '
          'Existing entries stay unchanged. Please review before saving.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Keep my entries')),
          TextButton(
            key: const Key('reminder-voice-apply'),
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Apply suggestions')),
        ],
      ),
    );
    if (approved != true || !mounted) return;
    setState(() {
      if (_title.text.trim().isEmpty) _title.text = result.title ?? '';
      if (_notes.text.trim().isEmpty) _notes.text = result.notes ?? '';
      _type ??= result.type;
      _date ??= result.date;
      _time ??= result.time;
      _related ??= matched;
      _error = null;
    });
  }

  Future<void> _voice() async {
    if (_busy || _voiceOpen) return;
    _voiceOpen = true;
    try {
      await showDialog<void>(
        context: context, barrierDismissible: false,
        barrierColor: const Color(0x80000000),
        builder: (_) => AiVoiceFlowDialog(
          recorder: widget.voiceRecorderFactory?.call() ??
              LocalVoiceRecorderService(),
          extraction: OpenAiVoiceJobExtractionService(),
          recordingTitle: 'Record Reminder Details',
          onAudioProcessed: (path) async {
            final key = await (widget.requestTemporaryApiKey?.call(context) ??
                _askApiKey(context));
            if (key == null || key.trim().isEmpty) {
              throw StateError('Reminder AI extraction was cancelled.');
            }
            final suggestion = await (widget.voiceExtractionService ??
                const OpenAiReminderVoiceExtractionService()).extract(path, key);
            await _applyVoice(suggestion);
          },
        ),
      );
    } catch (_) {
      _notice('Voice processing failed. Your entries were preserved.');
    } finally {
      _voiceOpen = false;
    }
  }

  void _save() {
    if (_busy) return;
    FocusManager.instance.primaryFocus?.unfocus();
    if (_title.text.trim().isEmpty || _type == null ||
        _date == null || _time == null ||
        _title.text.trim().length > 160) {
      setState(() => _error =
          'Enter a title (up to 160 characters), type, date and time.');
      return;
    }
    if (_related != null && _related!.type != _type) {
      setState(() => _error = 'Select a related item matching the reminder type.');
      return;
    }
    final remindAt = DateTime(
      _date!.year, _date!.month, _date!.day, _time!.hour, _time!.minute);
    if (remindAt.year != _date!.year || remindAt.month != _date!.month ||
        remindAt.day != _date!.day) {
      setState(() => _error = 'Choose a valid reminder date and time.');
      return;
    }
    final original = widget.initialReminder;
    setState(() { _busy = true; _error = null; });
    Navigator.of(context).pop(ReminderRecord(
      id: original?.id ??
        'reminder-local-${DateTime.now().microsecondsSinceEpoch}',
      title: _title.text.trim(), type: _type!, remindAt: remindAt,
      relatedItem: _related, notes: _notes.text.trim(),
      sendNotification: _notify,
      completedAt: _completed
        ? original?.completedAt ?? DateTime.now() : null,
      createdAt: original?.createdAt ?? DateTime.now(),
      demoOnly: original?.demoOnly ?? false,
    ));
  }

  Widget _notification() => Row(
    key: const Key('reminder-notification-setting'),
    children: [
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text('Send Notification', style: TextStyle(
            fontFamily: 'Inter', fontSize: 16,
            fontWeight: FontWeight.w600, color: AppColors.dark)),
          SizedBox(height: 5),
          Text('Receive a push notification at the reminder time',
            style: TextStyle(fontFamily: 'Inter',
              fontSize: 12, color: AppColors.placeholder)),
        ],
      )),
      const SizedBox(width: 10),
      Switch.adaptive(
        key: const Key('reminder-notification-toggle'),
        value: _notify,
        activeTrackColor: AppColors.primary,
        activeThumbColor: AppColors.white,
        onChanged: (value) => setState(() => _notify = value)),
    ],
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.white,
    resizeToAvoidBottomInset: true,
    body: SafeArea(child: Column(children: [
      Sign2DigitalHeader(
        title: 'Reminders', onBack: () => Navigator.of(context).maybePop()),
      Expanded(child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          key: const Key('reminder-form-scroll'),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          children: [
            Sign2DigitalAiVoiceButton(
              key: const Key('reminder-ai-voice'), onPressed: _voice),
            const SizedBox(height: 20),
            Sign2DigitalInputField(
              key: const Key('reminder-title'),
              label: 'Title', hintText: 'e.g. Send invoice INV-2026-88',
              iconAsset: 'assets/icons/description.svg',
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              maxLength: 160,
              trailing: IconButton(
                key: const Key('reminder-title-suggestions'),
                icon: const Icon(Icons.keyboard_arrow_down_rounded,
                  color: AppColors.secondaryText),
                onPressed: _selectTitle)),
            const SizedBox(height: 20),
            Sign2DigitalSelectionField(
              key: const Key('reminder-type'), label: 'Type',
              iconAsset: 'assets/icons/description.svg',
              leadingIcon: Icons.category_outlined,
              hintText: 'e.g. Invoice', value: _type?.label,
              onTap: _selectType,
              trailing: const Icon(Icons.keyboard_arrow_down_rounded,
                color: AppColors.secondaryText)),
            const SizedBox(height: 20),
            Sign2DigitalSelectionField(
              key: const Key('reminder-related'),
              label: 'Related Items',
              iconAsset: 'assets/icons/description.svg',
              leadingIcon: Icons.account_tree_outlined,
              hintText: 'e.g. Select invoice, job, client or document',
              value: _related?.title,
              onTap: _selectRelated),
            const SizedBox(height: 20),
            Sign2DigitalSelectionField(
              key: const Key('reminder-date'),
              label: 'Reminder Date',
              iconAsset: 'assets/icons/calendar-outlined.svg',
              hintText: 'August 25, 2026',
              value: _date == null ? null : _dateText(_date!),
              onTap: _selectDate),
            const SizedBox(height: 20),
            Sign2DigitalSelectionField(
              key: const Key('reminder-time'), label: 'Reminder Time',
              iconAsset: 'assets/icons/description.svg',
              leadingIcon: Icons.access_time_outlined,
              hintText: '10:00 PM',
              value: _time == null ? null : _timeText(_time!),
              onTap: _selectTime),
            const SizedBox(height: 20),
            Sign2DigitalInputField(
              key: const Key('reminder-notes'),
              label: 'Notes', iconAsset: 'assets/icons/description.svg',
              leadingIcon: Icons.subject,
              hintText: 'Complete renovation of the terrace, including '
                'new tiles, waterproofing and railings',
              controller: _notes, minLines: 2, maxLines: null),
            const SizedBox(height: 20),
            _notification(),
            if (widget.initialReminder != null) ...[
              const SizedBox(height: 15),
              CheckboxListTile(
                key: const Key('reminder-completed'),
                title: const Text('Completed'),
                subtitle: const Text('Move this reminder into Completed'),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                activeColor: AppColors.primary,
                value: _completed,
                onChanged: (value) =>
                  setState(() => _completed = value ?? false)),
            ],
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, key: const Key('reminder-form-error'),
                style: const TextStyle(color: Color(0xFFB42318))),
            ],
            const SizedBox(height: 25),
            Row(children: [
              Expanded(child: Sign2DigitalOutlinedButton(
                key: const Key('reminder-cancel'),
                label: 'Cancel', primaryOutline: true,
                enabled: !_busy,
                onPressed: () => Navigator.of(context).maybePop())),
              const SizedBox(width: 10),
              Expanded(child: Sign2DigitalPrimaryButton(
                key: const Key('reminder-save'),
                label: 'Save Reminder',
                loading: _busy, onPressed: _save)),
            ]),
          ],
        ),
      ))),
    ])),
  );
}
