import '../../../../core/widgets/sign2digital_selection_sheet.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/sign2digital_ai_voice_button.dart';
import '../../../../core/widgets/sign2digital_bottom_navigation_bar.dart';
import '../../../../core/widgets/sign2digital_header.dart';
import '../../../../core/widgets/sign2digital_input_field.dart';
import '../../../../core/widgets/sign2digital_outlined_button.dart';
import '../../../../core/widgets/sign2digital_outlined_container.dart';
import '../../../../core/widgets/sign2digital_primary_button.dart';
import '../../../../core/widgets/sign2digital_selection_field.dart';
import '../../../jobs/data/local_job_photo_source.dart';
import '../../../jobs/data/mock_jobs.dart';
import '../../../jobs/data/remote_job_repository.dart';
import '../../../../core/services/active_company_session.dart';
import '../../../jobs/domain/job_model.dart';
import '../../../jobs/presentation/widgets/ai_voice_flow_dialog.dart';
import '../../../jobs/presentation/widgets/sign2digital_photo_preview.dart';
import '../../../jobs/services/voice_job_extraction_service.dart';
import '../../../jobs/services/voice_recorder_service.dart';
import '../../domain/expense_record.dart';
import '../../services/expense_voice_extraction_service.dart';
import '../../services/remote_expense_voice_extraction_service.dart';
import '../widgets/sign2digital_expense_upload_tile.dart';

