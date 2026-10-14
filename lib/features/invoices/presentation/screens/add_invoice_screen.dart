import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sign2digital_ai_voice_button.dart';
import '../../../../core/widgets/sign2digital_bottom_navigation_bar.dart';
import '../../../../core/widgets/sign2digital_header.dart';
import '../../../../core/widgets/sign2digital_input_field.dart';
import '../../../../core/widgets/sign2digital_outlined_button.dart';
import '../../../../core/widgets/sign2digital_primary_button.dart';
import '../../../../core/widgets/sign2digital_selection_field.dart';
import '../../../deposits/data/demo_deposit_repository.dart';
import '../../../deposits/domain/deposit_record.dart';
import '../../../jobs/domain/job_model.dart';
import '../../../jobs/presentation/widgets/ai_voice_flow_dialog.dart';
import '../../../jobs/services/voice_job_extraction_service.dart';
import '../../../jobs/services/voice_recorder_service.dart';
import '../../../labour/data/demo_labour_repository.dart';
import '../../../quotes/domain/quote_review_models.dart';
import '../../../quotes/presentation/widgets/sign2digital_document_items_table.dart';
import '../../data/demo_invoice_repository.dart';
import '../../domain/invoice_record.dart';
import '../../services/invoice_voice_extraction_service.dart';

/// Create Invoice uses the same header, fields, audio dialogs and bottom bar
/// as the Labour and Deposit forms, and the shared Quote Preview table.
class AddInvoiceScreen extends StatefulWidget {
  const AddInvoiceScreen({
    super.key,
    this.selectedNavigationIndex = 4,
    this.onNavigationSelected,
    this.repository,
    this.depositRepository,
    this.jobs,
    this.initialIban = '',
    this.currency = 'CHF',
    this.vatBasisPoints = 0,
    this.initialItems = const [],
    this.initialInvoice,
    this.voiceRecorderFactory,
    this.voiceExtractionService,
    this.requestTemporaryApiKey,
    this.datePicker,
  });

  final int selectedNavigationIndex;
  final ValueChanged<int>? onNavigationSelected;
  final InvoiceRepository? repository;
  final DepositRepository? depositRepository;
  final List<JobModel>? jobs;
  final String initialIban, currency;
  final int vatBasisPoints;
  final List<InvoiceLineItem> initialItems;
  final InvoiceRecord? initialInvoice;
  final VoiceRecorderService Function()? voiceRecorderFactory;
  final InvoiceVoiceExtractionService? voiceExtractionService;
  final Future<String?> Function(BuildContext)? requestTemporaryApiKey;
  final Future<DateTime?> Function(BuildContext, DateTime)? datePicker;

  @override
  State<AddInvoiceScreen> createState() => _AddInvoiceScreenState();
}

class _AddInvoiceScreenState extends State<AddInvoiceScreen> {
  final _client = TextEditingController();
  final _number = TextEditingController();
  final _iban = TextEditingController();
  final _notes = TextEditingController();
  final _items = <InvoiceLineItem>[];
  late final InvoiceRepository _repository;
  late final DepositRepository _deposits;
  JobModel? _job;
  DateTime? _issueDate, _dueDate;
  int _depositPaidMinor = 0;
  bool _saving = false, _voiceOpen = false;
  String? _error, _voiceJobHint;

