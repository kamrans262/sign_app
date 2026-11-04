import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sign2digital_header.dart';
import '../../../../core/widgets/sign2digital_information_table.dart';
import '../../../../core/widgets/sign2digital_outlined_container.dart';
import '../../../../core/widgets/sign2digital_outlined_button.dart';
import '../../../../core/widgets/sign2digital_primary_button.dart';
import '../../../clients/presentation/widgets/sign2digital_details_tabs.dart';
import '../../../clients/presentation/widgets/sign2digital_status_badge.dart';
import '../../../documents/presentation/widgets/sign2digital_document_history.dart';
import '../../data/demo_expense_repository.dart';
import '../../data/remote_expense_repository.dart';
import '../../../../core/services/active_company_session.dart';
import '../../domain/expense_record.dart';
import '../widgets/sign2digital_expense_category_icon.dart';
import 'add_expense_screen.dart';
import 'receipt_screen.dart';
import '../../../jobs/data/local_job_photo_source.dart';

typedef ExpenseDetailsLoader = Future<ExpenseRecord?> Function(String expenseId);
typedef ExpenseReimbursementAction = Future<ExpenseRecord> Function(ExpenseRecord expense);

/// Details for one selected expense; no fabricated approval/reimbursement.
class ExpenseDetailsScreen extends StatefulWidget {
  const ExpenseDetailsScreen({
    super.key,
    required this.expense,
    this.repository,
    this.loadExpense,
    this.onRequestReimbursement,
    this.receiptPhotoSource,
    this.onReceiptShare,
    this.onReceiptDownload,
    this.onNavigationSelected,
    this.selectedNavigationIndex = 4,
  });

  final ExpenseRecord expense;
  final ExpenseRepository? repository;
  final ExpenseDetailsLoader? loadExpense;
  final ExpenseReimbursementAction? onRequestReimbursement;
  final JobPhotoSource? receiptPhotoSource;
  final ReceiptShare? onReceiptShare;
  final ReceiptDownload? onReceiptDownload;
  final ValueChanged<int>? onNavigationSelected;
  final int selectedNavigationIndex;

  @override
  State<ExpenseDetailsScreen> createState() => _ExpenseDetailsScreenState();
}

