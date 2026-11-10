import 'package:flutter/material.dart';

import '../domain/reminder_record.dart';

/// Nullable suggestions. Only explicitly spoken fields may be populated.
class ReminderVoiceSuggestion {
  const ReminderVoiceSuggestion({
    this.title, this.type, this.relatedItem, this.date, this.time, this.notes,
  });

  final String? title, relatedItem, notes;
  final ReminderType? type;
  final DateTime? date;
  final TimeOfDay? time;

  static String? _str(Object? value) =>
      value is String && value.trim().isNotEmpty ? value.trim() : null;

  static DateTime? _date(Object? input) {
    final value = _str(input);
    if (value == null || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
      return null;
    }
    final parsed = DateTime.tryParse(value);
    return parsed != null && parsed.toIso8601String().startsWith(value)
        ? parsed : null;
  }

  static TimeOfDay? _time(Object? input) {
    final value = _str(input);
    if (value == null || !RegExp(r'^\d{2}:\d{2}$').hasMatch(value)) {
      return null;
    }
    final parts = value.split(':').map(int.parse).toList();
    if (parts[0] > 23 || parts[1] > 59) return null;
    return TimeOfDay(hour: parts[0], minute: parts[1]);
  }

  factory ReminderVoiceSuggestion.fromJson(Map<String, dynamic> json) {
    final typeName = _str(json['type'])?.toLowerCase();
    final type = switch (typeName) {
      'invoice' => ReminderType.invoice,
      'job' || 'project' => ReminderType.job,
      'client' => ReminderType.client,
      'document' => ReminderType.document,
      'other' => ReminderType.other,
      _ => null,
    };
    return ReminderVoiceSuggestion(
      title: _str(json['title']),
      type: type,
      relatedItem: _str(json['relatedItem']),
      date: _date(json['reminderDate']),
      time: _time(json['reminderTime']),
      notes: _str(json['notes']),
    );
  }

  bool get hasData => title != null || type != null ||
      relatedItem != null || date != null || time != null || notes != null;
}

abstract class ReminderVoiceExtractionService {
  Future<ReminderVoiceSuggestion> extract(String audioPath);
}
