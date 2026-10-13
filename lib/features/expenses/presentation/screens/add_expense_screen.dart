import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sign2digital_primary_button.dart';
import '../../domain/expense_record.dart';

/// Add Expense is currently a local UI draft, not a submitted reimbursement.
class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key});
  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _job = TextEditingController();
  final _report = TextEditingController();
  final _amount = TextEditingController();
  final _description = TextEditingController();
  ExpenseCategory _category = ExpenseCategory.fuel;
  String? _error;

  @override
  void dispose() {
    _job.dispose();
    _report.dispose();
    _amount.dispose();
    _description.dispose();
    super.dispose();
  }

  void _save() {
    final value = double.tryParse(_amount.text.trim().replaceAll(',', '.'));
    if (_job.text.trim().isEmpty || value == null ||
        !value.isFinite || value <= 0) {
      setState(() => _error = 'Enter a job and a valid positive CHF amount.');
      return;
    }
    final now = DateTime.now();
    Navigator.of(context).pop(ExpenseRecord(
      id: 'local-expense-${now.microsecondsSinceEpoch}',
      category: _category,
      title: _category.label,
      job: _job.text.trim(),
      report: _report.text.trim(),
      amount: value,
      date: now,
      status: ExpenseStatus.toReview,
      description: _description.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SafeArea(top: false, child: Center(
      heightFactor: 1,
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Add Expense', style: TextStyle(
                fontFamily: 'Inter', fontSize: 20, color: AppColors.dark,
                fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              const Text('Local draft — no reimbursement is submitted.',
                style: TextStyle(fontFamily: 'Inter',
                  fontSize: 12, color: AppColors.secondaryText)),
              const SizedBox(height: 15),
              DropdownButtonFormField<ExpenseCategory>(
                key: const Key('expense-add-category'),
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: [for (final c in ExpenseCategory.values)
                  DropdownMenuItem(value: c, child: Text(c.label))],
                onChanged: (v) {
                  if (v != null) setState(() => _category = v);
                },
              ),
              const SizedBox(height: 12),
              TextField(key: const Key('expense-add-job'),
                controller: _job,
                decoration: const InputDecoration(labelText: 'Job')),
              const SizedBox(height: 12),
              TextField(key: const Key('expense-add-report'),
                controller: _report,
                decoration: const InputDecoration(labelText: 'Report reference')),
              const SizedBox(height: 12),
              TextField(key: const Key('expense-add-amount'),
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Amount (CHF)')),
              const SizedBox(height: 12),
              TextField(key: const Key('expense-add-description'),
                controller: _description,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 2),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, key: const Key('expense-add-error'),
                  style: const TextStyle(color: Color(0xFFB42318))),
              ],
              const SizedBox(height: 20),
              Sign2DigitalPrimaryButton(
                key: const Key('expense-save-draft'),
                label: 'Save Local Draft',
                onPressed: _save),
            ],
          ),
        ),
      ),
    )),
  );
}
