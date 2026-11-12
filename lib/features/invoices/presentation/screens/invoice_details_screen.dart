import '../../../../core/navigation/sign2digital_navigation.dart';
import '../../../../core/widgets/sign2digital_subscription_gate.dart';
import 'package:flutter/material.dart';
import '../../../../core/widgets/sign2digital_styled_bottom_sheet.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sign2digital_header.dart';
import '../../../../core/widgets/sign2digital_information_table.dart';
import '../../../../core/widgets/sign2digital_outlined_button.dart';
import '../../../../core/widgets/sign2digital_primary_button.dart';
import '../../../clients/presentation/widgets/sign2digital_details_tabs.dart';
import '../../../clients/presentation/widgets/sign2digital_status_badge.dart';
import '../../../documents/presentation/widgets/sign2digital_document_history.dart';
import '../../../quotes/domain/quote_review_models.dart';
import '../../../quotes/presentation/widgets/sign2digital_document_items_table.dart';
import '../../domain/invoice_record.dart';
import '../../data/remote_invoice_repository.dart';
import '../../../jobs/domain/job_model.dart';
import '../../services/invoice_pdf_service.dart';
import 'add_invoice_screen.dart';
import 'invoice_preview_screen.dart';
import '../widgets/mark_invoice_paid_dialog.dart';

typedef InvoicePdfAction = Future<void> Function(
    InvoiceRecord invoice, Uint8List pdfBytes);

/// Reuses the existing Expenses/Labour details layout and shared data tables.
/// Only actually recorded invoice payments and history are displayed.
class InvoiceDetailsScreen extends StatefulWidget {
  const InvoiceDetailsScreen({
    super.key,
    required this.invoice,
    required this.repository,
    this.onDownload,
    this.onSend,
    this.selectedNavigationIndex = 4,
    this.onNavigationSelected,
  });

  final InvoiceRecord invoice;
  final InvoiceRepository repository;
  final InvoicePdfAction? onDownload, onSend;
  final int selectedNavigationIndex;
  final ValueChanged<int>? onNavigationSelected;

  @override
  State<InvoiceDetailsScreen> createState() => _InvoiceDetailsScreenState();
}

