import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sign2digital_header.dart';
import '../../../../core/widgets/sign2digital_information_table.dart';
import '../../../../core/widgets/sign2digital_outlined_button.dart';
import '../../../../core/widgets/sign2digital_outlined_container.dart';
import '../../../../core/widgets/sign2digital_primary_button.dart';
import '../../../clients/presentation/widgets/sign2digital_details_tabs.dart';
import '../../../clients/presentation/widgets/sign2digital_status_badge.dart';
import '../../../documents/presentation/widgets/sign2digital_document_history.dart';
import '../../../jobs/data/local_job_photo_source.dart';
import '../../../jobs/presentation/widgets/sign2digital_photo_preview.dart';
import '../../../labour/data/demo_labour_repository.dart';
import '../../domain/deposit_record.dart';
import 'add_deposit_screen.dart';

typedef DepositReceiptShare = Future<void> Function(
    LocalJobPhotoSelection receipt);
typedef DepositReceiptDownload = Future<bool> Function(
    LocalJobPhotoSelection receipt);

/// The Expense/Labour Details family, with one deposit record throughout.
/// Refund and deletion never mutate the repository before confirmation.
class DepositDetailsScreen extends StatefulWidget {
  const DepositDetailsScreen({
    super.key,
    required this.deposit,
    required this.repository,
    this.onReceiptShare,
    this.onReceiptDownload,
  });

  final DepositRecord deposit;
  final DepositRepository repository;
  final DepositReceiptShare? onReceiptShare;
  final DepositReceiptDownload? onReceiptDownload;

  @override
  State<DepositDetailsScreen> createState() => _DepositDetailsScreenState();
}

