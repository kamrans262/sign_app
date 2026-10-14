import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sign2digital_modal_surface.dart';
import '../../../../core/widgets/sign2digital_outlined_button.dart';
import '../../../../core/widgets/sign2digital_primary_button.dart';
import '../../domain/invoice_record.dart';
import '../../data/demo_invoice_repository.dart';

/// Confirmation is separate from invoice-row navigation and never changes
/// an invoice until the repository successfully accepts the operation.
class MarkInvoicePaidDialog extends StatefulWidget {
  const MarkInvoicePaidDialog({
    super.key, required this.invoice, required this.repository,
  });
  final InvoiceRecord invoice;
  final InvoiceRepository repository;

  static Future<InvoiceRecord?> show(BuildContext context, {
    required InvoiceRecord invoice,
    required InvoiceRepository repository,
  }) => showDialog<InvoiceRecord>(
    context: context,
    barrierDismissible: false,
    barrierColor: const Color(0x80000000),
    builder: (_) => MarkInvoicePaidDialog(
      invoice: invoice, repository: repository),
  );

  @override
  State<MarkInvoicePaidDialog> createState() => _MarkInvoicePaidDialogState();
}

class _MarkInvoicePaidDialogState extends State<MarkInvoicePaidDialog> {
  bool _busy = false;
  String? _error;

  Future<void> _confirm() async {
    if (_busy) { return; }
    setState(() { _busy = true; _error = null; });
    try {
      final updated = await widget.repository.markAsPaid(widget.invoice.id);
      if (!mounted) { return; }
      if (updated.id != widget.invoice.id ||
          updated.status != InvoiceStatus.paid) {
        throw StateError('Invoice payment update was not confirmed.');
      }
      Navigator.of(context).pop(updated);
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Could not mark this invoice as paid. Please try again.';
        });
      }
    } finally {
      if (mounted) { setState(() => _busy = false); }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Sign2DigitalModalSurface(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircleAvatar(
            radius: 25,
            backgroundColor: Color(0xFFE3ECF0),
            child: Icon(Icons.fact_check_outlined,
              size: 26, color: AppColors.primary),
          ),
          const SizedBox(height: 15),
          const Text('Mark as Paid',
            key: Key('invoice-paid-confirm-heading'),
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Inter', fontSize: 18,
              fontWeight: FontWeight.w600, color: AppColors.dark,
              decoration: TextDecoration.none)),
          const SizedBox(height: 5),
          const Text('This will record the invoice as manually paid',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Inter', fontSize: 14,
              fontWeight: FontWeight.w500, color: AppColors.placeholder,
              decoration: TextDecoration.none)),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, key: const Key('invoice-paid-error'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'Inter',
                fontSize: 12, color: Color(0xFFB42318),
                decoration: TextDecoration.none)),
          ],
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: Sign2DigitalOutlinedButton(
              key: const Key('invoice-paid-cancel'),
              label: 'Cancel',
              enabled: !_busy,
              primaryOutline: true,
              onPressed: () => Navigator.of(context).pop(),
            )),
            const SizedBox(width: 15),
            Expanded(child: Sign2DigitalPrimaryButton(
              key: const Key('invoice-paid-confirm'),
              label: 'Mark as Paid',
              loading: _busy,
              onPressed: _confirm,
            )),
          ]),
        ],
      ),
    ),
  );
}
