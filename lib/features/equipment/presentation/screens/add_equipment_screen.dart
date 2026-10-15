import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sign2digital_ai_voice_button.dart';
import '../../../../core/widgets/sign2digital_header.dart';
import '../../../../core/widgets/sign2digital_input_field.dart';
import '../../../../core/widgets/sign2digital_outlined_button.dart';
import '../../../../core/widgets/sign2digital_primary_button.dart';
import '../../../../core/widgets/sign2digital_selection_field.dart';
import '../../../expenses/presentation/widgets/sign2digital_expense_upload_tile.dart';
import '../../../jobs/data/local_job_photo_source.dart';
import '../../../jobs/presentation/widgets/ai_voice_flow_dialog.dart';
import '../../../jobs/presentation/widgets/sign2digital_photo_preview.dart';
import '../../../jobs/services/voice_recorder_service.dart';
import '../../../jobs/services/voice_job_extraction_service.dart';
import '../../domain/equipment_record.dart';
import '../../services/equipment_voice_extraction_service.dart';

/// Uses the existing Deposit/Labour form controls, image picker and voice popup.
/// Returns a complete record; the caller commits through EquipmentRepository.
class AddEquipmentScreen extends StatefulWidget {
  const AddEquipmentScreen({
    super.key, this.initialEquipment, this.photoSource,
    this.voiceRecorderFactory, this.voiceExtractionService,
    this.requestTemporaryApiKey, this.datePicker, this.availableNames,
  });
  final EquipmentRecord? initialEquipment;
  final JobPhotoSource? photoSource;
  final VoiceRecorderService Function()? voiceRecorderFactory;
  final EquipmentVoiceExtractionService? voiceExtractionService;
  final Future<String?> Function(BuildContext)? requestTemporaryApiKey;
  final Future<DateTime?> Function(BuildContext, DateTime)? datePicker;
  final List<String>? availableNames;

  @override
  State<AddEquipmentScreen> createState() => _AddEquipmentScreenState();
}

class _AddEquipmentScreenState extends State<AddEquipmentScreen> {
  final _id = TextEditingController();
  final _brand = TextEditingController();
  final _model = TextEditingController();
  final _location = TextEditingController();
  final _notes = TextEditingController();
  final _photos = <LocalJobPhotoSelection>[];
  String? _name, _category;
  DateTime? _purchaseDate;
  EquipmentStatus _status = EquipmentStatus.available;
  bool _saving = false, _photoBusy = false, _voiceOpen = false;
  String? _error;

  static const _categories = [
    'Excavation', 'Earthmoving', 'Transportation',
    'Lifting', 'Construction', 'Other',
  ];

  @override
  void initState() {
    super.initState();
    final original = widget.initialEquipment;
    if (original != null) {
      _name = original.name;
      _category = original.category;
      _id.text = original.id;
      _brand.text = original.brand;
      _model.text = original.model;
      _location.text = original.location;
      _notes.text = original.notes;
      _purchaseDate = original.purchaseDate;
      _status = original.status;
      _photos.addAll(original.photos);
    }
  }

  @override
  void dispose() {
    for (final controller in [_id, _brand, _model, _location, _notes]) {
      controller.dispose();
    }
    super.dispose();
  }

  static String _date(DateTime value) {
    const months = ['January','February','March','April','May','June',
      'July','August','September','October','November','December'];
    return '${months[value.month - 1]} ${value.day}, ${value.year}';
  }

