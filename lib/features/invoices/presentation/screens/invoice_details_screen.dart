import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sign2digital_header.dart';
import '../../../../core/widgets/sign2digital_information_table.dart';
import '../../../../core/widgets/sign2digital_primary_button.dart';
import '../../../clients/presentation/widgets/sign2digital_status_badge.dart';
import '../../data/demo_invoice_repository.dart';
import '../../domain/invoice_record.dart';
import '../widgets/mark_invoice_paid_dialog.dart';

class InvoiceDetailsScreen extends StatefulWidget {
  const InvoiceDetailsScreen({
    super.key, required this.invoice, required this.repository,
  });

  final InvoiceRecord invoice;
  final InvoiceRepository repository;

  @override
  State<InvoiceDetailsScreen> createState() => _InvoiceDetailsScreenState();
}

class _InvoiceDetailsScreenState extends State<InvoiceDetailsScreen> {
  late InvoiceRecord _invoice;

  @override
  void initState() {
    super.initState();
    _invoice = widget.invoice;
  }

  static String _date(DateTime day) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[day.month - 1]} ${day.day}, ${day.year}';
  }

  Future<void> _markPaid() async {
    if (!_invoice.status.canMarkPaid) { return; }
    final updated = await MarkInvoicePaidDialog.show(
      context, invoice: _invoice, repository: widget.repository);
    if (!mounted || updated == null) { return; }
    setState(() => _invoice = updated);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Invoice marked paid in demo records.')));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.white,
    body: SafeArea(child: Column(children: [
      Sign2DigitalHeader(
        title: 'Invoice Details',
        onBack: () => Navigator.of(context).maybePop(),
      ),
      Expanded(child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          key: const Key('invoice-details-scroll'),
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 25),
          children: [
            Text(_invoice.number, key: const Key('invoice-details-number'),
              style: const TextStyle(fontFamily: 'Inter',
                fontSize: 22, fontWeight: FontWeight.w600,
                color: AppColors.dark)),
            const SizedBox(height: 10),
            Align(alignment: Alignment.centerLeft,
              child: Sign2DigitalStatusBadge(status: _invoice.status.label)),
            const SizedBox(height: 20),
            Sign2DigitalInformationTable(
              key: const Key('invoice-details-table'),
              rows: [
                Sign2DigitalInformationRow('Invoice', _invoice.number),
                Sign2DigitalInformationRow('Project', _invoice.project),
                Sign2DigitalInformationRow('Client', _invoice.clientName),
                Sign2DigitalInformationRow('Date', _date(_invoice.date)),
                Sign2DigitalInformationRow('Amount',
                  _invoice.formattedAmount),
                Sign2DigitalInformationRow('Status',
                  _invoice.status.label, isStatus: true),
                if (_invoice.manuallyPaidAt != null)
                  Sign2DigitalInformationRow('Manually paid',
                    _date(_invoice.manuallyPaidAt!)),
              ],
            ),
            if (_invoice.status.canMarkPaid) ...[
              const SizedBox(height: 25),
              Sign2DigitalPrimaryButton(
                key: const Key('invoice-details-mark-paid'),
                label: 'Mark as Paid',
                onPressed: _markPaid,
              ),
            ],
          ],
        ),
      ))),
    ])),
  );
}