class _InvoiceDetailsScreenState extends State<InvoiceDetailsScreen> {
  late InvoiceRecord _record;
  int _tab = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _record = widget.invoice;
  }

  @override
  void didUpdateWidget(covariant InvoiceDetailsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.invoice.id != widget.invoice.id) {
      _record = widget.invoice;
      _tab = 0;
    }
  }

  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  static String _date(DateTime value) =>
      '${value.day} ${_months[value.month - 1]} ${value.year}';

  static String _timestamp(DateTime value) {
    final local = value.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    return '${_date(local)}, $hour:'
        '${local.minute.toString().padLeft(2, '0')} '
        '${local.hour < 12 ? 'AM' : 'PM'}';
  }

  String _money(int? minor) => quoteMoney(minor, _record.currency);
  String get _filename =>
      'Sign2Digital_Invoice_${_record.number.replaceAll(
        RegExp(r'[^A-Za-z0-9_-]'), '_')}.pdf';

  void _notice(String message) {
    if (!mounted) { return; }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _summary() => Row(
    key: const Key('invoice-detail-summary'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      CircleAvatar(
        radius: 20,
        backgroundColor: const Color(0xFFE3ECF0),
        child: const Icon(Icons.account_balance_outlined,
          size: 24, color: AppColors.primary),
      ),
      const SizedBox(width: 10),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_record.project,
            maxLines: 2, overflow: TextOverflow.ellipsis,
            key: const Key('invoice-details-project'),
            style: const TextStyle(fontFamily: 'Inter',
              fontSize: 18, fontWeight: FontWeight.w600,
              color: AppColors.dark)),
          const SizedBox(height: 5),
          Text('Client: ${_record.clientName}',
            maxLines: 2, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontFamily: 'Inter', fontSize: 14,
              color: AppColors.placeholder)),
          const SizedBox(height: 3),
          Text(_date(_record.date), style: const TextStyle(
            fontFamily: 'Inter', fontSize: 14,
            color: AppColors.placeholder)),
        ],
      )),
      const SizedBox(width: 8),
      Sign2DigitalStatusBadge(status: _record.status.label),
    ],
  );

  Widget _amount() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(_record.formattedAmount,
        key: const Key('invoice-details-amount'),
        style: const TextStyle(fontFamily: 'Inter', fontSize: 22,
          fontWeight: FontWeight.w700, color: AppColors.dark)),
      const SizedBox(height: 5),
      Text(_date(_record.date),
        style: const TextStyle(fontFamily: 'Inter', fontSize: 14,
          fontWeight: FontWeight.w500, color: AppColors.placeholder)),
    ],
  );

  Future<void> _copyJob() async {
    await Clipboard.setData(ClipboardData(text: _record.project));
    _notice('Job copied to clipboard.');
  }

  Widget _details() {
    final invoice = _record;
    final payments = invoice.payments;
    final rows = <Sign2DigitalInformationRow>[
      Sign2DigitalInformationRow('Job', invoice.project, onCopy: _copyJob),
      Sign2DigitalInformationRow('Date', _date(invoice.date)),
      Sign2DigitalInformationRow('Client', invoice.clientName),
      Sign2DigitalInformationRow('Issue Date', _date(invoice.date)),
      Sign2DigitalInformationRow('Due Date',
        invoice.dueDate == null ? 'Not recorded' : _date(invoice.dueDate!)),
      Sign2DigitalInformationRow('Invoice Number', invoice.number),
      Sign2DigitalInformationRow('Subtotal', _money(invoice.subtotalMinor)),
      Sign2DigitalInformationRow(
        'VAT ${(invoice.vatBasisPoints / 100).toStringAsFixed(2)}%',
        _money(invoice.vatMinor)),
      Sign2DigitalInformationRow('Total', invoice.formattedAmount),
      Sign2DigitalInformationRow('Amount Received',
        payments.isEmpty ? 'Not recorded' : _money(invoice.receivedMinor)),
      Sign2DigitalInformationRow('Amount Due',
        _money(invoice.amountDueMinor)),
      Sign2DigitalInformationRow('Status', invoice.status.label,
        isStatus: true),
      if (invoice.sentAt != null)
        Sign2DigitalInformationRow('Sent Date',
          _timestamp(invoice.sentAt!)),
      if (invoice.manuallyPaidAt != null)
        Sign2DigitalInformationRow('Paid Date',
          _timestamp(invoice.manuallyPaidAt!)),
      Sign2DigitalInformationRow('Payment History',
        payments.isEmpty ? 'No payment is recorded yet'
            : '${payments.length} recorded payment(s)'),
    ];
    return Sign2DigitalInformationTable(
      key: const Key('invoice-details-table'),
      rows: rows);
  }

  Widget _items() {
    final rows = _record.items;
    if (rows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Text('No invoice items recorded.',
          key: Key('invoice-details-items-empty'),
          style: TextStyle(fontFamily: 'Inter', fontSize: 14,
            color: AppColors.placeholder)),
      );
    }
    return Column(
      key: const Key('invoice-details-items'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Sign2DigitalDocumentItemsTable(
          items: [
            for (final item in rows)
              Sign2DigitalDocumentTableLine(
                description: item.description,
                quantity: '${item.quantity}',
                unitPrice: _money(item.unitPriceMinor),
                total: _money(item.totalMinor),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Align(alignment: Alignment.centerRight,
          child: FractionallySizedBox(
            widthFactor: .75,
            child: Column(children: [
              Sign2DigitalDocumentAmountRow(
                label: 'Subtotal', value: _money(_record.subtotalMinor)),
              Sign2DigitalDocumentAmountRow(
                label: 'VAT ${(_record.vatBasisPoints / 100).toStringAsFixed(2)}%',
                value: _money(_record.vatMinor)),
              Sign2DigitalDocumentAmountRow(
                label: 'Total', value: _record.formattedAmount,
                highlight: true),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _payments() {
    final payments = _record.payments;
    if (payments.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Text('No payment is recorded yet.',
          key: Key('invoice-details-payments-empty'),
          style: TextStyle(fontFamily: 'Inter', fontSize: 14,
            color: AppColors.placeholder)),
      );
    }
    return Column(
      key: const Key('invoice-details-payments'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final payment in payments) ...[
          Sign2DigitalInformationTable(
            key: Key('invoice-payment-${payment.id}'),
            rows: [
              Sign2DigitalInformationRow('Amount',
                _money(payment.amountMinor)),
              Sign2DigitalInformationRow('Payment Method', payment.method),
              Sign2DigitalInformationRow('Date', _timestamp(payment.paidAt)),
              if (payment.referenceNumber?.trim().isNotEmpty == true)
                Sign2DigitalInformationRow('Reference Number',
                  payment.referenceNumber!),
              Sign2DigitalInformationRow('Status', payment.status,
                isStatus: true),
            ],
          ),
          const SizedBox(height: 15),
        ],
        Sign2DigitalInformationTable(rows: [
          Sign2DigitalInformationRow('Amount Received',
            _money(_record.receivedMinor)),
          Sign2DigitalInformationRow('Amount Due',
            _money(_record.amountDueMinor)),
        ]),
      ],
    );
  }

  Widget _history() {
    final events = _record.history.toList()
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    if (events.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Text('No recorded invoice history is available.',
          key: Key('invoice-details-history-empty'),
          style: TextStyle(fontFamily: 'Inter', fontSize: 14,
            color: AppColors.placeholder)),
      );
    }
    return Column(
      key: const Key('invoice-details-history'),
      children: [
        for (final event in events) ...[
          Sign2DigitalTrackingRow(
            key: Key('invoice-history-${event.id}'),
            title: event.title,
            historyStyle: true,
            historyIcon: Icons.history_rounded,
            dateText: _timestamp(event.occurredAt),
            actorText: event.description,
          ),
          const SizedBox(height: 20),
        ],
      ],
    );
  }

  Future<void> _approve() async {
    if(_busy||_record.demoOnly||_record.lifecycleStatus!='draft')return;
    final confirmed=await showDialog<bool>(
      context:context,
      builder:(dialog)=>AlertDialog(
        title:const Text('Approve Invoice?'),
        content:Text('Approve and lock invoice ${_record.number}? '
          'This confirms the reviewed invoice; no payment will be charged '
          'and no customer email will be sent.'),
        actions:[
          TextButton(onPressed:()=>Navigator.of(dialog).pop(false),
            child:const Text('Cancel')),
          TextButton(key:const Key('invoice-approve-confirm'),
            onPressed:()=>Navigator.of(dialog).pop(true),
            child:const Text('Approve Invoice')),
        ],
      ),
    );
    if(confirmed!=true||!mounted)return;
    setState(()=>_busy=true);
    try{
      final approved=await widget.repository.approveInvoice(_record.id);
      if(!mounted)return;
      if(approved.id!=_record.id||approved.lifecycleStatus!='approved'){
        throw StateError('Invoice approval was not verified.');
      }
      setState(()=>_record=approved);
      _notice('Invoice approved. Delivery is a separate action.');
    }catch(error){
      if(mounted && !await Sign2DigitalSubscriptionGate.handle(
          context, error)) {
        _notice('Unable to approve. Refresh invoice and try again.');
      }
    }finally{
      if(mounted)setState(()=>_busy=false);
    }
  }

  Future<void> _markPaid() async {
    if (_busy || !_record.status.canMarkPaid) { return; }
    final updated = await MarkInvoicePaidDialog.show(
      context, invoice: _record, repository: widget.repository);
    if (!mounted || updated == null) { return; }
    setState(() => _record = updated);
    _notice('Manual payment recorded; no bank transaction initiated.');
  }


  bool get _canDeliver => const ['approved', 'sent']
      .contains(_record.lifecycleStatus);

  Future<bool> _confirmLiveSend() async {
    if (_record.clientEmail.trim().isEmpty) {
      _notice('Add a customer email address before sending the invoice.');
      return false;
    }
    return await showSign2DigitalBottomSheet<bool>(
      context:context,showDragHandle:true,
      builder:(sheetContext)=>SafeArea(child:Padding(
        padding:const EdgeInsets.all(20),
        child:Column(mainAxisSize:MainAxisSize.min,
          crossAxisAlignment:CrossAxisAlignment.stretch,children:[
          const Text('Send Invoice',style:TextStyle(
            fontFamily:'Inter',fontSize:20,fontWeight:FontWeight.w600,
            color:AppColors.dark)),
          const SizedBox(height:12),
          Text('Send the verified issued invoice PDF to ${_record.clientEmail}?',
            style:const TextStyle(fontFamily:'Inter',fontSize:14,
              color:AppColors.dark)),
          const SizedBox(height:20),
          Sign2DigitalPrimaryButton(label:'Confirm Send',
            onPressed:()=>Navigator.of(sheetContext).pop(true)),
          const SizedBox(height:8),
        ]),
      )),
    )??false;
  }

  Future<void> _pdf({required bool share}) async {
    if (_busy) { return; }
    if (!_canDeliver) {
      _notice('Approve the invoice before sending or downloading its PDF.');
      return;
    }
    if (!_record.demoOnly && share && !await _confirmLiveSend())return;
    setState(() => _busy = true);
    try {
      final invoice = _record;
      if (!invoice.demoOnly) {
        if(widget.repository is! RemoteInvoiceRepository){
          throw StateError('Official invoice API unavailable.');
        }
        final remote=widget.repository as RemoteInvoiceRepository;
        if(share){
          await remote.sendIssuedInvoice(invoice.id,
            recipientEmail:invoice.clientEmail,mode:'pdf');
          final updated=await remote.invoiceDetail(invoice.id);
          if(mounted)setState(()=>_record=updated);
          _notice('Invoice email delivery confirmed.');
          return;
        }
        final verified=await remote.issuedPdf(invoice.id);
        if(widget.onDownload!=null){
          await widget.onDownload!(invoice,verified);
        }else{
          final opened=await Printing.layoutPdf(
            name:_filename,onLayout:(_) async=>verified);
          if(!opened)throw StateError('PDF print/save cancelled');
        }
        _notice('Verified issued invoice PDF opened.');
        return;
      }
      final bytes=await const Sign2DigitalInvoicePdfBuilder().build(invoice);
      if(bytes.isEmpty)throw StateError('PDF generation failed');
      if(share){
        if(widget.onSend!=null){
          await widget.onSend!(invoice,bytes);
        }else{
          await Printing.sharePdf(bytes:bytes,filename:_filename);
        }
        _notice('Share sheet opened; invoice delivery is not confirmed.');
      }else{
        if(widget.onDownload!=null){
          await widget.onDownload!(invoice,bytes);
        }else{
          final opened=await Printing.layoutPdf(
            name:_filename,onLayout:(_) async=>bytes);
          if(!opened)throw StateError('PDF print/save cancelled');
        }
        _notice('PDF print/save workflow opened.');
      }
    }catch(_){
      _notice('Invoice action failed. Check delivery history before retrying.');
    }finally{
      if(mounted)setState(()=>_busy=false);
    }
  }

  Future<void> _edit() async {
    if (_busy) { return; }
    if (_record.status == InvoiceStatus.paid ||
        (!_record.demoOnly&&_record.lifecycleStatus!='draft')) {
      _notice('Approved invoices cannot be edited.');
      return;
    }
    List<JobModel>? jobs;
    if(widget.repository is RemoteInvoiceRepository){
      try{
        jobs=await (widget.repository as RemoteInvoiceRepository).jobs();
      }catch(_){
        _notice('Unable to load current jobs.');
        return;
      }
    }
    if(!mounted)return;
    final updated = await Sign2DigitalNavigation.push<InvoiceRecord>(context,
      MaterialPageRoute<InvoiceRecord>(
        builder: (_) => AddInvoiceScreen(
          initialInvoice: _record,
          jobs:jobs,
          repository: widget.repository,
        ),
      ),
    );
    if (!mounted || updated == null) { return; }
    if (updated.id != _record.id) {
      _notice('Invoice identifier changed. No changes were applied.');
      return;
    }
    setState(() => _record = updated);
    _notice('Invoice draft updated.');
  }

  Future<void> _preview() async {
    if (_busy) { return; }
    await Sign2DigitalNavigation.push<void>(context,
      MaterialPageRoute<void>(
        builder: (_) => InvoicePreviewScreen(
          invoice: _record,
          repository: widget.repository,
          selectedNavigationIndex: widget.selectedNavigationIndex,
          onNavigationSelected: widget.onNavigationSelected,
        ),
      ),
    );
    if (!mounted) { return; }
    try {
      if(widget.repository is RemoteInvoiceRepository){
        final verified=await widget.repository.invoiceDetail(_record.id);
        if(mounted)setState(()=>_record=verified);
        return;
      }
      final records = await widget.repository.listInvoices();
      for (final record in records) {
        if (record.id == _record.id) {
          setState(() => _record = record);
          break;
        }
      }
    } catch (_) {
      _notice('Unable to refresh invoice details.');
    }
  }

  Widget _actions() {
    // Only the Items tab exposes document output, and only after approval
    // can the customer-facing issued PDF be downloaded.
    if (_tab == 1) {
      return IntrinsicHeight(child: Row(
        key: const Key('invoice-details-actions'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: Sign2DigitalOutlinedButton(
            key: const Key('invoice-details-download'),
            label: 'Download',
            primaryOutline: true,
            enabled: !_busy && _canDeliver,
            onPressed: () => _pdf(share: false))),
          const SizedBox(width: 10),
          Expanded(child: Sign2DigitalOutlinedButton(
            key: const Key('invoice-details-preview'),
            label: 'Preview Invoice',
            primaryOutline: true,
            enabled: !_busy,
            onPressed: _preview)),
        ],
      ));
    }

    // The Details tab controls the workflow. Payments and History have no
    // actions: they display recorded transactions and events only.
    return Column(
      key: const Key('invoice-details-actions'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_record.lifecycleStatus == 'draft') ...[
          Sign2DigitalPrimaryButton(
            key: const Key('invoice-details-edit'),
            label: 'Edit',
            enabled: !_busy,
            onPressed: _edit),
          if (!_record.demoOnly) ...[
            const SizedBox(height: 15),
            Sign2DigitalPrimaryButton(
              key: const Key('invoice-details-approve'),
              label: 'Approve Invoice',
              enabled: !_busy,
              onPressed: _approve),
          ],
        ],
        if (_canDeliver) ...[
          Sign2DigitalOutlinedButton(
            key: const Key('invoice-details-send'),
            label: 'Send',
            primaryOutline: true,
            enabled: !_busy,
            onPressed: () => _pdf(share: true)),
          if (_record.status.canMarkPaid) ...[
            const SizedBox(height: 15),
            Sign2DigitalPrimaryButton(
              key: const Key('invoice-details-mark-paid'),
              label: 'Mark as Paid',
              enabled: !_busy,
              onPressed: _markPaid),
          ],
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.white,
    body: SafeArea(child: Column(children: [
      Sign2DigitalHeader(
        title: 'Invoices',
        onBack: () => Navigator.of(context).maybePop(),
      ),
      Expanded(child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          key: const Key('invoice-details-scroll'),
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 25),
          children: [
            _summary(),
            const SizedBox(height: 20),
            _amount(),
            const SizedBox(height: 20),
            Stack(children: [
              const Positioned(
                left: 0, right: 0, bottom: 0,
                child: Divider(height: 1, thickness: 1,
                  color: AppColors.lightBorder),
              ),
              Sign2DigitalDetailsTabs(
                labels: const ['Details', 'Items', 'Payments', 'History'],
                selectedIndex: _tab,
                onSelected: (value) => setState(() => _tab = value),
              ),
            ]),
            const SizedBox(height: 20),
            if (_tab == 0) _details()
            else if (_tab == 1) _items()
            else if (_tab == 2) _payments()
            else _history(),
            if (_tab < 2) ...[
              const SizedBox(height: 25),
              _actions(),
            ],
          ],
        ),
      ))),
    ])),
  );
}