  void _notice(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<String?> _customValue(String title) async {
    final input = TextEditingController();
    try {
      final value = await showDialog<String>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: Text('Enter $title'),
          content: TextField(
            key: const Key('equipment-custom-value'),
            controller: input, maxLength: 100,
            decoration: InputDecoration(hintText: title),
            autofocus: true),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialog),
              child: const Text('Cancel')),
            TextButton(onPressed: () =>
              Navigator.pop(dialog, input.text.trim()),
              child: const Text('Use')),
          ]),
      );
      return value == null || value.isEmpty ? null : value;
    } finally {
      input.dispose();
    }
  }

  Future<void> _chooseName() async {
    if (_saving) return;
    final options = {...?widget.availableNames, if (_name != null) _name!};
    final chosen = await showModalBottomSheet<String>(
      context: context,
      builder: (sheet) => SafeArea(child: Column(
        mainAxisSize: MainAxisSize.min, children: [
          const ListTile(title: Text('Choose equipment name')),
          for (final name in options)
            ListTile(title: Text(name), onTap: () => Navigator.pop(sheet, name)),
          ListTile(
            key: const Key('equipment-custom-name'),
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Enter equipment name'),
            onTap: () => Navigator.pop(sheet, '__custom__')),
        ])),
    );
    if (!mounted || chosen == null) return;
    final resolved = chosen == '__custom__'
        ? await _customValue('equipment name') : chosen;
    if (resolved != null && mounted) setState(() { _name = resolved; _error = null; });
  }

  Future<void> _chooseCategory() async {
    if (_saving) return;
    final choices = {..._categories, if (_category != null) _category!};
    final chosen = await showModalBottomSheet<String>(
      context: context,
      builder: (sheet) => SafeArea(child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ListTile(title: Text('Select Category')),
          for (final category in choices)
            ListTile(
              key: Key('equipment-category-${category.toLowerCase()}'),
              title: Text(category),
              onTap: () => Navigator.pop(sheet, category)),
        ])),
    );
    if (chosen == null || !mounted) return;
    final result = chosen == 'Other'
        ? await _customValue('category') : chosen;
    if (result != null && mounted) setState(() { _category = result; _error = null; });
  }

  Future<void> _pickDate() async {
    final initial = _purchaseDate ?? DateTime.now();
    final date = widget.datePicker != null
        ? await widget.datePicker!(context, initial)
        : await showDatePicker(context: context, initialDate: initial,
            firstDate: DateTime(2000), lastDate: DateTime(2100));
    if (mounted && date != null) setState(() {
      _purchaseDate = DateTime(date.year, date.month, date.day);
      _error = null;
    });
  }

  Future<void> _pickStatus() async {
    final choice = await showModalBottomSheet<EquipmentStatus>(
      context: context,
      builder: (sheet) => SafeArea(child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ListTile(title: Text('Equipment Status')),
          for (final status in EquipmentStatus.values)
            ListTile(
              key: Key('equipment-status-${status.name}'),
              title: Text(status.label),
              onTap: () => Navigator.pop(sheet, status)),
        ])),
    );
    if (mounted && choice != null) setState(() => _status = choice);
  }

  Future<void> _pickPhoto() async {
    if (_saving || _photoBusy) return;
    final camera = await showModalBottomSheet<bool>(
      context: context,
      builder: (sheet) => SafeArea(child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            key: const Key('equipment-photo-gallery'),
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose from gallery'),
            onTap: () => Navigator.pop(sheet, false)),
          ListTile(
            key: const Key('equipment-photo-camera'),
            leading: const Icon(Icons.camera_alt_outlined),
            title: const Text('Take a photo'),
            onTap: () => Navigator.pop(sheet, true)),
        ])),
    );
    if (camera == null || !mounted) return;
    setState(() => _photoBusy = true);
    try {
      final source = widget.photoSource ?? DeviceJobPhotoSource();
      final items = camera
          ? <LocalJobPhotoSelection>[?await source.camera()]
          : await source.upload();
      for (final photo in items) {
        DeviceJobPhotoSource.validate(photo.name, photo.bytes);
      }
      if (!mounted) return;
      setState(() {
        final existing = _photos.map((e) => e.sourceKey).toSet();
        for (final photo in items) {
          if (existing.add(photo.sourceKey)) _photos.add(photo);
        }
      });
    } catch (_) {
      _notice('Unable to add equipment photos. Check permissions or file type.');
    } finally {
      if (mounted) setState(() => _photoBusy = false);
    }
  }

  Widget _photoGrid() => LayoutBuilder(
    builder: (context, bounds) => GridView.builder(
      key: const Key('equipment-photo-grid'),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: bounds.maxWidth < 320 ? 1 : 2,
        crossAxisSpacing: 15, mainAxisSpacing: 15, mainAxisExtent: 120),
      itemCount: _photos.length + 1,
      itemBuilder: (context, index) =>
        index == _photos.length
            ? Sign2DigitalExpenseUploadTile(
                key: const Key('equipment-add-photo'),
                enabled: !_photoBusy && !_saving,
                onTap: _pickPhoto)
            : Sign2DigitalPhotoPreview(
                key: Key('equipment-photo-$index'),
                bytes: _photos[index].bytes, showDemo: false,
                compactTile: true,
                onRemove: () => setState(() => _photos.removeAt(index))),
    ),
  );

  Future<String?> _askApiKey(BuildContext parent) async {
    final controller = TextEditingController();
    try {
      return await showDialog<String>(
        context: parent,
        builder: (dialog) => AlertDialog(
          title: const Text('Connect Equipment AI'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Enter a temporary OpenAI API key to process your '
              'recording. Audio is transmitted to OpenAI; API charges may apply.'),
            TextField(
              key: const Key('equipment-ai-key'),
              controller: controller, obscureText: true,
              decoration: const InputDecoration(labelText: 'OpenAI API key')),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialog),
              child: const Text('Cancel')),
            TextButton(
              key: const Key('equipment-ai-extract'),
              onPressed: () => Navigator.pop(dialog, controller.text.trim()),
              child: const Text('Process recording')),
          ]),
      );
    } finally {
      controller.dispose();
    }
  }

  Future<void> _applyVoice(EquipmentVoiceSuggestion suggestion) async {
    if (!mounted) return;
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Use extracted equipment details?'),
        content: const Text('Only empty text fields and missing selections '
          'will be filled. Review and correct every field before saving.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Keep my entries')),
          TextButton(
            key: const Key('equipment-voice-apply'),
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Apply suggestions')),
        ]),
    );
    if (approved != true || !mounted) return;
    setState(() {
      _name ??= suggestion.name;
      _category ??= suggestion.category;
      if (_id.text.trim().isEmpty) _id.text = suggestion.equipmentId ?? '';
      if (_brand.text.trim().isEmpty) _brand.text = suggestion.brand ?? '';
      if (_model.text.trim().isEmpty) _model.text = suggestion.model ?? '';
      if (_location.text.trim().isEmpty) _location.text = suggestion.location ?? '';
      if (_notes.text.trim().isEmpty) _notes.text = suggestion.notes ?? '';
      _purchaseDate ??= suggestion.purchaseDate;
      // Status is a deliberate user choice; never override it from audio.
      _error = null;
    });
  }

  Future<void> _voice() async {
    if (_saving || _voiceOpen) return;
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
          recordingTitle: 'Record Equipment Details',
          onAudioProcessed: (path) async {
            final key = await (widget.requestTemporaryApiKey?.call(context) ??
                _askApiKey(context));
            if (key == null || key.trim().isEmpty) {
              throw StateError('Equipment AI extraction was cancelled.');
            }
            final result = await (widget.voiceExtractionService ??
                const OpenAiEquipmentVoiceExtractionService()).extract(path, key);
            await _applyVoice(result);
          },
        ),
      );
    } finally {
      _voiceOpen = false;
    }
  }

  void _save() {
    if (_saving) return;
    FocusManager.instance.primaryFocus?.unfocus();
    if ((_name ?? '').trim().isEmpty ||
        (_category ?? '').trim().isEmpty ||
        _id.text.trim().isEmpty || _brand.text.trim().isEmpty ||
        _model.text.trim().isEmpty || _purchaseDate == null) {
      setState(() => _error =
        'Select a name, category and date; enter equipment ID, brand and model.');
      return;
    }
    setState(() { _saving = true; _error = null; });
    final old = widget.initialEquipment;
    Navigator.of(context).pop(EquipmentRecord(
      id: old?.id ?? _id.text.trim(),
      name: _name!.trim(), category: _category!.trim(),
      brand: _brand.text.trim(), model: _model.text.trim(),
      purchaseDate: _purchaseDate!, status: _status,
      location: _location.text.trim(), notes: _notes.text.trim(),
      photos: List<LocalJobPhotoSelection>.unmodifiable(_photos),
      initialHours: old?.initialHours ?? 0,
      usage: old?.usage ?? const [],
      maintenance: old?.maintenance ?? const [],
      history: old?.history ?? const [],
      createdAt: old?.createdAt ?? DateTime.now(),
    ));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.white,
    resizeToAvoidBottomInset: true,
    body: SafeArea(child: Column(children: [
      Sign2DigitalHeader(title: 'Equipment',
        onBack: () => Navigator.of(context).maybePop()),
      Expanded(child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          key: const Key('equipment-form-scroll'),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          children: [
            Sign2DigitalAiVoiceButton(
              key: const Key('equipment-ai-voice'), onPressed: _voice),
            const SizedBox(height: 20),
            Sign2DigitalSelectionField(
              key: const Key('equipment-form-name'), label: 'Name (ID)',
              iconAsset: 'assets/icons/description.svg',
              hintText: 'e.g, Tractor', value: _name, onTap: _chooseName,
              trailing: const Icon(Icons.keyboard_arrow_down_rounded,
                color: AppColors.secondaryText)),
            const SizedBox(height: 20),
            Sign2DigitalSelectionField(
              key: const Key('equipment-form-category'),
              label: 'Category', leadingIcon: Icons.category_outlined,
              iconAsset: 'assets/icons/description.svg',
              hintText: 'e.g, Mini tractor', value: _category,
              onTap: _chooseCategory,
              trailing: const Icon(Icons.keyboard_arrow_down_rounded,
                color: AppColors.secondaryText)),
            const SizedBox(height: 20),
            Sign2DigitalInputField(
              key: const Key('equipment-form-id'),
              label: 'Equipment ID', hintText: 'e.g, A-0005',
              iconAsset: 'assets/icons/description.svg',
              leadingIcon: Icons.tag, controller: _id),
            const SizedBox(height: 20),
            Sign2DigitalInputField(
              key: const Key('equipment-form-brand'),
              label: 'Brand', hintText: 'e.g, Kubota',
              iconAsset: 'assets/icons/description.svg',
              leadingIcon: Icons.verified_outlined,
              controller: _brand),
            const SizedBox(height: 20),
            Sign2DigitalInputField(
              key: const Key('equipment-form-model'),
              label: 'Model', hintText: 'e.g, U-27-4',
              iconAsset: 'assets/icons/description.svg',
              leadingIcon: Icons.account_tree_outlined,
              controller: _model),
            const SizedBox(height: 20),
            Sign2DigitalSelectionField(
              key: const Key('equipment-form-date'),
              label: 'Purchase Date',
              iconAsset: 'assets/icons/calendar-outlined.svg',
              hintText: 'August 25, 2026',
              value: _purchaseDate == null ? null : _date(_purchaseDate!),
              onTap: _pickDate),
            const SizedBox(height: 20),
            Sign2DigitalSelectionField(
              key: const Key('equipment-form-status'),
              label: 'Status', leadingIcon: Icons.adjust_outlined,
              iconAsset: 'assets/icons/description.svg',
              hintText: 'Available', value: _status.label,
              onTap: _pickStatus),
            const SizedBox(height: 20),
            Sign2DigitalInputField(
              key: const Key('equipment-form-location'),
              label: 'Location (optional)',
              hintText: 'e.g, Swiss Gate, London',
              iconAsset: 'assets/icons/description.svg',
              leadingIcon: Icons.location_on_outlined,
              controller: _location),
            const SizedBox(height: 20),
            Sign2DigitalInputField(
              key: const Key('equipment-form-notes'),
              label: 'Notes',
              hintText: 'Complete renovation of the terrace, including '
                'new tiles, waterproofing and railings',
              iconAsset: 'assets/icons/description.svg',
              leadingIcon: Icons.subject,
              controller: _notes, minLines: 2, maxLines: null),
            const SizedBox(height: 20),
            _photoGrid(),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, key: const Key('equipment-form-error'),
                style: const TextStyle(color: Color(0xFFB42318))),
            ],
            const SizedBox(height: 25),
            Row(children: [
              Expanded(child: Sign2DigitalOutlinedButton(
                key: const Key('equipment-form-cancel'),
                label: 'Cancel', primaryOutline: true,
                enabled: !_saving,
                onPressed: () => Navigator.of(context).maybePop())),
              const SizedBox(width: 10),
              Expanded(child: Sign2DigitalPrimaryButton(
                key: const Key('equipment-form-save'),
                label: oldLabel, loading: _saving, onPressed: _save)),
            ]),
          ],
        ),
      ))),
    ])),
  );

  String get oldLabel => widget.initialEquipment == null
      ? 'Save Equipment' : 'Save Changes';
}