class _DepositDetailsScreenState extends State<DepositDetailsScreen> {
  late DepositRecord _record;
  int _tab = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _record = widget.deposit;
  }

  static const _months = [
    'January','February','March','April','May','June',
    'July','August','September','October','November','December',
  ];

  static String _date(DateTime date) =>
      '${date.day} ${_months[date.month - 1]} ${date.year}';

  static String _timestamp(DateTime when) {
    final date = when.toLocal();
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    return '${_date(date)}, $hour:'
        '${date.minute.toString().padLeft(2, '0')} '
        '${date.hour < 12 ? 'AM' : 'PM'}';
  }

  void _notice(String message) {
    if (!mounted) { return; }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _copyJob() async {
    await Clipboard.setData(ClipboardData(text: _record.title));
    if (mounted) { _notice('Job copied to clipboard.'); }
  }

  Widget _summary() => Row(
    key: const Key('deposit-detail-summary'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const CircleAvatar(
        radius: 20, backgroundColor: Color(0xFFE3ECF0),
        child: Icon(Icons.account_balance_outlined,
          size: 24, color: AppColors.primary)),
      const SizedBox(width: 10),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_record.title,
            key: const Key('deposit-detail-title'),
            maxLines: 2, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontFamily: 'Inter', fontSize: 18,
              fontWeight: FontWeight.w600, color: AppColors.dark)),
          const SizedBox(height: 5),
          Text('Client: ${_record.clientName}',
            maxLines: 2, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontFamily: 'Inter', fontSize: 14,
              color: AppColors.placeholder)),
          const SizedBox(height: 3),
          Text(_date(_record.date),
            style: const TextStyle(fontFamily: 'Inter', fontSize: 14,
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
        key: const Key('deposit-detail-amount'),
        style: const TextStyle(fontFamily: 'Inter',
          fontWeight: FontWeight.w700, fontSize: 22, color: AppColors.dark)),
      const SizedBox(height: 5),
      Text(_timestamp(_record.receivedAt ?? _record.date),
        style: const TextStyle(fontFamily: 'Inter', fontSize: 14,
          color: AppColors.placeholder)),
    ],
  );

  Widget _details() => Sign2DigitalInformationTable(
    key: const Key('deposit-details-table'),
    rows: [
      Sign2DigitalInformationRow('Job', _record.title, onCopy: _copyJob),
      Sign2DigitalInformationRow('Date', _date(_record.date)),
      Sign2DigitalInformationRow('Client', _record.clientName),
      Sign2DigitalInformationRow('Amount', _record.formattedAmount),
      Sign2DigitalInformationRow('Payment Method',
        _record.paymentMethod.trim().isEmpty
            ? 'Not recorded' : _record.paymentMethod),
      Sign2DigitalInformationRow('Reference Number',
        _record.referenceNumber.trim().isEmpty
            ? 'Not recorded' : _record.referenceNumber),
      Sign2DigitalInformationRow('Status', _record.status.label,
        isStatus: true),
      if (_record.receivedBy?.trim().isNotEmpty == true)
        Sign2DigitalInformationRow('Received By', _record.receivedBy!),
      if (_record.receivedAt != null)
        Sign2DigitalInformationRow('Received Date',
          _timestamp(_record.receivedAt!)),
      if (_record.refundedAt != null)
        Sign2DigitalInformationRow('Refunded Date',
          _timestamp(_record.refundedAt!)),
    ],
  );

  Future<void> _preview(int index) async {
    final receipt = _record.photos[index];
    await showDialog<void>(
      context: context,
      builder: (dialog) => Dialog(
        child: Stack(children: [
          InteractiveViewer(
            child: Image.memory(receipt.bytes,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) =>
                  const Icon(Icons.broken_image_outlined)),
          ),
          Positioned(
            top: 0, right: 0,
            child: IconButton(
              key: const Key('deposit-receipt-close'),
              tooltip: 'Close receipt',
              onPressed: () => Navigator.of(dialog).pop(),
              icon: const Icon(Icons.close),
            ),
          ),
        ]),
      ),
    );
  }

  Future<void> _receiptAction(int index, {required bool share}) async {
    if (_busy) { return; }
    final receipt = _record.photos[index];
    setState(() => _busy = true);
    try {
      if (share) {
        if (widget.onReceiptShare != null) {
          await widget.onReceiptShare!(receipt);
        } else {
          final pdf = pw.Document();
          pdf.addPage(pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (_) => pw.Center(child: pw.Image(
              pw.MemoryImage(receipt.bytes), fit: pw.BoxFit.contain)),
          ));
          await Printing.sharePdf(bytes: await pdf.save(),
            filename: 'deposit_receipt.pdf');
        }
      } else {
        if (widget.onReceiptDownload != null) {
          if (!await widget.onReceiptDownload!(receipt)) {
            throw StateError('Receipt saving was cancelled.');
          }
        } else {
          final filename = receipt.name.replaceAll(
            RegExp(r'[^a-zA-Z0-9_.-]'), '_');
          final result = await FilePicker.saveFile(
            dialogTitle: 'Save receipt', fileName: filename,
            type: FileType.custom,
            allowedExtensions: [filename.split('.').last.toLowerCase()],
            bytes: receipt.bytes);
          if (result == null) { return; }
        }
        _notice('Receipt saved.');
      }
    } catch (_) {
      _notice('Unable to ${share ? 'share' : 'save'} receipt.');
    } finally {
      if (mounted) { setState(() => _busy = false); }
    }
  }

  Widget _receipts() {
    final photos = _record.photos;
    if (photos.isEmpty) {
      return Sign2DigitalOutlinedContainer(
        child: InkWell(
          key: const Key('deposit-receipts-empty'),
          onTap: _busy ? null : _edit,
          child: const SizedBox(height: 145,
            child: Center(child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_upload_outlined,
                  color: AppColors.primary, size: 28),
                SizedBox(height: 10),
                Text('No receipt attached',
                  style: TextStyle(fontFamily: 'Inter',
                    fontSize: 14, color: AppColors.placeholder)),
                Text('Edit the deposit to add a photo',
                  style: TextStyle(fontFamily: 'Inter',
                    fontSize: 12, color: AppColors.placeholder)),
              ],
            )),
          ),
        ),
      );
    }
    return Column(
      key: const Key('deposit-receipts-grid'),
      children: [
        for (var i = 0; i < photos.length; i++) ...[
          Sign2DigitalOutlinedContainer(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(children: [
                InkWell(
                  key: Key('deposit-receipt-$i'),
                  onTap: () => _preview(i),
                  child: Sign2DigitalPhotoPreview(
                    bytes: photos[i].bytes, showDemo: false,
                    showRemove: false, onRemove: () {}),
                ),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: Sign2DigitalOutlinedButton(
                    key: Key('deposit-receipt-share-$i'),
                    label: 'Share', enabled: !_busy,
                    primaryOutline: true,
                    onPressed: () => _receiptAction(i, share: true))),
                  const SizedBox(width: 10),
                  Expanded(child: Sign2DigitalOutlinedButton(
                    key: Key('deposit-receipt-download-$i'),
                    label: 'Download', enabled: !_busy,
                    primaryOutline: true,
                    onPressed: () => _receiptAction(i, share: false))),
                ]),
              ]),
            ),
          ),
          const SizedBox(height: 15),
        ],
        TextButton.icon(
          key: const Key('deposit-receipts-edit'),
          onPressed: _busy ? null : _edit,
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Add or remove photos'),
        ),
      ],
    );
  }

  Widget _history() {
    final events = _record.history.toList()
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    if (events.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Text('No recorded deposit history is available.',
          key: Key('deposit-history-empty'),
          style: TextStyle(fontFamily: 'Inter', fontSize: 14,
            color: AppColors.placeholder)),
      );
    }
    return Column(
      key: const Key('deposit-history-list'),
      children: [
        for (final event in events) ...[
          Sign2DigitalTrackingRow(
            key: Key('deposit-history-${event.id}'),
            title: event.title, historyStyle: true,
            historyIcon: Icons.history_rounded,
            dateText: _timestamp(event.occurredAt),
            actorText: event.description,
          ),
          const SizedBox(height: 20),
        ],
      ],
    );
  }

  Future<void> _delete() async {
    if (_busy) { return; }
    final yes = await showDialog<bool>(
      context: context, builder: (dialog) => AlertDialog(
        title: const Text('Delete deposit?'),
        content: Text('Delete ${_record.formattedAmount} for ${_record.title}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: const Text('Cancel')),
          TextButton(
            key: const Key('deposit-confirm-delete'),
            onPressed: () => Navigator.of(dialog).pop(true),
            child: const Text('Delete')),
        ],
      ),
    );
    if (yes != true || !mounted) { return; }
    setState(() => _busy = true);
    try {
      await widget.repository.deleteDeposit(_record.id);
      if (!mounted) { return; }
      Navigator.of(context).pop(true);
    } catch (_) {
      _notice('Unable to delete this deposit.');
    } finally {
      if (mounted) { setState(() => _busy = false); }
    }
  }

  Future<void> _refund() async {
    if (_busy || _record.status != DepositStatus.received) { return; }
    final yes = await showDialog<bool>(
      context: context, builder: (dialog) => AlertDialog(
        title: const Text('Refund deposit?'),
        content: Text('Mark ${_record.formattedAmount} as refunded locally? '
          'This will not initiate a bank refund.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: const Text('Cancel')),
          TextButton(
            key: const Key('deposit-confirm-refund'),
            onPressed: () => Navigator.of(dialog).pop(true),
            child: const Text('Refund')),
        ],
      ),
    );
    if (yes != true || !mounted) { return; }
    setState(() => _busy = true);
    try {
      final updated = await widget.repository.refundDeposit(_record.id);
      if (updated.id != _record.id ||
          updated.status != DepositStatus.refunded) {
        throw StateError('Refund was not confirmed.');
      }
      if (!mounted) { return; }
      setState(() => _record = updated);
      _notice('Deposit marked refunded locally.');
    } catch (_) {
      _notice('Refund status was not changed. Please try again.');
    } finally {
      if (mounted) { setState(() => _busy = false); }
    }
  }

  Future<void> _edit() async {
    if (_busy || _record.status == DepositStatus.refunded) { return; }
    final updated = await Navigator.of(context).push<DepositRecord>(
      MaterialPageRoute<DepositRecord>(
        builder: (_) => AddDepositScreen(
          initialDeposit: _record,
          jobs: LabourDemoJobs.all,
        ),
      ),
    );
    if (updated == null || !mounted) { return; }
    if (updated.id != _record.id) {
      _notice('Deposit ID changed; edit was not saved.');
      return;
    }
    setState(() => _busy = true);
    try {
      final saved = await widget.repository.updateDeposit(updated);
      if (saved.id != _record.id) {
        throw StateError('Updated deposit did not match.');
      }
      if (!mounted) { return; }
      setState(() => _record = saved);
      _notice('Deposit updated locally.');
    } catch (_) {
      _notice('Deposit update failed.');
    } finally {
      if (mounted) { setState(() => _busy = false); }
    }
  }

  Widget _actions() => Column(
    key: const Key('deposit-detail-actions'),
    children: [
      Row(children: [
        Expanded(child: Sign2DigitalOutlinedButton(
          key: const Key('deposit-detail-delete'),
          label: 'Delete', enabled: !_busy, primaryOutline: true,
          onPressed: _delete)),
        const SizedBox(width: 10),
        Expanded(child: Sign2DigitalOutlinedButton(
          key: const Key('deposit-detail-refund'),
          label: 'Refund', primaryOutline: true,
          enabled: !_busy && _record.status == DepositStatus.received,
          onPressed: _refund)),
      ]),
      const SizedBox(height: 15),
      FractionallySizedBox(
        widthFactor: .5,
        child: Sign2DigitalPrimaryButton(
          key: const Key('deposit-detail-edit'),
          label: 'Edit',
          enabled: !_busy && _record.status != DepositStatus.refunded,
          onPressed: _edit)),
    ],
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.white,
    body: SafeArea(child: Column(children: [
      Sign2DigitalHeader(
        title: 'Deposits',
        onBack: () => Navigator.of(context).maybePop(),
      ),
      Expanded(child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          key: const Key('deposit-details-scroll'),
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          children: [
            _summary(),
            const SizedBox(height: 20),
            _amount(),
            const SizedBox(height: 20),
            Stack(children: [
              const Positioned(left: 0, right: 0, bottom: 0,
                child: Divider(height: 1, thickness: 1,
                  color: AppColors.lightBorder)),
              Sign2DigitalDetailsTabs(
                labels: const ['Details', 'Receipt', 'History'],
                selectedIndex: _tab,
                onSelected: (index) => setState(() => _tab = index),
              ),
            ]),
            const SizedBox(height: 20),
            if (_tab == 0) _details()
            else if (_tab == 1) _receipts()
            else _history(),
            const SizedBox(height: 25),
            _actions(),
          ],
        ),
      ))),
    ])),
  );
}