/// Full Create Expense page; returns a validated local record for the caller
/// to save via its injected ExpenseRepository.
class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key, this.initialJob, this.photoSource,
    this.voiceRecorderFactory, this.voiceExtractionService,
    this.requestTemporaryApiKey, this.selectedNavigationIndex = 4,
    this.onNavigationSelected, this.initialExpense});
  final JobModel? initialJob;
  final ExpenseRecord? initialExpense;
  final JobPhotoSource? photoSource;
  final VoiceRecorderService Function()? voiceRecorderFactory;
  final ExpenseVoiceExtractionService? voiceExtractionService;
  final Future<String?> Function(BuildContext)? requestTemporaryApiKey;
  final int selectedNavigationIndex;
  final ValueChanged<int>? onNavigationSelected;
  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _amount = TextEditingController();
  final _description = TextEditingController();
  final _supplier = TextEditingController();
  final _tagInput = TextEditingController();
  JobModel? _job;
  ExpenseCategory? _category;
  DateTime? _date;
  final _photos = <LocalJobPhotoSelection>[];
  final _tags = <String>[];
  bool _busy = false;
  bool _voiceOpen = false;
  bool _allowPop = false;
  String? _error;
  String? _voiceJobSuggestion;

  @override
  void initState() {
    super.initState();
    final existing = widget.initialExpense;
    _job = widget.initialJob;
    if (existing != null) {
      for (final job in MockJobsData.jobs) {
        if (job.id == existing.jobId) { _job = job; break; }
      }
      _category = existing.category;
      _date = existing.date;
      _amount.text = existing.amount.toStringAsFixed(2);
      _description.text = existing.description;
      _supplier.text = existing.supplier;
      _photos.addAll(existing.photos);
      _tags.addAll(existing.tags);
    }
    _amount.addListener(_refresh);
    _description.addListener(_refresh);
    _supplier.addListener(_refresh);
    _tagInput.addListener(_refresh);
  }
  void _refresh() { if (mounted) setState(() {}); }
  @override
  void dispose() {
    _amount.dispose(); _description.dispose(); _supplier.dispose(); _tagInput.dispose();
    super.dispose();
  }

  bool get _dirty {
    final original = widget.initialExpense;
    if (original != null) {
      return _job?.id != original.jobId ||
          _category != original.category ||
          _date != original.date ||
          _amount.text.trim() != original.amount.toStringAsFixed(2) ||
          _description.text != original.description ||
          _supplier.text != original.supplier ||
          _photos.length != original.photos.length ||
          _tags.join('|') != original.tags.join('|') ||
          _tagInput.text.trim().isNotEmpty;
    }
    return _job != widget.initialJob ||
        _category != null || _date != null || _amount.text.isNotEmpty ||
        _description.text.isNotEmpty || _supplier.text.isNotEmpty ||
        _photos.isNotEmpty || _tags.isNotEmpty ||
        _tagInput.text.isNotEmpty;
  }

  void _notice(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _confirmDiscard() async {
    if (!_dirty) return true;
    return await showDialog<bool>(context: context, builder: (dialog) => AlertDialog(
      title: const Text('Discard expense?'),
      content: const Text('Your unsaved expense information will be lost.'),
      actions: [
        TextButton(onPressed: () => Navigator.of(dialog).pop(false),
          child: const Text('Keep editing')),
        TextButton(key: const Key('expense-discard-confirm'),
          onPressed: () => Navigator.of(dialog).pop(true),
          child: const Text('Discard')),
      ],
    )) ?? false;
  }

  Future<void> _cancel() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (await _confirmDiscard() && mounted) {
      setState(() => _allowPop = true);
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _chooseJob() async {
    final search = TextEditingController();
    try {
      final jobs = ActiveCompanySession.companyId == null
          ? MockJobsData.jobs : await RemoteJobRepository.shared.listJobs();
      if (!mounted) return;
      final chosen = await Sign2DigitalSelectionSheet.showCustom<JobModel>(
        title: 'Select Job / Project',
        icon: Icons.work_outline_rounded,
        subtitle: 'Search jobs for this expense',
        context: context, isScrollControlled: true,
        builder: (sheet) => StatefulBuilder(
          builder: (sheet, update) => SafeArea(child: SizedBox(
            height: MediaQuery.sizeOf(sheet).height * 0.65,
            child: Column(children: [
              Padding(padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(key: const Key('expense-job-search'),
                  controller: search,
                  decoration: const InputDecoration(
                    hintText: 'Search jobs or reference number'),
                  onChanged: (_) => update(() {}),
                )),
              Expanded(child: ListView(children: [
                for (final job in jobs.where((item) =>
                    item.matches(search.text)))
                  ListTile(
                    key: Key('expense-job-${job.id}'),
                    selected: _job?.id == job.id,
                    trailing: _job?.id == job.id
                        ? const Icon(Icons.check_circle_rounded,
                            color: AppColors.primary) : null,
                    title: Text(job.title),
                    subtitle: Text('${job.referenceNumber} • ${job.clientName}'),
                    onTap: () => Navigator.of(sheet).pop(job),
                  ),
              ])),
            ]),
          )),
        ),
      );
      if (chosen != null && mounted) setState(() { _job = chosen; _error = null; });
    } finally { search.dispose(); }
  }

  Future<void> _chooseCategory() async {
    final chosen = await Sign2DigitalSelectionSheet.showCustom<ExpenseCategory>(
      title: 'Select Expense Type',
      icon: Icons.account_balance_wallet_outlined,
      subtitle: 'Choose the expense category',
      context: context,
      builder: (sheet) => SafeArea(child: ListView(
        shrinkWrap: true, children: [
          for (final type in ExpenseCategory.values)
            ListTile(key: Key('expense-type-${type.name}'), title: Text(type.label),
              selected: _category == type,
              trailing: _category == type
                  ? const Icon(Icons.check_circle_rounded,
                      color: AppColors.primary) : null,
              onTap: () => Navigator.of(sheet).pop(type)),
        ])),
    );
    if (chosen != null && mounted) setState(() { _category = chosen; _error = null; });
  }

  Future<void> _chooseDate() async {
    final result = await showDatePicker(context: context,
      initialDate: _date ?? DateTime.now(),
      firstDate: DateTime(2000), lastDate: DateTime(2100));
    if (result != null && mounted) setState(() { _date = result; _error = null; });
  }

  String _dateText(DateTime date) {
    const months = ['January','February','March','April','May','June','July',
      'August','September','October','November','December'];
    return '${months[date.month-1]} ${date.day}, ${date.year}';
  }

  Future<void> _addPhotos() async {
    if (_busy) return;
    final camera = await showModalBottomSheet<bool>(context: context,
      builder: (sheet) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(key: const Key('expense-choose-gallery'),
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose from gallery'),
            onTap: () => Navigator.of(sheet).pop(false)),
          ListTile(key: const Key('expense-choose-camera'),
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Take a photo'),
            onTap: () => Navigator.of(sheet).pop(true)),
        ])));
    if (camera == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final service = widget.photoSource ?? DeviceJobPhotoSource();
      final chosen = camera
          ? <LocalJobPhotoSelection>[if (await service.camera() case final photo?) photo]
          : await service.upload();
      for (final photo in chosen) {
        DeviceJobPhotoSource.validate(photo.name, photo.bytes);
      }
      if (!mounted) return;
      setState(() {
        final existing = _photos.map((p) => p.sourceKey).toSet();
        for (final photo in chosen) {
          if (existing.add(photo.sourceKey)) _photos.add(photo);
        }
      });
    } on FormatException catch (e) {
      _notice(e.message);
    } catch (_) { _notice('Unable to access photos. Try again.'); }
    finally { if (mounted) setState(() => _busy = false); }
  }

  Widget _photoGrid() => GridView.builder(
    key: const Key('expense-photo-grid'),
    shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: _photos.isEmpty ? 1 : 2,
      mainAxisSpacing: 10, crossAxisSpacing: 15,
      childAspectRatio: _photos.isEmpty ? 390 / 118 : 188 / 118,
    ),
    itemCount: _photos.length + 1,
    itemBuilder: (context,index) {
      if (index == _photos.length) {
        return Sign2DigitalExpenseUploadTile(
          key: const Key('expense-add-photo'),
          enabled: !_busy,
          onTap: _addPhotos,
        );
      }
      return Sign2DigitalPhotoPreview(
        key: Key('expense-photo-$index'),
        bytes: _photos[index].bytes, showDemo: false, compactTile: true,
        onRemove: () => setState(() => _photos.removeAt(index)),
      );
    },
  );

  void _addTag(String raw) {
    final candidates = raw.split(',');
    if (!mounted) return;
    setState(() {
      for (final part in candidates) {
        final tag = part.trim();
        if (tag.isNotEmpty && !_tags.any(
            (item) => item.toLowerCase() == tag.toLowerCase())) {
          _tags.add(tag);
        }
      }
      _tagInput.clear();
    });
  }

  Widget _tagField() => Sign2DigitalOutlinedContainer(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Icon(Icons.sell_outlined, size: 20, color: AppColors.dark),
      const SizedBox(width: 15),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,children: [
        Text.rich(TextSpan(children: [
          const TextSpan(text: 'Tags', style: AppTextStyles.fieldLabel),
          TextSpan(text: ' (optional)', style: AppTextStyles.fieldHint),
        ])),
        const SizedBox(height: 5),
        if (_tags.isNotEmpty) ...[
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final tag in _tags)
              InputChip(
                key: Key('expense-tag-$tag'), label: Text(tag),
                onDeleted: () => setState(() => _tags.remove(tag)),
              ),
          ]),
          const SizedBox(height: 6),
        ],
        Row(children: [
          Expanded(child: TextField(
            key: const Key('expense-tag-input'),
            controller: _tagInput,
            decoration: const InputDecoration(hintText: 'Add tags',
              border: InputBorder.none, isCollapsed: true),
            textInputAction: TextInputAction.done,
            onSubmitted: _addTag,
            onChanged: (value) {
              if (value.contains(',')) _addTag(value);
            },
          )),
          IconButton(key: const Key('expense-add-tag'),
            tooltip: 'Add tag', onPressed: () => _addTag(_tagInput.text),
            icon: const Icon(Icons.add_circle_outline,
              color: AppColors.primary)),
        ]),
      ])),
    ]),
  );

  Future<void> _extractReceipt() async {
    if (_busy || _photos.isEmpty) return;
    setState(() => _busy = true);
    try {
      final image = _photos.firstWhere(
        (file) => RegExp(r'\.(png|jpe?g)$', caseSensitive: false)
            .hasMatch(file.name));
      final suggestion = await RemoteExpenseVoiceExtractionService()
          .extractReceipt(image);
      await _applyVoice(suggestion);
      _notice('Review extracted receipt details before saving.');
    } on StateError {
      _notice('Select a JPG or PNG receipt for AI extraction.');
    } catch (_) {
      _notice('Unable to extract receipt details. Enter them manually.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _applyVoice(ExpenseVoiceSuggestion suggested) async {
    if (!mounted) return;
    setState(() {
      _category ??= suggested.category;
      if (_supplier.text.trim().isEmpty && suggested.supplier != null) {
        _supplier.text = suggested.supplier!;
      }
      _date ??= suggested.date;
      if (_amount.text.trim().isEmpty && suggested.amount != null) {
        _amount.text = suggested.amount!.toStringAsFixed(2);
      }
      if (_description.text.trim().isEmpty && suggested.description != null) {
        _description.text = suggested.description!;
      }
      for (final tag in suggested.tags) {
        if (!_tags.any((t) => t.toLowerCase() == tag.toLowerCase())) {
          _tags.add(tag);
        }
      }
      _voiceJobSuggestion = suggested.jobReference;
    });
    if (suggested.jobReference != null && _job == null) {
      _notice('AI mentioned ${suggested.jobReference}. Select the matching job to confirm.');
    }
  }

  Future<void> _voice() async {
    if (_voiceOpen) return;
    _voiceOpen = true;
    try {
      await showDialog<void>(
        context: context, barrierDismissible: false,
        barrierColor: const Color(0x80000000),
        builder: (_) => AiVoiceFlowDialog(
          recorder: widget.voiceRecorderFactory?.call() ??
              LocalVoiceRecorderService(),
          extraction: OpenAiVoiceJobExtractionService(),
          recordingTitle: 'Record Expense Details',
          onAudioProcessed: (path) async {
            final key = await widget.requestTemporaryApiKey?.call(context) ?? '';
            final extracted = await (widget.voiceExtractionService ??
              RemoteExpenseVoiceExtractionService()).extract(path,key);
            await _applyVoice(extracted);
          },
        ));
    } finally { _voiceOpen = false; }
  }

  Future<void> _save() async {
    if (_busy) return;
    if (_tagInput.text.trim().isNotEmpty) _addTag(_tagInput.text);
    final value = double.tryParse(_amount.text.trim()
        .replaceAll('CHF','').replaceAll(',','.').trim());
    final previous = widget.initialExpense;
    if (_job == null && (previous == null || previous.job.trim().isEmpty)) {
      setState(() => _error = 'Choose an existing job to confirm its ID.');
      return;
    }
    if (_category == null) { setState(() => _error = 'Choose an expense type.'); return; }
    if (_date == null) { setState(() => _error = 'Choose the expense date.'); return; }
    if (value == null || !value.isFinite || value <= 0 ||
        (value * 100 - (value * 100).round()).abs() > .001) {
      setState(() => _error = 'Enter a valid positive CHF amount (maximum 2 decimals).');
      return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      final now = DateTime.now();
      setState(() => _allowPop = true);
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      final event = ExpenseHistoryEvent(
        id: 'expense-event-${now.microsecondsSinceEpoch}',
        title: previous == null ? 'Expense Created' : 'Expense Updated',
        occurredAt: now,
        description: 'Saved locally on this device.',
      );
      final saved = previous == null
          ? ExpenseRecord(
              id: 'local-expense-${now.microsecondsSinceEpoch}',
              jobId: _job?.id ?? previous?.jobId,
              job: _job?.title ?? previous?.job ?? '',
              category: _category!, title: _category!.label,
              report: '', amount: value, date: _date!,
              status: ExpenseStatus.toReview,
              description: _description.text.trim(),

              supplier: _supplier.text.trim(),
              photos: List.unmodifiable(_photos), tags: List.unmodifiable(_tags),
              updatedAt: now, history: [event],
            )
          : previous.copyWith(
              jobId: _job?.id ?? previous?.jobId,
              job: _job?.title ?? previous!.job,
              category: _category!, title: _category!.label,
              amount: value, date: _date!,
              description: _description.text.trim(),

              supplier: _supplier.text.trim(),
              photos: List.unmodifiable(_photos), tags: List.unmodifiable(_tags),
              updatedAt: now, history: [...previous.history, event],
            );
      Navigator.of(context).pop(saved);
    } finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _navigate(int index) async {
    if (index == widget.selectedNavigationIndex) return;
    if (!await _confirmDiscard() || !mounted) return;
    setState(() => _allowPop = true);
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
    widget.onNavigationSelected?.call(index);
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _allowPop || !_dirty,
    onPopInvokedWithResult: (didPop, result) async {
      if (!didPop) await _cancel();
    },
    child: Scaffold(
      backgroundColor: AppColors.white,
      resizeToAvoidBottomInset: true,
      body: SafeArea(bottom: false,child: Column(children: [
        Sign2DigitalHeader(title: 'Expenses', onBack: _cancel),
        Expanded(child: Center(child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: SingleChildScrollView(
            key: const Key('create-expense-scroll'),
            padding: const EdgeInsets.fromLTRB(20,0,20,30),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Sign2DigitalAiVoiceButton(onPressed: _voice),
              const SizedBox(height: 20),
              Sign2DigitalSelectionField(
                key: const Key('expense-add-job'), label: 'Job',
                iconAsset: 'assets/icons/description.svg',
                hintText: _voiceJobSuggestion ?? 'e.g, Site renovation',
                value: _job == null
                    ? widget.initialExpense?.job
                    : '${_job!.title} (${_job!.referenceNumber})',
                trailing: const Icon(Icons.keyboard_arrow_down_rounded,
                  color: AppColors.secondaryText),
                onTap: _chooseJob),
              const SizedBox(height: 20),
              Sign2DigitalSelectionField(
                key: const Key('expense-add-category'), label: 'Expense Type',
                iconAsset: 'assets/icons/description.svg',
                leadingIcon: Icons.donut_large_outlined, hintText: 'e.g, Material',
                value: _category?.label,
                trailing: const Icon(Icons.keyboard_arrow_down_rounded,
                  color: AppColors.secondaryText),
                onTap: _chooseCategory),
              const SizedBox(height: 20),
              Sign2DigitalSelectionField(
                key: const Key('expense-add-date'), label: 'Date',
                iconAsset: 'assets/icons/calendar-outlined.svg',
                hintText: 'August 25, 2026', value: _date == null ? null : _dateText(_date!),
                onTap: _chooseDate),
              const SizedBox(height: 20),
              Sign2DigitalInputField(
                key: const Key('expense-add-amount'),
                label: 'Amount', hintText: '98.00',
                iconAsset: 'assets/icons/hashtag.svg',
                leadingIcon: Icons.monetization_on_outlined,
                inputPrefix: const Text('CHF', style: AppTextStyles.fieldInput),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                controller: _amount),
              const SizedBox(height: 20),
              Sign2DigitalInputField(
                key: const Key('expense-add-description'),
                label: 'Description',
                hintText: 'Complete renovation of the terrace, including new tiles, waterproofing and railings',
                iconAsset: 'assets/icons/description.svg',
                controller: _description, minLines: 2, maxLines: null),
              const SizedBox(height: 20),
              Sign2DigitalInputField(
                key: const Key('expense-add-supplier'),
                label: 'Supplier', hintText: 'Supplier or store',
                iconAsset: 'assets/icons/description.svg',
                controller: _supplier),
              const SizedBox(height: 20),
              _photoGrid(),
              if (_photos.isNotEmpty && ActiveCompanySession.companyId != null) ...[
                const SizedBox(height: 10),
                Sign2DigitalOutlinedButton(
                  key: const Key('expense-ai-extract-receipt'),
                  label: 'Extract Receipt Details',
                  enabled: !_busy, onPressed: _extractReceipt),
              ],
              const SizedBox(height: 20),
              _tagField(),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, key: const Key('expense-add-error'),
                  style: const TextStyle(color: Color(0xFFB42318))),
              ],
              const SizedBox(height: 25),
              Row(children: [
                Expanded(child: Sign2DigitalOutlinedButton(
                  key: const Key('expense-cancel'), label: 'Cancel',
                  primaryOutline: true, onPressed: _cancel)),
                const SizedBox(width: 10),
                Expanded(child: Sign2DigitalPrimaryButton(
                  key: const Key('expense-save-draft'), label: 'Save Expense',
                  loading: _busy, onPressed: _save)),
              ]),
            ]),
          ),
        ))),
      ])),
      bottomNavigationBar: Sign2DigitalBottomNavigationBar(
        selectedIndex: widget.selectedNavigationIndex,
        onSelected: _navigate),
    ),
  );
}
