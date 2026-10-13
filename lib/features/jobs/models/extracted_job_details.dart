/// Suggested values from a real, completed transcription/extraction request.
/// Missing or uncertain values stay null; no client/member ID is fabricated.
class ExtractedJobDetails {
  const ExtractedJobDetails({
    this.clientName,
    this.address,
    this.description,
    this.startDate,
    this.endDate,
    this.budgetChf,
    this.teamMemberNames = const <String>[],
    this.transcript,
  });

  final String? clientName;
  final String? address;
  final String? description;
  final DateTime? startDate;
  final DateTime? endDate;
  final double? budgetChf;
  final List<String> teamMemberNames;
  final String? transcript;

  bool get hasSuggestions =>
      clientName != null ||
      address != null ||
      description != null ||
      startDate != null ||
      endDate != null ||
      budgetChf != null ||
      teamMemberNames.isNotEmpty;

  static String? _text(Object? value) {
    if (value is! String || value.trim().isEmpty) return null;
    return value.trim();
  }

  static DateTime? _date(Object? value) {
    final text = _text(value);
    if (text == null || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text)) {
      return null;
    }
    final parsed = DateTime.tryParse(text);
    if (parsed == null ||
        '${parsed.year.toString().padLeft(4, '0')}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}' !=
            text) {
      return null;
    }
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  factory ExtractedJobDetails.fromJson(Map<String, dynamic> value) {
    final rawBudget = value['budgetChf'];
    final budget = rawBudget is num
        ? rawBudget.toDouble()
        : (rawBudget is String ? double.tryParse(rawBudget) : null);
    final rawMembers = value['teamMemberNames'];
    return ExtractedJobDetails(
      clientName: _text(value['clientName']),
      address: _text(value['address']),
      description: _text(value['description']),
      startDate: _date(value['startDate']),
      endDate: _date(value['endDate']),
      budgetChf: budget != null && budget.isFinite && budget >= 0
          ? budget
          : null,
      teamMemberNames: rawMembers is List
          ? rawMembers.map(_text).whereType<String>().toSet().toList()
          : const <String>[],
      transcript: _text(value['transcript']),
    );
  }
}
