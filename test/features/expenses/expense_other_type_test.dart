import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/features/expenses/domain/expense_record.dart';

void main() {
  test('Other shows custom expense type, searchable and preserved by edit', () {
    final expense = ExpenseRecord(
      id: 'expense-1', category: ExpenseCategory.other, title: 'Vehicle hire',
      customCategory: 'Vehicle hire', job: 'Repair', report: '',
      amount: 42, date: DateTime(2026, 11, 11),
      status: ExpenseStatus.toReview,
    );
    expect(expense.displayCategory, 'Vehicle hire');
    expect(expense.matches('hire'), true);
    expect(expense.copyWith(description: 'Transport').customCategory, 'Vehicle hire');
    expect(expense.copyWith(category: ExpenseCategory.material,
        customCategory: '').displayCategory, 'Material');
  });
}
