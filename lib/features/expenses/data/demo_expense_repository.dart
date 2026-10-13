import '../domain/expense_record.dart';

/// Local-only sample records and drafts until the Laravel API is ready.
class DemoExpenseRepository implements ExpenseRepository {
  const DemoExpenseRepository();

  static final Map<String, ExpenseRecord> _localDrafts = {};

  static void clearDrafts() => _localDrafts.clear();

  @override
  Future<List<ExpenseRecord>> listExpenses() async => [
    for (final (index, category, status) in [
      (1, ExpenseCategory.fuel, ExpenseStatus.approved),
      (2, ExpenseCategory.tools, ExpenseStatus.toReview),
      (3, ExpenseCategory.parking, ExpenseStatus.approved),
      (4, ExpenseCategory.meals, ExpenseStatus.approved),
    ])
      if (!_localDrafts.containsKey('demo-expense-$index')) ExpenseRecord(
        id: 'demo-expense-$index',
        category: category,
        title: category.label,
        job: 'Kitchen renovation',
        report: 'Site report',
        amount: 78.80,
        date: DateTime(2026, 8, 23, 22),
        status: status,
        description: 'UI demo expense',
        clientName: 'Jean Dupont',
        approvedBy: status == ExpenseStatus.approved ? 'Jean Dupont' : null,
        approvedAt: status == ExpenseStatus.approved
            ? DateTime(2026, 8, 23) : null,
        updatedAt: DateTime(2026, 8, 23),
      ),
    ..._localDrafts.values,
  ];

  @override
  Future<void> saveDraft(ExpenseRecord expense) async {
    if (!expense.demoOnly || expense.status != ExpenseStatus.toReview ||
        expense.title.trim().isEmpty || !expense.amount.isFinite ||
        expense.amount <= 0 || expense.job.trim().isEmpty) {
      throw ArgumentError('Invalid local expense draft.');
    }
    _localDrafts[expense.id] = expense;
  }

  @override
  Future<void> updateExpense(ExpenseRecord expense) async {
    if (!expense.demoOnly || expense.id.trim().isEmpty ||
        expense.job.trim().isEmpty || !expense.amount.isFinite ||
        expense.amount <= 0) {
      throw ArgumentError('Invalid expense edit.');
    }
    final exists = _localDrafts.containsKey(expense.id) ||
        (await listExpenses()).any((item) => item.id == expense.id);
    if (!exists) throw StateError('Expense is no longer available.');
    _localDrafts[expense.id] = expense;
  }
}
