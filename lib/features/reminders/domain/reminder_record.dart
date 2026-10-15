enum ReminderType {
  invoice('Invoice'), job('Job'), client('Client'),
  document('Document'), other('Other');

  const ReminderType(this.label);
  final String label;
}

enum ReminderFilter { all, upcoming, overdue, completed }

class ReminderRelatedItem {
  const ReminderRelatedItem({
    required this.type, required this.id, required this.title,
    this.project = '',
  });

  final ReminderType type;
  final String id, title, project;
}

class ReminderRecord {
  const ReminderRecord({
    required this.id, required this.title, required this.type,
    required this.remindAt, this.relatedItem, this.notes = '',
    this.sendNotification = true, this.completedAt,
    this.createdAt, this.demoOnly = false,
  });

  final String id, title, notes;
  final ReminderType type;
  final ReminderRelatedItem? relatedItem;
  final DateTime remindAt;
  final bool sendNotification;
  final DateTime? completedAt, createdAt;
  final bool demoOnly;

  bool get completed => completedAt != null;

  ReminderFilter filterAt(DateTime now) {
    if (completed) return ReminderFilter.completed;
    return remindAt.isBefore(now) ? ReminderFilter.overdue
        : ReminderFilter.upcoming;
  }

  bool matches(String value) {
    final query = value.trim().toLowerCase();
    return query.isEmpty || [
      title, type.label, notes,
      relatedItem?.title ?? '', relatedItem?.project ?? '',
    ].any((part) => part.toLowerCase().contains(query));
  }

  ReminderRecord copyWith({
    String? title, ReminderType? type, DateTime? remindAt,
    ReminderRelatedItem? relatedItem, bool clearRelatedItem = false,
    String? notes, bool? sendNotification,
    DateTime? completedAt, bool clearCompleted = false,
  }) => ReminderRecord(
    id: id, title: title ?? this.title, type: type ?? this.type,
    remindAt: remindAt ?? this.remindAt,
    relatedItem: clearRelatedItem ? null : relatedItem ?? this.relatedItem,
    notes: notes ?? this.notes,
    sendNotification: sendNotification ?? this.sendNotification,
    completedAt: clearCompleted ? null : completedAt ?? this.completedAt,
    createdAt: createdAt, demoOnly: demoOnly,
  );
}

abstract class ReminderRepository {
  Future<List<ReminderRecord>> listReminders();
  Future<ReminderRecord> saveReminder(ReminderRecord reminder);
  Future<ReminderRecord> updateReminder(ReminderRecord reminder);
  Future<ReminderRecord> setCompleted(String id, bool completed);
}

abstract class ReminderReferenceSource {
  Future<List<ReminderRelatedItem>> listForType(ReminderType type);
}
