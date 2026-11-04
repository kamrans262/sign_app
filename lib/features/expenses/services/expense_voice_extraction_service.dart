import '../domain/expense_record.dart';

class ExpenseVoiceSuggestion {
  const ExpenseVoiceSuggestion({this.jobReference, this.category, this.date,
    this.amount, this.description, this.supplier, this.tags = const []});
  final String? jobReference;
  final ExpenseCategory? category;
  final DateTime? date;
  final double? amount;
  final String? description;
  final String? supplier;
  final List<String> tags;

  factory ExpenseVoiceSuggestion.fromJson(Map<String,dynamic> json) {
    String? nonblank(dynamic x) => x is String && x.trim().isNotEmpty ? x.trim() : null;
    final kind = nonblank(json['expenseType']);
    ExpenseCategory? category;
    for (final v in ExpenseCategory.values) {
      if (v.label.toLowerCase() == kind?.toLowerCase()) category = v;
    }
    final rawDate = nonblank(json['date']);
    DateTime? day;
    if (rawDate != null && RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(rawDate)) {
      final parse = DateTime.tryParse(rawDate);
      if (parse != null && parse.toIso8601String().startsWith(rawDate)) day = parse;
    }
    final rawAmount = json['amount'];
    final amount = rawAmount is num ? rawAmount.toDouble() : null;
    final tags = json['tags'] is List
        ? (json['tags'] as List).whereType<String>()
            .map((t) => t.trim()).where((t) => t.isNotEmpty).toSet().toList()
        : <String>[];
    return ExpenseVoiceSuggestion(
      jobReference: nonblank(json['jobReference']),
      category: category, date: day,
      amount: amount != null && amount.isFinite && amount > 0 ? amount : null,
      description: nonblank(json['description']),
      supplier: nonblank(json['supplier']), tags: tags,
    );
  }
}

abstract class ExpenseVoiceExtractionService {
  Future<ExpenseVoiceSuggestion> extract(String audioPath, String temporaryApiKey);
}

/// Production and testing implementations must never expose an OpenAI key
/// in the Flutter client. AI extraction happens via Laravel only.
