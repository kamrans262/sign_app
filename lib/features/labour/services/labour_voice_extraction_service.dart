

/// Suggestions only: an empty/null value is never treated as a form answer.
class LabourVoiceSuggestion {
  const LabourVoiceSuggestion({
    this.jobReference,
    this.worker,
    this.date,
    this.startMinutes,
    this.endMinutes,
    this.labourType,
    this.hourlyRate,
    this.description,
  });

  final String? jobReference;
  final String? worker;
  final DateTime? date;
  final int? startMinutes;
  final int? endMinutes;
  final String? labourType;
  final double? hourlyRate;
  final String? description;

  static String? _text(Object? raw) =>
      raw is String && raw.trim().isNotEmpty ? raw.trim() : null;

  static int? _time(Object? raw) {
    final value = _text(raw);
    if (value == null) { return null; }
    final parts = RegExp(r'^([01]\d|2[0-3]):([0-5]\d)$').firstMatch(value);
    if (parts == null) { return null; }
    return int.parse(parts.group(1)!) * 60 + int.parse(parts.group(2)!);
  }

  static DateTime? _date(Object? raw) {
    final value = _text(raw);
    if (value == null || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
      return null;
    }
    final parsed = DateTime.tryParse(value);
    if (parsed == null || !parsed.toIso8601String().startsWith(value)) {
      return null;
    }
    return parsed;
  }

  factory LabourVoiceSuggestion.fromJson(Map<String, dynamic> data) {
    final rawRate = data['hourlyRate'];
    final rate = rawRate is num ? rawRate.toDouble() : null;
    return LabourVoiceSuggestion(
      jobReference: _text(data['jobReference']),
      worker: _text(data['worker']),
      date: _date(data['date']),
      startMinutes: _time(data['startTime']),
      endMinutes: _time(data['endTime']),
      labourType: _text(data['labourType']),
      hourlyRate: rate != null && rate.isFinite && rate >= 0 ? rate : null,
      description: _text(data['description']),
    );
  }

  bool get hasSuggestions =>
      jobReference != null || worker != null || date != null ||
      startMinutes != null || endMinutes != null ||
      labourType != null || hourlyRate != null || description != null;
}

abstract class LabourVoiceExtractionService {
  Future<LabourVoiceSuggestion> extract(String audioPath, String temporaryApiKey);
}

// Production uses Laravel-backed RemoteLabourVoiceExtractionService.
