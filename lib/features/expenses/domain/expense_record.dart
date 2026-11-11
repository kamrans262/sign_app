import '../../jobs/data/local_job_photo_source.dart';

/// Events must come from a real local action or the future API response.
class ExpenseHistoryEvent {
  const ExpenseHistoryEvent({
    required this.id,
    required this.title,
    required this.occurredAt,
    this.description,
    this.actorName,
  });
  final String id;
  final String title;
  final DateTime occurredAt;
  final String? description;
  final String? actorName;
}

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
    this.customCategory = '',
    this.supplier = '',
    this.lockVersion = 1,
    this.demoOnly = true,
    this.jobId,
    this.photos = const [],
    this.tags = const [],
    this.clientName,
    this.approvedBy,
    this.approvedAt,
    this.updatedAt,
    this.history = const [],
    this.reimbursementRequested = false,
    this.canApprove = false,
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
  /// Optional name when Other is selected; legacy records may be empty.
  final String customCategory;
  final String supplier;
  String get displayCategory => category == ExpenseCategory.other &&
          customCategory.trim().isNotEmpty
      ? customCategory.trim() : category.label;
  final int lockVersion;
  final bool demoOnly;
  final String? jobId;
  final List<LocalJobPhotoSelection> photos;
  final List<String> tags;
  final String? clientName;
  final String? approvedBy;
  final DateTime? approvedAt;
  final DateTime? updatedAt;
  final List<ExpenseHistoryEvent> history;
  final bool reimbursementRequested;
  /// Server-verified reviewer capability, never inferred from visible buttons.
  final bool canApprove;

  bool matches(String input) {
    final query = input.trim().toLowerCase();
    if (query.isEmpty) return true;
    return [id, title, category.label, displayCategory, job, report,
        status.label, supplier, description, ...tags]
        .any((value) => value.toLowerCase().contains(query));
  }

  ExpenseRecord copyWith({
    ExpenseCategory? category, String? title, String? job, String? jobId,
    String? report, double? amount, DateTime? date, String? description,
    String? customCategory,
    List<LocalJobPhotoSelection>? photos, List<String>? tags,
    String? supplier, DateTime? updatedAt, List<ExpenseHistoryEvent>? history,
    bool? reimbursementRequested, bool? canApprove,
  }) => ExpenseRecord(
    id: id, category: category ?? this.category,
    title: title ?? this.title, job: job ?? this.job,
    jobId: jobId ?? this.jobId, report: report ?? this.report,
    amount: amount ?? this.amount, date: date ?? this.date,
    status: status, demoOnly: demoOnly,
    description: description ?? this.description,
    customCategory: customCategory ?? this.customCategory,
    supplier: supplier ?? this.supplier, lockVersion: lockVersion,
    photos: photos ?? this.photos, tags: tags ?? this.tags,
    clientName: clientName, approvedBy: approvedBy, approvedAt: approvedAt,
    updatedAt: updatedAt ?? this.updatedAt,
    history: history ?? this.history,
    reimbursementRequested: reimbursementRequested ?? this.reimbursementRequested,
    canApprove: canApprove ?? this.canApprove,
  );

  String get formattedAmount => 'CHF ${amount.toStringAsFixed(2)}';
}

abstract class ExpenseRepository {
  Future<List<ExpenseRecord>> listExpenses();
  Future<void> saveDraft(ExpenseRecord expense);

  /// Override in a repository supporting updates; never duplicate an expense.
  Future<void> updateExpense(ExpenseRecord expense) =>
      Future<void>.error(UnsupportedError('Expense editing is not available.'));
}
