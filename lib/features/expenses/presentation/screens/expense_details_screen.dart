import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sign2digital_header.dart';
import '../../../../core/widgets/sign2digital_outlined_container.dart';
import '../../../clients/presentation/widgets/sign2digital_status_badge.dart';
import '../../domain/expense_record.dart';

/// Read-only details for the exact selected expense; no fake reimbursements.
class ExpenseDetailsScreen extends StatelessWidget {
  const ExpenseDetailsScreen({super.key, required this.expense});
  final ExpenseRecord expense;

  Widget _field(String title, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: Text(title, style: const TextStyle(
        fontFamily: 'Inter', fontSize: 14, color: AppColors.placeholder))),
      const SizedBox(width: 12),
      Expanded(child: Text(value, textAlign: TextAlign.right,
        style: const TextStyle(fontFamily: 'Inter', fontSize: 14,
          color: AppColors.dark, fontWeight: FontWeight.w500))),
    ]),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.white,
    body: SafeArea(bottom: false, child: Column(children: [
      Sign2DigitalHeader(
        title: 'Expense Details',
        onBack: () => Navigator.of(context).pop(),
      ),
      Expanded(child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 25),
          children: [
            Text(expense.title, key: const Key('expense-detail-title'),
              style: const TextStyle(
                fontFamily: 'Inter', fontSize: 20,
                fontWeight: FontWeight.w600, color: AppColors.dark)),
            const SizedBox(height: 15),
            Sign2DigitalOutlinedContainer(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                _field('Category', expense.category.label),
                _field('Job', expense.job),
                _field('Report', expense.report),
                _field('Amount', expense.formattedAmount),
                _field('Date', _date(expense.date)),
                if (expense.description.isNotEmpty)
                  _field('Description', expense.description),
                if (expense.tags.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    for (final tag in expense.tags) Chip(label: Text(tag)),
                  ]),
                ],
                if (expense.photos.isNotEmpty) ...[
                  const SizedBox(height: 15),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (var i = 0; i < expense.photos.length; i++)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(expense.photos[i].bytes,
                          key: Key('expense-detail-photo-$i'),
                          width: 112, height: 84, fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                            const Icon(Icons.broken_image_outlined)),
                      ),
                  ]),
                ],
                const SizedBox(height: 12),
                Align(alignment: Alignment.centerRight,
                  child: Sign2DigitalStatusBadge(
                    status: expense.status.label)),
              ]),
            ),
            if (expense.demoOnly) ...[
              const SizedBox(height: 15),
              const Text('Demo/local expense — not submitted or reimbursed.',
                style: TextStyle(fontFamily: 'Inter',
                  fontSize: 12, color: AppColors.secondaryText)),
            ],
          ]),
      ))),
    ])),
  );

  static String _date(DateTime value) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[value.month-1]} ${value.day}, ${value.year}';
  }
}
