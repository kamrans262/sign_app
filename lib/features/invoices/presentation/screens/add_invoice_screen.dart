import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sign2digital_header.dart';
import '../../../../core/widgets/sign2digital_bottom_navigation_bar.dart';
import '../../../../core/widgets/sign2digital_input_field.dart';
import '../../../../core/widgets/sign2digital_selection_field.dart';
import '../../../../core/widgets/sign2digital_outlined_button.dart';
import '../../../../core/widgets/sign2digital_primary_button.dart';
import '../../../labour/data/demo_labour_repository.dart';
import '../../../jobs/domain/job_model.dart';
import '../../domain/invoice_record.dart';

/// Simple draft entry until a dedicated Create Invoice design is provided.
class AddInvoiceScreen extends StatefulWidget {
  const AddInvoiceScreen({
    super.key, this.selectedNavigationIndex = 4, this.onNavigationSelected,
  });
  final int selectedNavigationIndex;
  final ValueChanged<int>? onNavigationSelected;
  @override
  State<AddInvoiceScreen> createState() => _AddInvoiceScreenState();
}

class _AddInvoiceScreenState extends State<AddInvoiceScreen> {
  final _number = TextEditingController();
  final _client = TextEditingController();
  final _amount = TextEditingController();
  JobModel? _job;
  DateTime? _date;
  String? _error;

  @override
  void initState() {
    super.initState();
    _number.text = 'INV-${DateTime.now().microsecondsSinceEpoch}';
  }

  @override
  void dispose() {
    _number.dispose();
    _client.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _selectJob() async {
    final selected = await showModalBottomSheet<JobModel>(
      context: context,
      builder: (sheet) => SafeArea(child: ListView(
        shrinkWrap: true,
        children: [
          const ListTile(title: Text('Select Job / Project')),
          for (final job in LabourDemoJobs.all)
            ListTile(
              key: Key('invoice-pick-job-${job.id}'),
              title: Text(job.title),
              subtitle: Text(job.referenceNumber),
              onTap: () => Navigator.of(sheet).pop(job),
            ),
        ],
      )),
    );
    if (selected != null && mounted) {
      setState(() {
        _job = selected;
        if (_client.text.trim().isEmpty) { _client.text = selected.clientName; }
        _error = null;
      });
    }
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _date ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date != null && mounted) { setState(() => _date = date); }
  }

  void _save() {
    final text = _amount.text.trim();
    final amount = RegExp(r'^\d+(?:[.,]\d{1,2})?$').hasMatch(text)
      ? double.tryParse(text.replaceAll(',', '.')) : null;
    if (_number.text.trim().isEmpty || _job == null ||
        _client.text.trim().isEmpty || _date == null ||
        amount == null || !amount.isFinite ||
        amount <= 0 || amount > 999999999) {
      setState(() => _error =
        'Select a job and date, and enter an invoice number, client and valid amount.');
      return;
    }
    Navigator.of(context).pop(InvoiceRecord(
      id: 'local-invoice-${DateTime.now().microsecondsSinceEpoch}',
      number: _number.text.trim(),
      project: _job!.title,
      jobId: _job!.id,
      clientName: _client.text.trim(),
      amount: amount,
      date: _date!,
      status: InvoiceStatus.draft,
    ));
  }

  void _navigate(int index) {
    if (index == widget.selectedNavigationIndex) { return; }
    Navigator.of(context).pop();
    widget.onNavigationSelected?.call(index);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.white,
    body: SafeArea(bottom: false, child: Column(children: [
      Sign2DigitalHeader(
        title: 'Create Invoice',
        onBack: () => Navigator.of(context).maybePop()),
      Expanded(child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          key: const Key('invoice-create-scroll'),
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 25),
          children: [
            Sign2DigitalInputField(
              key: const Key('invoice-create-number'),
              label: 'Invoice Number',
              hintText: 'INV-2026-0098',
              iconAsset: 'assets/icons/description.svg',
              controller: _number,
            ),
            const SizedBox(height: 20),
            Sign2DigitalSelectionField(
              key: const Key('invoice-create-job'),
              label: 'Job / Project',
              iconAsset: 'assets/icons/description.svg',
              hintText: 'Select a job',
              value: _job?.title,
              onTap: _selectJob,
              trailing: const Icon(Icons.keyboard_arrow_down_rounded,
                color: AppColors.secondaryText),
            ),
            const SizedBox(height: 20),
            Sign2DigitalInputField(
              key: const Key('invoice-create-client'),
              label: 'Client',
              hintText: 'Client name',
              iconAsset: 'assets/icons/user.svg',
              controller: _client,
            ),
            const SizedBox(height: 20),
            Sign2DigitalInputField(
              key: const Key('invoice-create-amount'),
              label: 'Amount',
              hintText: 'CHF 78.80',
              leadingIcon: Icons.monetization_on_outlined,
              iconAsset: 'assets/icons/description.svg',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              controller: _amount,
            ),
            const SizedBox(height: 20),
            Sign2DigitalSelectionField(
              key: const Key('invoice-create-date'),
              label: 'Invoice Date',
              iconAsset: 'assets/icons/calendar-outlined.svg',
              hintText: 'Select date',
              value: _date == null ? null :
                '${_date!.day}/${_date!.month}/${_date!.year}',
              onTap: _selectDate,
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, key: const Key('invoice-create-error'),
                style: const TextStyle(color: Color(0xFFB42318))),
            ],
            const SizedBox(height: 25),
            Row(children: [
              Expanded(child: Sign2DigitalOutlinedButton(
                label: 'Cancel', primaryOutline: true,
                onPressed: () => Navigator.of(context).pop(),
              )),
              const SizedBox(width: 10),
              Expanded(child: Sign2DigitalPrimaryButton(
                key: const Key('invoice-create-save'),
                label: 'Save Draft',
                onPressed: _save,
              )),
            ]),
          ],
        ),
      ))),
    ])),
    bottomNavigationBar: Sign2DigitalBottomNavigationBar(
      selectedIndex: widget.selectedNavigationIndex,
      onSelected: _navigate,
    ),
  );
}
