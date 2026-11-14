import '../../../support/presentation/widgets/support_ai_prompt_hint.dart';
import '../../../../core/widgets/sign2digital_selection_sheet.dart';
import 'package:flutter/material.dart';
import '../../../../core/widgets/sign2digital_styled_bottom_sheet.dart';
import '../../../../core/widgets/sign2digital_confirmation_dialog.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/sign2digital_ai_voice_button.dart';
import '../../../../core/widgets/sign2digital_bottom_navigation_bar.dart';
import '../../../../core/widgets/sign2digital_header.dart';
import '../../../../core/widgets/sign2digital_input_field.dart';
import '../../../../core/widgets/sign2digital_outlined_button.dart';
import '../../../../core/widgets/sign2digital_primary_button.dart';
import '../../../../core/widgets/sign2digital_selection_field.dart';
import '../../../deposits/data/demo_deposit_repository.dart';
import '../../../deposits/data/remote_deposit_repository.dart';
import '../../../auth/data/mobile_auth_repository.dart';
import '../../../../core/services/active_company_session.dart';
import '../../../deposits/domain/deposit_record.dart';
import '../../../jobs/domain/job_model.dart';
import '../../../jobs/presentation/widgets/ai_voice_flow_dialog.dart';
import '../../../jobs/services/voice_job_extraction_service.dart';
import '../../../jobs/services/voice_recorder_service.dart';
import '../../../labour/data/demo_labour_repository.dart';
import '../../../quotes/domain/quote_review_models.dart';
import '../../../quotes/presentation/widgets/sign2digital_document_items_table.dart';
import '../../data/demo_invoice_repository.dart';
import '../../data/remote_invoice_repository.dart';
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
    this.initialJob,
    this.initialIban = '',
    this.currency = 'CHF',
    this.vatBasisPoints = 0,
    this.initialItems = const [],
    this.initialInvoice,
    this.voiceRecorderFactory,
    this.voiceExtractionService,
    this.datePicker,
  });

  final int selectedNavigationIndex;
  final ValueChanged<int>? onNavigationSelected;
  final InvoiceRepository? repository;
  final DepositRepository? depositRepository;
  final List<JobModel>? jobs;
  final JobModel? initialJob;
  final String initialIban, currency;
  final int vatBasisPoints;
  final List<InvoiceLineItem> initialItems;
  final InvoiceRecord? initialInvoice;
  final VoiceRecorderService Function()? voiceRecorderFactory;
  final InvoiceVoiceExtractionService? voiceExtractionService;
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
  List<int> _availableDepositCandidates = [];
  bool _saving = false, _voiceOpen = false;
  late final String _draftId;
  late String _invoiceType;
  int? _sourceQuoteId;
  List<int> _sourceAddendaIds=[];
  int? _sourceVatBasisPoints;
  String? _error, _voiceJobHint;

  List<JobModel> get _jobs => widget.jobs ?? LabourDemoJobs.all;
  int get _vatBasisPoints => _sourceVatBasisPoints ??
      widget.initialInvoice?.vatBasisPoints ?? widget.vatBasisPoints;
  int? get _subtotalMinor => _items.isEmpty ||
      _items.any((item) => !item.valid || item.totalMinor == null)
      ? null : _items.fold<int>(0, (sum, item) => sum + item.totalMinor!);
  int? get _vatMinor => _subtotalMinor == null ? null
      : percentOfMinor(_subtotalMinor!, _vatBasisPoints);
  int? get _totalMinor => _subtotalMinor == null ? null
      : _subtotalMinor! + _vatMinor!;
  int get _appliedDepositMinor {
    if (_repository is! RemoteInvoiceRepository) return _depositPaidMinor;
    if (_invoiceType!='final') return 0;
    final total=_totalMinor;
    if(total==null) return 0;
    final original=widget.initialInvoice;
    // Already reserved credits belong to this draft; only the exact
    // unchanged total can be displayed until the server recalculates.
    if(original!=null && original.jobId==_job?.id &&
        original.invoiceType=='final' &&
        original.totalMinor==total) {
      return original.depositPaidMinor;
    }
    var remaining=total,applied=0;
    for(final amount in _availableDepositCandidates) {
      if(amount<=remaining) {
        applied+=amount;
        remaining-=amount;
      }
    }
    return applied;
  }
  int? get _dueMinor => _totalMinor == null ? null
      : (_totalMinor! - _appliedDepositMinor).clamp(0, _totalMinor!).toInt();

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ??
        (!MobileAuthRepository.shared.isSignedIn &&
            ActiveCompanySession.companyId==null
        ? const DemoInvoiceRepository():RemoteInvoiceRepository.shared);
    _deposits = widget.depositRepository ??
        (_repository is RemoteInvoiceRepository
            ? RemoteDepositRepository.shared:const DemoDepositRepository());
    final initial = widget.initialInvoice;
    _draftId=initial?.id ??
        'local-invoice-${DateTime.now().microsecondsSinceEpoch}';
    _invoiceType=initial?.invoiceType??'final';
    _sourceQuoteId=initial?.sourceQuoteId;
    _sourceAddendaIds=[...?initial?.sourceAddendaIds];
    _iban.text = initial?.iban ?? widget.initialIban;
    _items.addAll(initial?.items ?? widget.initialItems);
    _number.text = initial?.number ??
        (_repository is RemoteInvoiceRepository
          ? '' : 'INV-${DateTime.now().microsecondsSinceEpoch}');
    if (initial == null && widget.initialJob != null) {
      _job = widget.initialJob;
      _client.text = _job!.clientName;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _job != null) _refreshDeposits(_job!.id);
      });
    }
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

  Future<void> _chooseInvoiceItemAction() async {
    final selected=await Sign2DigitalSelectionSheet.showCustom<String>(
      title:'Invoice Items',
      subtitle:'Add an item or import verified work.',
      icon:Icons.receipt_long_outlined,
      context:context,
      builder:(sheet)=>SafeArea(child:Column(
        mainAxisSize:MainAxisSize.min,
        children:[
          ListTile(
            key:const Key('invoice-item-action-manual'),
            title:const Text('Add Invoice Item'),
            onTap:()=>Navigator.of(sheet).pop('manual'),
          ),
          ListTile(
            key:const Key('invoice-item-action-import'),
            title:const Text('Import Approved Work'),
            onTap:()=>Navigator.of(sheet).pop('import'),
          ),
          ListTile(
            key:const Key('invoice-item-action-type'),
            title:Text(_invoiceType=='final'
                ?'Type: Final Invoice':'Type: Deposit Invoice'),
            onTap:()=>Navigator.of(sheet).pop('type'),
          ),
        ],
      )),
    );
    if(!mounted)return;
    if(selected=='manual')await _editItem();
    if(selected=='import')await _chooseInvoiceSource();
    if(selected=='type')await _chooseInvoiceType();
  }

  Future<void> _chooseInvoiceType() async {
    final chosen=await Sign2DigitalSelectionSheet.showCustom<String>(
      title:'Invoice Type',
      subtitle:'Choose the appropriate billing document.',
      icon:Icons.receipt_long_outlined,
      context:context,
      builder:(sheet)=>SafeArea(child:Column(
        mainAxisSize:MainAxisSize.min,
        children:[
          for(final type in const ['final','deposit'])
            ListTile(
              key:Key('invoice-type-$type'),
              title:Text(type=='final'?'Final Invoice':'Deposit Invoice'),
              trailing:_invoiceType==type?
                const Icon(Icons.check_circle_rounded,color:AppColors.primary)
                :null,
              onTap:()=>Navigator.of(sheet).pop(type),
            ),
        ],
      )),
    );
    if(chosen!=null&&mounted){
      setState((){
        _invoiceType=chosen;
        if(chosen=='deposit'){
          _depositPaidMinor=0;
          _sourceAddendaIds=[];
        }
      });
      final job=_job;
      if(job!=null&&chosen=='final')await _refreshDeposits(job.id);
    }
  }

  Future<void> _chooseInvoiceSource() async {
    final job=_job;
    final remote=_repository;
    if(job==null||remote is! RemoteInvoiceRepository){
      _notice('Select a saved job to import verified work items.');
      return;
    }
    final id=int.tryParse(job.id);
    if(id==null)return;
    Map<String,dynamic> result;
    try{
      result=await remote.sources(id);
    }catch(_){
      _notice('Unable to load approved invoice sources.');
      return;
    }
    if(!mounted||_job?.id!=job.id)return;
    final options=<Map<String,dynamic>>[];
    for(final item in result['quotes'] as List){
      if(item is Map)options.add(Map<String,dynamic>.from(item));
    }
    for(final item in result['addenda'] as List){
      if(item is Map&&item['already_invoiced']!=true){
        options.add(Map<String,dynamic>.from(item));
      }
    }
    for(final item in result['completed_work'] as List){
      if(item is Map){
        final m=Map<String,dynamic>.from(item);
        m['kind']='completed_work';
        m['items']=[{
          'description':m['description'],'quantity':0,
          'unit_price_minor':null,
        }];
        options.add(m);
      }
    }
    if(options.isEmpty){
      _notice('No approved quotes, signed addenda or accepted work found.');
      return;
    }
    final selected=await Sign2DigitalSelectionSheet.showCustom<Map<String,dynamic>>(
      title:'Import Approved Work',
      subtitle:'Only verified source descriptions and prices are offered.',
      icon:Icons.receipt_long_outlined,
      context:context,
      isScrollControlled:true,
      builder:(sheet)=>SafeArea(child:SizedBox(
        height:MediaQuery.sizeOf(sheet).height*.55,
        child:ListView(children:[
          for(final item in options)
            ListTile(
              title:Text((item['number']??'Source').toString()),
              subtitle:Text(item['kind']=='approved_quote'
                  ?'Approved quote':item['kind']=='signed_addendum'
                  ?'Signed addendum':'Completed work (price not provided)'),
              onTap:()=>Navigator.of(sheet).pop(item),
            ),
        ]),
      )),
    );
    if(selected==null||!mounted||_job?.id!=job.id)return;
    if(_items.isNotEmpty){
      final replace = await Sign2DigitalConfirmationDialog.show(
        context,
        title: 'Replace Invoice Items?',
        message: 'Current invoice line items will be replaced. '
          'Review all amounts after importing.',
        confirmLabel: 'Replace Items',
        confirmKey: const Key('invoice-import-confirm-replace'),
        icon: Icons.receipt_long_outlined,
      );
      if(replace!=true||!mounted)return;
    }
    final lines=<InvoiceLineItem>[];
    final raw=selected['items'];
    if(raw is List){
      for(final item in raw){
        if(item is! Map)continue;
        final description=(item['description']??'').toString().trim();
        final qty=item['quantity'] is int?item['quantity'] as int:0;
        final price=item['unit_price_minor'];
        if(description.isNotEmpty){
          lines.add(InvoiceLineItem(
            description:description.length>1000
                ?description.substring(0,1000):description,
            quantity:qty>0&&qty<=100000?qty:0,
            unitPriceMinor:price is int&&price>=0?price:null,
          ));
        }
      }
    }
    if(lines.isEmpty){
      _notice('Source has no priced work items. Add invoice items manually.');
      return;
    }
    setState((){
      _items..clear()..addAll(lines);
      final kind=selected['kind'];
      _sourceQuoteId=kind=='approved_quote'?selected['id'] as int:null;
      _sourceAddendaIds=kind=='signed_addendum'
          ?[selected['id'] as int]:[];
      final vat=selected['vat_basis_points'];
      _sourceVatBasisPoints=vat is int?vat:null;
      _error=null;
    });
    if(lines.any((x)=>x.unitPriceMinor==null||x.quantity<=0)){
      _notice('Source price or quantity is missing. Enter it before saving.');
    }
  }

  Future<void> _chooseJob() async {
    final search = TextEditingController();
    try {
      final job = await Sign2DigitalSelectionSheet.showCustom<JobModel>(
        title: 'Select Job / Project',
        icon: Icons.work_outline_rounded,
        subtitle: 'Search jobs for your invoice',
        context: context, isScrollControlled: true,
        builder: (sheet) => StatefulBuilder(
          builder: (sheet, update) => SafeArea(child: SizedBox(
            height: MediaQuery.sizeOf(sheet).height * .65,
            child: Column(children: [
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
                    selected: _job?.id == item.id,
                    trailing: _job?.id == item.id
                        ? const Icon(Icons.check_circle_rounded,
                            color: AppColors.primary) : null,
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
          _client.text = job.clientName;
          _voiceJobHint = null;
          _error = null;
          _depositPaidMinor = 0;
          _availableDepositCandidates=[];
          _sourceQuoteId=null;
          _sourceAddendaIds=[];
          _sourceVatBasisPoints=null;
        });
        await _refreshDeposits(job.id);
      }
    } finally {
      search.dispose();
    }
  }

  Future<void> _refreshDeposits(String jobId) async {
    try {
      if(_repository is RemoteInvoiceRepository){
        final id=int.tryParse(jobId);
        if(id==null||id<1){
          throw StateError('Saved job reference is required.');
        }
        if(_invoiceType=='deposit'){
          if(mounted && _job?.id==jobId){
            setState((){
              _depositPaidMinor=0;
              _availableDepositCandidates=[];
            });
          }
          return;
        }
        final saved=widget.initialInvoice;
        // An existing draft's allocations are reserved by its own invoice;
        // they are excluded from the general available-deposit endpoint.
        if(saved!=null && saved.jobId==jobId &&
            saved.sourceQuoteId==widget.initialInvoice?.sourceQuoteId){
          if(mounted&&_job?.id==jobId){
            setState(()=>_depositPaidMinor=saved.depositPaidMinor);
          }
          return;
        }
        final candidates=await _repository.availableDepositCandidates(id);
        if(mounted&&_job?.id==jobId){
          setState((){
            _availableDepositCandidates=candidates;
            _depositPaidMinor=0;
          });
        }
        return;
      }
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
    // Let FormFields own their editing controllers until the sheet route
    // finishes its exit animation. Disposing temporary controllers when the
    // Navigator.pop future completes can rebuild still-visible TextFields
    // against disposed controllers on iOS.
    var description = previous?.description ?? '';
    var quantity = previous?.quantity.toString() ?? '1';
    var price = previous?.unitPriceMinor == null ? ''
        : (previous!.unitPriceMinor! / 100).toStringAsFixed(2);
    String? error;
    await showSign2DigitalBottomSheet<void>(
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
                  TextFormField(
                    key: const Key('invoice-item-description'),
                    initialValue: description,
                    onChanged: (value) => description = value,
                    decoration: const InputDecoration(labelText: 'Description')),
                  const SizedBox(height: 10),
                  TextFormField(
                    key: const Key('invoice-item-quantity'),
                    initialValue: quantity,
                    onChanged: (value) => quantity = value,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Quantity')),
                  const SizedBox(height: 10),
                  TextFormField(
                    key: const Key('invoice-item-unit-price'),
                    initialValue: price,
                    onChanged: (value) => price = value,
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
                        final qty = int.tryParse(quantity.trim());
                        final unit = price.trim().isEmpty
                            ? null : parseQuoteMinorUnits(price.trim());
                        if (description.trim().isEmpty ||
                            qty == null || qty <= 0 || qty > 100000 ||
                            (price.trim().isNotEmpty && unit == null)) {
                          update(() => error =
                            'Enter a description, valid quantity and price.');
                          return;
                        }
                        final value = InvoiceLineItem(
                          description: description.trim(),
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
      replace = await Sign2DigitalConfirmationDialog.show(
        context,
        title: 'Replace Entered Values?',
        message: 'AI found different details. Keep your existing values '
          'or replace them with the recording.',
        cancelLabel: 'Keep Existing',
        confirmLabel: 'Replace',
        icon: Icons.mic_outlined,
        cancelKey: const Key('invoice-ai-keep'),
        confirmKey: const Key('invoice-ai-replace'),
      );
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
            // Production requests OpenAI via authenticated Laravel.
            // No temporary API key is requested or handled by the app.
            final result = await (widget.voiceExtractionService ??
                RemoteInvoiceVoiceExtractionService()).extract(path);
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
    return Sign2DigitalConfirmationDialog.show(
      context,
      title: 'Discard Invoice?',
      message: 'Unsaved invoice details will be lost.',
      cancelLabel: 'Keep Editing',
      confirmLabel: 'Discard',
      icon: Icons.delete_outline,
      confirmKey: const Key('invoice-discard-confirm'),
    );
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
        (_repository is! RemoteInvoiceRepository &&
          _number.text.trim().isEmpty) || issued == null || due == null ||
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
        id: _draftId,
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
        demoOnly: initial?.demoOnly ??
            (_repository is! RemoteInvoiceRepository),
        iban: _iban.text.trim(),
        notes: _notes.text.trim(),
        currency: widget.currency,
        vatBasisPoints: _vatBasisPoints,
        depositPaidMinor: _appliedDepositMinor,
        items: List<InvoiceLineItem>.unmodifiable(_items),
        invoiceType:_invoiceType,
        lockVersion:initial?.lockVersion??0,
        lifecycleStatus:initial?.lifecycleStatus??'draft',
        sourceQuoteId:_sourceQuoteId,
        sourceAddendaIds:_sourceAddendaIds,
      );
      if (initial == null) {
        if (_repository is RemoteInvoiceRepository) {
          final created = await _repository
              .createInvoice(draft);
          if (mounted) { Navigator.of(context).pop(created); }
        } else {
          await _repository.saveDraft(draft);
          if (mounted) { Navigator.of(context).pop(draft); }
        }
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
        // A new invoice is genuinely empty. Never display sample items.
        // Preserve explicit existing or imported line items when supplied.
        items: [
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
      Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (_repository is RemoteInvoiceRepository)
            Flexible(child: TextButton(
              key: const Key('invoice-item-options'),
              onPressed: _chooseInvoiceItemAction,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
              ),
              child: const Text('Import / Type',
                style: TextStyle(fontFamily: 'Inter',
                  color: AppColors.primary, fontSize: 14)),
            )),
          Flexible(child: TextButton.icon(
            key: const Key('invoice-add-item'),
            onPressed: () => _editItem(),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
            ),
            icon: const Icon(Icons.add, color: AppColors.primary),
            label: const Text('Add item',
              style: TextStyle(fontFamily: 'Inter', fontSize: 14,
                fontWeight: FontWeight.w600, color: AppColors.primary)),
          )),
        ],
      ),
      if (_items.isEmpty)
        const Text('No invoice items added yet.',
          key: Key('invoice-no-items'),
          style: TextStyle(fontFamily: 'Inter', fontSize: 12,
            color: AppColors.secondaryText)),
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
            label: 'Deposit Paid', value: _money(_appliedDepositMinor)),
          const SizedBox(height: 15),
          Sign2DigitalDocumentAmountRow(
            label: 'Amount Due', value: _money(_dueMinor),
            highlight: true),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Theme(
    data: AppTheme.light,
    child: Scaffold(
    backgroundColor: AppColors.white,
    body: SafeArea(bottom: false, child: Column(children: [
      Sign2DigitalHeader(title: 'Invoices', onBack: _cancel,
        trailing: widget.initialInvoice == null ?
            const SupportAiPromptHint(module: 'invoices') : null),
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
            Text(widget.initialInvoice == null
                ? 'Invoice Number: Assigned automatically on save'
                : 'Invoice Number: ${widget.initialInvoice!.number}',
              key: const Key('invoice-auto-number-label'),
              style: const TextStyle(fontFamily: 'Inter', fontSize: 14,
                color: AppColors.secondaryText)),
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
  ));
}
