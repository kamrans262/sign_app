import '../../jobs/data/local_job_photo_source.dart';

enum ExpenseCategory {
  fuel('Fuel'), tools('Tools'), parking('Parking'),
  meals('Meals'), other('Other'), material('Material'), labour('Labour');

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
    this.jobId,
    this.photos = const [],
    this.tags = const [],
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
  final String? jobId;
  final List<LocalJobPhotoSelection> photos;
  final List<String> tags;

  bool matches(String input) {
    final query = input.trim().toLowerCase();
    if (query.isEmpty) return true;
    return [id, title, category.label, job, report, status.label, description, ...tags]
        .any((value) => value.toLowerCase().contains(query));
  }

  String get formattedAmount => 'CHF ${amount.toStringAsFixed(2)}';
}

abstract class ExpenseRepository {
  Future<List<ExpenseRecord>> listExpenses();
  Future<void> saveDraft(ExpenseRecord expense);
}