  List<JobModel> get _jobs => widget.jobs ?? LabourDemoJobs.all;
  String get _currency => widget.initialInvoice?.currency ?? widget.currency;
  int get _vatBasisPoints => widget.initialInvoice?.vatBasisPoints ??
      widget.vatBasisPoints;
  int? get _subtotalMinor => _items.isEmpty ||
      _items.any((item) => !item.valid || item.totalMinor == null)
      ? null : _items.fold<int>(0, (sum, item) => sum + item.totalMinor!);
  int? get _vatMinor => _subtotalMinor == null ? null
      : percentOfMinor(_subtotalMinor!, _vatBasisPoints);
  int? get _totalMinor => _subtotalMinor == null ? null
      : _subtotalMinor! + _vatMinor!;
  int? get _dueMinor => _totalMinor == null ? null
      : (_totalMinor! - _depositPaidMinor).clamp(0, _totalMinor!).toInt();

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? const DemoInvoiceRepository();
    _deposits = widget.depositRepository ?? const DemoDepositRepository();
    final initial = widget.initialInvoice;
    _iban.text = initial?.iban ?? widget.initialIban;
    _items.addAll(initial?.items ?? widget.initialItems);
    _number.text = initial?.number ??
        'INV-${DateTime.now().microsecondsSinceEpoch}';
    if (initial != null) {
      _client.text = initial.clientName;
      _notes.text = initial.notes;
      _issueDate = initial.date;
      _dueDate = initial.dueDate;
      _depositPaidMinor = initial.depositPaidMinor;
      for (final candidate in _jobs) {
        if (candidate.id == initial.jobId ||
            candidate.title == initial.project) {
          _job = candidate;
          break;
        }
      }
      if (_job == null) { _voiceJobHint = initial.project; }
    }
  }

  @override
  void dispose() {
    _client.dispose();
    _number.dispose();
    _iban.dispose();
    _notes.dispose();
    super.dispose();
  }

  static String _dateLabel(DateTime day) {
    const months = ['January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'];
    return '${months[day.month - 1]} ${day.day}, ${day.year}';
  }

  String _money(int? minor) => quoteMoney(minor, widget.currency);

  void _notice(String value) {
    if (!mounted) { return; }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(value)));
  }

  Future<void> _chooseJob() async {
    final search = TextEditingController();
    try {
      final job = await showModalBottomSheet<JobModel>(
        context: context, isScrollControlled: true,
        builder: (sheet) => StatefulBuilder(
          builder: (sheet, update) => SafeArea(child: SizedBox(
            height: MediaQuery.sizeOf(sheet).height * .65,
            child: Column(children: [
              const ListTile(title: Text('Select Job / Project')),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  key: const Key('invoice-job-search'),
                  controller: search,
                  onChanged: (_) => update(() {}),
                  decoration: const InputDecoration(hintText: 'Search jobs'),
                )),
              Expanded(child: ListView(children: [
                for (final item in _jobs.where((j) => j.matches(search.text)))
                  ListTile(
                    key: Key('invoice-pick-job-${item.id}'),
                    title: Text(item.title), subtitle: Text(item.referenceNumber),
                    onTap: () => Navigator.of(sheet).pop(item),
                  ),
              ])),
            ]),
          )),
        ),
      );
      if (job != null && mounted) {
        setState(() {
          _job = job;
          if (_client.text.trim().isEmpty) { _client.text = job.clientName; }
          _voiceJobHint = null;
          _error = null;
          _depositPaidMinor = 0;
        });
        await _refreshDeposits(job.id);
      }
    } finally {
      search.dispose();
    }
  }

  Future<void> _refreshDeposits(String jobId) async {
    try {
      final data = await _deposits.listDeposits();
      final amount = data.where((deposit) =>
          deposit.jobId == jobId &&
          deposit.status == DepositStatus.received &&
          deposit.amount.isFinite && deposit.amount > 0)
          .fold<int>(0, (sum, deposit) =>
              sum + (deposit.amount * 100).round());
      if (mounted && _job?.id == jobId) {
        setState(() => _depositPaidMinor = amount);
      }
    } catch (_) {
      if (mounted && _job?.id == jobId) {
        setState(() => _depositPaidMinor = 0);
        _notice('Recorded deposits could not be loaded.');
      }
    }
  }

  Future<void> _pickDate({required bool issue}) async {
    final initial = (issue ? _issueDate : _dueDate) ?? DateTime.now();
    final date = await (widget.datePicker?.call(context, initial) ??
        showDatePicker(
          context: context,
          initialDate: initial,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        ));
    if (date != null && mounted) {
      setState(() {
        if (issue) { _issueDate = date; } else { _dueDate = date; }
        _error = null;
      });
    }
  }

  Future<void> _editItem([int? index]) async {
    final previous = index == null ? null : _items[index];
    final description = TextEditingController(
      text: previous?.description ?? '');
    final quantity = TextEditingController(
      text: previous?.quantity.toString() ?? '1');
    final price = TextEditingController(
      text: previous?.unitPriceMinor == null ? ''
          : (previous!.unitPriceMinor! / 100).toStringAsFixed(2));
    String? error;
    try {
      await showModalBottomSheet<void>(
        context: context, isScrollControlled: true,
        builder: (sheet) => StatefulBuilder(
          builder: (sheet, update) => SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20,
                MediaQuery.viewInsetsOf(sheet).bottom + 20),
              child: SingleChildScrollView(child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(index == null ? 'Add invoice item' : 'Edit invoice item',
                    style: const TextStyle(fontFamily: 'Inter',
                      fontSize: 18, color: AppColors.dark,
                      fontWeight: FontWeight.w600)),
                  const SizedBox(height: 15),
                  TextField(
                    key: const Key('invoice-item-description'),
                    controller: description,
                    decoration: const InputDecoration(labelText: 'Description')),
                  const SizedBox(height: 10),
                  TextField(
                    key: const Key('invoice-item-quantity'),
                    controller: quantity,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Quantity')),
                  const SizedBox(height: 10),
                  TextField(
                    key: const Key('invoice-item-unit-price'),
                    controller: price,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Unit Price (${widget.currency})',
                      hintText: 'Leave blank if not priced')),
                  if (error != null) ...[
                    const SizedBox(height: 10),
                    Text(error!, style:
                      const TextStyle(color: Color(0xFFB42318))),
                  ],
                  const SizedBox(height: 15),
                  Row(children: [
                    if (index != null) ...[
                      TextButton(
                        key: const Key('invoice-item-remove'),
                        onPressed: () {
                          setState(() => _items.removeAt(index));
                          Navigator.of(sheet).pop();
                        }, child: const Text('Remove')),
                      const Spacer(),
                    ],
                    Expanded(child: Sign2DigitalPrimaryButton(
                      key: const Key('invoice-item-apply'),
                      label: index == null ? 'Add item' : 'Update item',
                      onPressed: () {
                        final qty = int.tryParse(quantity.text.trim());
                        final unit = price.text.trim().isEmpty
                            ? null : parseQuoteMinorUnits(price.text.trim());
                        if (description.text.trim().isEmpty ||
                            qty == null || qty <= 0 || qty > 100000 ||
                            (price.text.trim().isNotEmpty && unit == null)) {
                          update(() => error =
                            'Enter a description, valid quantity and price.');
                          return;
                        }
                        final value = InvoiceLineItem(
                          description: description.text.trim(),
                          quantity: qty, unitPriceMinor: unit);
                        setState(() {
                          if (index == null) { _items.add(value); }
                          else { _items[index] = value; }
                          _error = null;
                        });
                        Navigator.of(sheet).pop();
                      },
                    )),
                  ]),
                ],
              )),
            ),
          ),
        ),
      );
    } finally {
      description.dispose();
      quantity.dispose();
      price.dispose();
    }
  }

  Future<String?> _askApiKey(BuildContext parent) {
    String value = '';
    return showDialog<String>(
      context: parent,
      builder: (dialog) => AlertDialog(
        title: const Text('Connect Invoice AI'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Enter a temporary OpenAI API key for testing. '
            'It is not saved. Production requires a secure backend.'),
          TextField(
            key: const Key('invoice-ai-key'),
            obscureText: true,
            onChanged: (text) => value = text,
            decoration: const InputDecoration(labelText: 'OpenAI API key')),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(),
            child: const Text('Cancel')),
          TextButton(
            key: const Key('invoice-ai-extract'),
            onPressed: () {
              if (value.trim().isNotEmpty) {
                Navigator.of(dialog).pop(value.trim());
              }
            },
            child: const Text('Process recording')),
        ],
      ),
    );
  }

  Future<void> _applyVoice(InvoiceVoiceSuggestion result) async {
    if (!mounted) { return; }
    JobModel? matched;
    final reference = result.jobReference?.toLowerCase();
    if (reference != null) {
      for (final job in _jobs) {
        if (job.id.toLowerCase() == reference ||
            job.title.toLowerCase() == reference ||
            job.referenceNumber.toLowerCase() == reference) {
          matched = job;
          break;
        }
      }
    }
    final conflicts = <bool>[
      matched != null && _job != null && _job!.id != matched.id,
      result.clientName != null && _client.text.trim().isNotEmpty &&
          _client.text.trim() != result.clientName,
      result.invoiceNumber != null && _number.text.trim().isNotEmpty &&
          _number.text.trim() != result.invoiceNumber,
      result.iban != null && _iban.text.trim().isNotEmpty &&
          _iban.text.trim() != result.iban,
      result.issueDate != null && _issueDate != null &&
          _issueDate != result.issueDate,
      result.dueDate != null && _dueDate != null &&
          _dueDate != result.dueDate,
      result.notes != null && _notes.text.trim().isNotEmpty &&
          _notes.text.trim() != result.notes,
      result.items.isNotEmpty && _items.isNotEmpty,
    ].contains(true);
    var replace = false;
    if (conflicts) {
      replace = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: const Text('Replace entered values?'),
          content: const Text('AI found different details. '
            'Keep your existing values or replace them with the recording.'),
          actions: [
            TextButton(
              key: const Key('invoice-ai-keep'),
              onPressed: () => Navigator.of(dialog).pop(false),
              child: const Text('Keep existing')),
            TextButton(
              key: const Key('invoice-ai-replace'),
              onPressed: () => Navigator.of(dialog).pop(true),
              child: const Text('Replace')),
          ],
        ),
      ) ?? false;
    }
    if (!mounted) { return; }
    setState(() {
      if (matched != null && (replace || _job == null)) {
        _job = matched;
        _depositPaidMinor = 0;
      }
      if (result.clientName != null &&
          (replace || _client.text.trim().isEmpty)) {
        _client.text = result.clientName!;
      }
      if (result.invoiceNumber != null &&
          (replace || _number.text.trim().isEmpty)) {
        _number.text = result.invoiceNumber!;
      }
      if (result.iban != null &&
          (replace || _iban.text.trim().isEmpty)) {
        _iban.text = result.iban!;
      }
      if (result.issueDate != null && (replace || _issueDate == null)) {
        _issueDate = result.issueDate;
      }
      if (result.dueDate != null && (replace || _dueDate == null)) {
        _dueDate = result.dueDate;
      }
      if (result.notes != null &&
          (replace || _notes.text.trim().isEmpty)) {
        _notes.text = result.notes!;
      }
      if (result.items.isNotEmpty && (replace || _items.isEmpty)) {
        _items
          ..clear()
          ..addAll(result.items.map((line) => InvoiceLineItem(
            description: line.description,
            quantity: line.quantity,
            unitPriceMinor: line.unitPriceMinor)));
      }
      _error = null;
      _voiceJobHint = matched == null ? result.jobReference : null;
    });
    if (matched != null && _job?.id == matched.id) {
      await _refreshDeposits(matched.id);
    }
    if (reference != null && matched == null) {
      _notice('Select the matching job for ${result.jobReference}.');
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
          recordingTitle: 'Record Invoice Details',
          onAudioProcessed: (path) async {
            final key = await (widget.requestTemporaryApiKey?.call(context) ??
                _askApiKey(context));
            if (key == null) {
              throw StateError('AI processing was cancelled.');
            }
            final result = await (widget.voiceExtractionService ??
                const OpenAiInvoiceVoiceExtractionService()).extract(
                  path, key);
            await _applyVoice(result);
          },
        ),
      );
    } finally {
      _voiceOpen = false;
    }
  }

  bool get _dirty => _job != null || _client.text.trim().isNotEmpty ||
      _iban.text.trim().isNotEmpty || _issueDate != null ||
      _dueDate != null || _items.isNotEmpty || _notes.text.trim().isNotEmpty;

  Future<bool> _confirmDiscard() async {
    if (_saving) { return false; }
    if (!_dirty) { return true; }
    return await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Discard invoice?'),
        content: const Text('Unsaved invoice details will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: const Text('Keep editing')),
          TextButton(
            key: const Key('invoice-discard-confirm'),
            onPressed: () => Navigator.of(dialog).pop(true),
            child: const Text('Discard')),
        ],
      ),
    ) ?? false;
  }

  Future<void> _cancel() async {
    if (await _confirmDiscard() && mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _save() async {
    if (_saving) { return; }
    FocusManager.instance.primaryFocus?.unfocus();
    final job = _job, issued = _issueDate, due = _dueDate;
    final subtotal = _subtotalMinor;
    final total = _totalMinor;
    if (job == null || _client.text.trim().isEmpty ||
        _number.text.trim().isEmpty || issued == null || due == null ||
        due.isBefore(issued) || !isValidInvoiceIban(_iban.text) ||
        _vatBasisPoints < 0 || _vatBasisPoints > 10000 ||
        subtotal == null || total == null || total <= 0 ||
        _items.any((item) => !item.valid)) {
      setState(() => _error = 'Select a job, client, valid IBAN and dates '
        '(due date not before issue date). Price every line item.');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      final initial = widget.initialInvoice;
      final draft = InvoiceRecord(
        id: initial?.id ??
            'local-invoice-${DateTime.now().microsecondsSinceEpoch}',
        number: _number.text.trim(),
        project: job.title, jobId: job.id,
        clientName: _client.text.trim(),
        amount: total / 100,
        date: issued, dueDate: due,
        status: initial?.status ?? InvoiceStatus.draft,
        manuallyPaidAt: initial?.manuallyPaidAt,
        sentAt: initial?.sentAt,
        history: initial?.history ?? const [],
        payments: initial?.payments ?? const [],
        demoOnly: initial?.demoOnly ?? true,
        iban: _iban.text.trim(),
        notes: _notes.text.trim(),
        currency: widget.currency,
        vatBasisPoints: _vatBasisPoints,
        depositPaidMinor: _depositPaidMinor,
        items: List<InvoiceLineItem>.unmodifiable(_items),
      );
      if (initial == null) {
        await _repository.saveDraft(draft);
        if (mounted) { Navigator.of(context).pop(draft); }
      } else {
        final saved = await _repository.updateInvoice(draft);
        if (mounted) { Navigator.of(context).pop(saved); }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error =
          'Could not save the invoice. Review the details and try again.');
      }
    } finally {
      if (mounted) { setState(() => _saving = false); }
    }
  }

  Future<void> _navigate(int index) async {
    if (index == widget.selectedNavigationIndex || _saving) { return; }
    if (!await _confirmDiscard() || !mounted) { return; }
    final callback = widget.onNavigationSelected;
    Navigator.of(context).pop();
    callback?.call(index);
  }

  Widget _itemsTable() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Sign2DigitalDocumentItemsTable(
        key: const Key('invoice-items-table'),
        // Visual-only Figma examples until genuine items are added.
        // They are never included in totals or saved invoice records.
        items: _items.isEmpty
            ? [
                Sign2DigitalDocumentTableLine(
                  description: 'Electric Installation', quantity: '1',
                  unitPrice: _money(9800), total: _money(9800)),
                const Sign2DigitalDocumentTableLine(
                  description: 'Material', quantity: '1',
                  unitPrice: '—', total: '—'),
                Sign2DigitalDocumentTableLine(
                  description: 'Labour', quantity: '1',
                  unitPrice: _money(9800), total: _money(9800)),
              ]
            : [
                for (final item in _items)
                  Sign2DigitalDocumentTableLine(
                    description: item.description,
                    quantity: item.quantity.toString(),
                    unitPrice: _money(item.unitPriceMinor),
                    total: _money(item.totalMinor),
                  ),
              ],
        onItemTap: _items.isEmpty ? null : (index) => _editItem(index),
      ),
      Align(alignment: Alignment.centerRight,
        child: TextButton.icon(
          key: const Key('invoice-add-item'),
          onPressed: () => _editItem(),
          icon: const Icon(Icons.add),
          label: const Text('Add item'),
        )),
      if (_items.isEmpty)
        const Text('Example items only — add your actual invoice items.',
          key: Key('invoice-example-items-notice'),
          style: TextStyle(fontFamily: 'Inter', fontSize: 12,
            color: AppColors.placeholder)),
      if (_items.any((item) => item.totalMinor == null))
        const Text('Unpriced items must be completed before creating.',
          key: Key('invoice-unpriced-notice'),
          style: TextStyle(fontFamily: 'Inter', fontSize: 12,
            color: AppColors.placeholder)),
    ],
  );

  Widget _summary() => Align(
    alignment: Alignment.centerRight,
    child: FractionallySizedBox(
      widthFactor: .75,
      child: Column(
        key: const Key('invoice-financial-summary'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Sign2DigitalDocumentAmountRow(
            label: 'Subtotal', value: _money(_subtotalMinor)),
          const SizedBox(height: 15),
          Sign2DigitalDocumentAmountRow(
            label: 'VAT (${(_vatBasisPoints / 100).toStringAsFixed(0)}%)',
            value: _money(_vatMinor)),
          const SizedBox(height: 15),
          Sign2DigitalDocumentAmountRow(
            label: 'Total', value: _money(_totalMinor), highlight: true),
          const SizedBox(height: 15),
          Sign2DigitalDocumentAmountRow(
            label: 'Deposit Paid', value: _money(_depositPaidMinor)),
          const SizedBox(height: 15),
          Sign2DigitalDocumentAmountRow(
            label: 'Amount Due', value: _money(_dueMinor),
            highlight: true),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.white,
    body: SafeArea(bottom: false, child: Column(children: [
      Sign2DigitalHeader(title: 'Invoices', onBack: _cancel),
      Expanded(child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          key: const Key('invoice-create-scroll'),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          children: [
            Sign2DigitalAiVoiceButton(onPressed: _voice),
            const SizedBox(height: 20),
            Sign2DigitalSelectionField(
              key: const Key('invoice-create-job'),
              label: 'Job / Project',
              hintText: _voiceJobHint ?? 'e.g, Site renovation',
              iconAsset: 'assets/icons/description.svg',
              value: _job?.title, onTap: _chooseJob,
              trailing: const Icon(Icons.keyboard_arrow_down_rounded,
                color: AppColors.secondaryText)),
            const SizedBox(height: 20),
            Sign2DigitalInputField(
              key: const Key('invoice-create-client'),
              label: 'Client',
              hintText: 'e.g, Marc dupont',
              iconAsset: 'assets/icons/user.svg', controller: _client,
              textCapitalization: TextCapitalization.words),
            const SizedBox(height: 20),
            Sign2DigitalInputField(
              key: const Key('invoice-create-number'),
              label: 'Invoice Number', hintText: 'e.g, A-0005',
              iconAsset: 'assets/icons/hashtag.svg', controller: _number),
            const SizedBox(height: 20),
            Sign2DigitalInputField(
              key: const Key('invoice-create-iban'),
              label: 'IBAN',
              hintText: 'e.g. CH93 0076 2011 6238 5295 7',
              iconAsset: 'assets/icons/iban.svg', controller: _iban),
            const SizedBox(height: 20),
            Sign2DigitalSelectionField(
              key: const Key('invoice-create-date'),
              label: 'Issue Date', hintText: 'August 25, 2026',
              iconAsset: 'assets/icons/calendar-outlined.svg',
              value: _issueDate == null ? null : _dateLabel(_issueDate!),
              onTap: () => _pickDate(issue: true)),
            const SizedBox(height: 20),
            Sign2DigitalSelectionField(
              key: const Key('invoice-create-due-date'),
              label: 'Due Date', hintText: 'August 25, 2026',
              iconAsset: 'assets/icons/calendar-outlined.svg',
              value: _dueDate == null ? null : _dateLabel(_dueDate!),
              onTap: () => _pickDate(issue: false)),
            const SizedBox(height: 20),
            _itemsTable(),
            const SizedBox(height: 10),
            _summary(),
            const SizedBox(height: 20),
            Sign2DigitalInputField(
              key: const Key('invoice-create-notes'),
              label: 'Notes (optional)',
              hintText: 'Complete renovation of the terrace, including '
                'new tiles, waterproofing and railings',
              iconAsset: 'assets/icons/description.svg',
              controller: _notes,
              minLines: 2, maxLines: null,
              textCapitalization: TextCapitalization.sentences),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, key: const Key('invoice-create-error'),
                style: const TextStyle(
                  fontFamily: 'Inter', color: Color(0xFFB42318))),
            ],
            const SizedBox(height: 25),
            Row(children: [
              Expanded(child: Sign2DigitalOutlinedButton(
                key: const Key('invoice-create-cancel'),
                label: 'Cancel', primaryOutline: true,
                enabled: !_saving, onPressed: _cancel)),
              const SizedBox(width: 10),
              Expanded(child: Sign2DigitalPrimaryButton(
                key: const Key('invoice-create-save'),
                label: widget.initialInvoice == null ? 'Create Invoice' : 'Save Changes',
                loading: _saving,
                onPressed: _save)),
            ]),
          ],
        ),
      ))),
    ])),
    bottomNavigationBar: Sign2DigitalBottomNavigationBar(
      selectedIndex: widget.selectedNavigationIndex,
      onSelected: _navigate),
  );
}
