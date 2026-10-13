enum ExpenseCategory {
  fuel('Fuel'), tools('Tools'), parking('Parking'),
  meals('Meals'), other('Other');

  const ExpenseCategory(this.label);
  final String label;
}

enum ExpenseStatus {
  toReview('To Review'), approved('Approved'), reimbursed('Reimbursed');

  const ExpenseStatus(this.label);
  final String label;
}

class ExpenseRecord {
  const ExpenseRecord({
    required this.id,
    required this.category,
    required this.title,
    required this.job,
    required this.report,
    required this.amount,
    required this.date,
    required this.status,
    this.description = '',
    this.demoOnly = true,
  });

  final String id;
  final ExpenseCategory category;
  final String title;
  final String job;
  final String report;
  /// Exact numeric CHF amount; never sort formatted strings.
  final double amount;
  final DateTime date;
  final ExpenseStatus status;
  final String description;
  final bool demoOnly;

  bool matches(String input) {
    final query = input.trim().toLowerCase();
    if (query.isEmpty) return true;
    return [id, title, category.label, job, report, status.label, description]
        .any((value) => value.toLowerCase().contains(query));
  }

  String get formattedAmount => 'CHF ${amount.toStringAsFixed(2)}';
}

abstract class ExpenseRepository {
  Future<List<ExpenseRecord>> listExpenses();
  Future<void> saveDraft(ExpenseRecord expense);
}