class _ExpenseDetailsScreenState extends State<ExpenseDetailsScreen> {
  late ExpenseRecord _record;
  late final ExpenseRepository _repository;
  int _tab = 0;
  bool _loading = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _record = widget.expense;
    _repository = widget.repository ?? (ActiveCompanySession.companyId == null
        ? const DemoExpenseRepository() : RemoteExpenseRepository.shared);
    if (widget.loadExpense != null || _repository is RemoteExpenseRepository) _reload();
  }

  @override
  void didUpdateWidget(covariant ExpenseDetailsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expense != widget.expense) {
      _record = widget.expense;
      _tab = 0;
      if (widget.loadExpense != null ||
          _repository is RemoteExpenseRepository) {
        _reload();
      }
    }
  }

  Future<void> _reload() async {
    final load = widget.loadExpense ?? (_repository is RemoteExpenseRepository
        ? _repository.getExpense : null);
    if (load == null) return;
    setState(() { _loading = true; _error = null; });
    try {
      final updated = await load(_record.id);
      if (!mounted) return;
      if (updated == null || updated.id != _record.id) {
        setState(() {
          _loading = false;
          _error = 'Expense could not be found.';
        });
        return;
      }
      setState(() { _record = updated; _loading = false; });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Unable to load expense details.';
        });
      }
    }
  }

  void _notice(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  static String _shortDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  static String _dateTime(DateTime date) {
    final local = date.toLocal();
    const months = ['January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'];
    final datePart = '${local.day} ${months[local.month - 1]} ${local.year}';
    // Date-only expense records do not imply an actual midnight purchase.
    if (local.hour == 0 && local.minute == 0) return datePart;
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    return '$datePart  $hour:${local.minute.toString().padLeft(2, '0')} '
      '${local.hour >= 12 ? 'PM' : 'AM'}';
  }

  Widget _summary() => Row(
    key: const Key('expense-detail-summary'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Sign2DigitalExpenseCategoryIcon(
          category: _record.category, detailStyle: true)),

      const SizedBox(width: 15),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_record.title,
            key: const Key('expense-detail-title'),
            style: const TextStyle(
              fontFamily: 'Inter', fontSize: 18,
              fontWeight: FontWeight.w600, color: AppColors.dark)),
          const SizedBox(height: 5),
          Text([_record.job, _record.report]
              .where((value) => value.trim().isNotEmpty).join(', '),
            style: const TextStyle(
              fontFamily: 'Inter', fontSize: 14,
              fontWeight: FontWeight.w500, color: AppColors.placeholder),
            softWrap: true),
        ],
      )),
      const SizedBox(width: 8),
      Align(alignment: Alignment.centerRight,
        child: Sign2DigitalStatusBadge(status: _record.status.label)),
    ],
  );

  Widget _amount() => Column(
    key: const Key('expense-detail-amount-section'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(_record.formattedAmount,
        style: const TextStyle(fontFamily: 'Inter',
          fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.dark)),
      const SizedBox(height: 5),
      Text(_dateTime(_record.date),
        style: const TextStyle(fontFamily: 'Inter', fontSize: 14,
          color: AppColors.placeholder, fontWeight: FontWeight.w500)),
    ],
  );

  Widget _details() {
    final r = _record;
    final rows = <Sign2DigitalInformationRow>[
      Sign2DigitalInformationRow('Expense Type', r.category.label),
      Sign2DigitalInformationRow('Amount', r.formattedAmount),
      Sign2DigitalInformationRow('Job', r.job),
      if (r.clientName?.trim().isNotEmpty == true)
        Sign2DigitalInformationRow('Client:', r.clientName!),
      if (r.approvedBy?.trim().isNotEmpty == true)
        Sign2DigitalInformationRow('Approved By:', r.approvedBy!),
      if (r.approvedAt != null)
        Sign2DigitalInformationRow('Approved Date:', _shortDate(r.approvedAt!)),
      if (r.updatedAt != null)
        Sign2DigitalInformationRow('Last Update:', _shortDate(r.updatedAt!)),
      Sign2DigitalInformationRow('Status:', r.status.label, isStatus: true),
    ];
    return Sign2DigitalInformationTable(
      key: const Key('expense-information-table'), rows: rows);
  }

  Future<void> _openReceipt(int index) async {
    if (_busy) return;
    setState(() => _tab = 1);
    await Navigator.of(context).push<void>(MaterialPageRoute<void>(
      builder: (_) => ReceiptScreen(
        expense: _record,
        repository: _repository,
        canEdit: _record.demoOnly || _record.status == ExpenseStatus.toReview,
        initialIndex: index,
        photoSource: widget.receiptPhotoSource,
        onShare: widget.onReceiptShare,
        onDownload: widget.onReceiptDownload,
        selectedNavigationIndex: widget.selectedNavigationIndex,
        onNavigationSelected: widget.onNavigationSelected,
        onExpenseChanged: (value) {
          if (mounted && value.id == _record.id) {
            setState(() => _record = value);
          }
        },
      ),
    ));
    if (mounted && _repository is RemoteExpenseRepository) await _reload();
  }

  Widget _receipts() {
    final photos = _record.photos;
    if (photos.isEmpty) {
      return Sign2DigitalOutlinedContainer(
        child: InkWell(
          key: const Key('expense-add-receipt'),
          onTap: _busy ? null : _edit,
          child: const SizedBox(
            height: 145,
            child: Center(child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
              Icon(Icons.cloud_upload_outlined,
                color: AppColors.primary, size: 28),
              SizedBox(height: 8),
              Text('Add Photo', style: TextStyle(
                fontFamily: 'Inter', fontSize: 16, color: AppColors.dark)),
              SizedBox(height: 5),
              Text('Add receipt photos by editing this expense',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Inter', fontSize: 12,
                  color: AppColors.placeholder)),
            ])),
          ),
        ),
      );
    }
    return Sign2DigitalOutlinedContainer(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: LayoutBuilder(builder: (context, constraints) =>
          GridView.builder(
            key: const Key('expense-receipt-grid'),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: constraints.maxWidth < 250 ? 1 : 2,
              mainAxisSpacing: 10, crossAxisSpacing: 10,
              childAspectRatio: 188 / 118),
            itemCount: photos.length,
            itemBuilder: (context, index) => InkWell(
              key: Key('expense-receipt-$index'),
              onTap: () => _openReceipt(index),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.memory(photos[index].bytes,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const Center(
                    child: Icon(Icons.broken_image_outlined))),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _history() {
    final events = _record.history.toList()
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    if (events.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Text('No recorded expense history is available.',
          key: Key('expense-history-empty'),
          style: TextStyle(fontFamily: 'Inter',
            fontSize: 14, color: AppColors.placeholder)),
      );
    }
    return Column(
      key: const Key('expense-history-list'),
      children: [
        for (final event in events) ...[
          Sign2DigitalTrackingRow(
            key: Key('expense-history-event-${event.id}'),
            historyStyle: true,
            historyIcon: Icons.description_outlined,
            title: event.title,
            dateText: _dateTime(event.occurredAt),
            actorText: [
              if (event.description?.trim().isNotEmpty == true)
                event.description!.trim(),
              if (event.actorName?.trim().isNotEmpty == true)
                'By ${event.actorName!.trim()}',
            ].join(' • '),
          ),
          const SizedBox(height: 20),
        ],
      ],
    );
  }

  Future<void> _edit() async {
    if (_busy) return;
    final updated = await Navigator.of(context).push<ExpenseRecord>(
      MaterialPageRoute<ExpenseRecord>(
        builder: (_) => AddExpenseScreen(initialExpense: _record)),
    );
    if (updated == null || !mounted) return;
    if (updated.id != _record.id) {
      _notice('Expense identifier changed unexpectedly. Nothing was saved.');
      return;
    }
    setState(() => _busy = true);
    try {
      await _repository.updateExpense(updated);
      if (!mounted) return;
      if (_repository is RemoteExpenseRepository) {
        await _reload();
      } else {
        setState(() => _record = updated);
      }
      _notice('Expense changes saved.');
    } catch (_) {
      _notice('Unable to save changes to this expense.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reimburse() async {
    if (_busy) return;
    if (_record.status != ExpenseStatus.approved ||
        _record.reimbursementRequested) {
      _notice('This expense is not eligible for another reimbursement request.');
      return;
    }
    final submit = widget.onRequestReimbursement ??
        (_repository is RemoteExpenseRepository
            ? _repository.requestReimbursement : null);
    if (submit == null) {
      _notice('Reimbursement service is not connected yet.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Request reimbursement?'),
        content: Text('Submit ${_record.formattedAmount} for reimbursement?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialog).pop(false),
            child: const Text('Cancel')),
          TextButton(key: const Key('expense-confirm-reimburse'),
            onPressed: () => Navigator.of(dialog).pop(true),
            child: const Text('Request')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final response = await submit(_record);
      if (!mounted) return;
      if (response.id != _record.id) {
        throw StateError('Reimbursement response did not match the expense.');
      }
      setState(() => _record = response);
      _notice('Reimbursement request processed by the connected service.');
    } catch (_) {
      _notice('Reimbursement request failed. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _actions() => LayoutBuilder(
    builder: (context, constraints) {
      final edit = Sign2DigitalOutlinedButton(
        key: const Key('expense-edit'),
        label: 'Edit', primaryOutline: true,
        enabled: !_busy && (_record.demoOnly ||
            _record.status == ExpenseStatus.toReview), onPressed: _edit,
      );
      final reimburse = Sign2DigitalPrimaryButton(
        key: const Key('expense-request-reimburse'),
        label: 'Request Reimburse',
        loading: _busy,
        enabled: !_busy && _record.status == ExpenseStatus.approved &&
            !_record.reimbursementRequested,
        onPressed: _reimburse,
      );
      return KeyedSubtree(
        key: const Key('expense-detail-actions'),
        child: constraints.maxWidth < 345
            ? Column(crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [edit, const SizedBox(height: 10), reimburse])
            : Row(children: [
                Expanded(child: edit), const SizedBox(width: 10),
                Expanded(child: reimburse),
              ]),
      );
    },
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.white,
    body: SafeArea(bottom: false, child: Column(children: [
      Sign2DigitalHeader(title: 'Expenses',
        onBack: () => Navigator.of(context).maybePop()),
      Expanded(child: _loading
            ? const Center(child: CircularProgressIndicator(
                key: Key('expense-details-loading')))
            : _error != null
                ? Center(child: TextButton(
                    key: const Key('expense-details-retry'),
                    onPressed: _reload,
                    child: Text('$_error Retry')))
                : SingleChildScrollView(
                    key: const Key('expense-details-scroll'),
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 25),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _summary(),
                        const SizedBox(height: 20),
                        _amount(),
                        const SizedBox(height: 20),
                        Stack(children: [
                          const Positioned(bottom: 0, left: 0, right: 0,
                            child: Divider(height: 1, thickness: 1,
                              color: AppColors.lightBorder)),
                          Sign2DigitalDetailsTabs(
                            labels: const ['Details', 'Receipt', 'History'],
                            selectedIndex: _tab,
                            onSelected: (index) {
                              if (index == 1) {
                                _openReceipt(0);
                              } else {
                                setState(() => _tab = index);
                              }
                            }),
                        ]),
                        const SizedBox(height: 20),
                        if (_tab == 0) _details()
                        else if (_tab == 1) _receipts()
                        else _history(),
                        if (_record.demoOnly) ...[
                          const SizedBox(height: 12),
                          const Text('UI demo/local expense — not a verified approval or reimbursement.',
                            style: TextStyle(fontFamily: 'Inter',
                              fontSize: 12, color: AppColors.primary)),
                        ],
                        const SizedBox(height: 25),
                        _actions(),
                      ]),
                  ),
      ),
    ])),
  );
}
