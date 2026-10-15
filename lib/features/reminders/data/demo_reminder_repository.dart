import '../domain/reminder_record.dart';

/// Session-local repository, matching the existing Invoice/Equipment demo
/// architecture. No OS notification, Laravel persistence or push is implied.
class DemoReminderRepository implements ReminderRepository {
  const DemoReminderRepository();

  static final Map<String, ReminderRecord> _changes = {};

  static void resetForTests() => _changes.clear();

  static List<ReminderRecord> _examples(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final evening = today.add(const Duration(hours: 19));
    final upcomingToday = evening.isAfter(now)
        ? evening : now.add(const Duration(minutes: 90));
    return [
      ReminderRecord(
        id: 'reminder-demo-client-1', title: 'Client Meeting',
        type: ReminderType.client,
        relatedItem: const ReminderRelatedItem(
          type: ReminderType.client,
          id: 'demo-client-1', title: 'Roadside Villa',
          project: 'Roadside Villa'),
        remindAt: upcomingToday, demoOnly: true,
      ),
      ReminderRecord(
        id: 'reminder-demo-invoice-1', title: 'Send Invoice',
        type: ReminderType.invoice,
        relatedItem: const ReminderRelatedItem(
          type: ReminderType.invoice,
          id: 'invoice-demo-pending-1',
          title: 'INV-2026-0099', project: 'Riverside Villa'),
        remindAt: now.add(const Duration(days: 2)), demoOnly: true,
      ),
      ReminderRecord(
        id: 'reminder-demo-job-1', title: 'Site Inspection',
        type: ReminderType.job,
        relatedItem: const ReminderRelatedItem(
          type: ReminderType.job,
          id: 'demo-active-1', title: 'Terrace Renovation',
          project: 'Terrace Renovation'),
        remindAt: now.subtract(const Duration(hours: 3)),
        demoOnly: true,
      ),
      ReminderRecord(
        id: 'reminder-demo-doc-1', title: 'Review Document',
        type: ReminderType.document,
        remindAt: now.subtract(const Duration(days: 1)),
        completedAt: now.subtract(const Duration(hours: 18)),
        demoOnly: true,
      ),
    ];
  }

  @override
  Future<List<ReminderRecord>> listReminders() async {
    final examples = _examples(DateTime.now());
    return List<ReminderRecord>.unmodifiable([
      for (final sample in examples) _changes[sample.id] ?? sample,
      for (final entry in _changes.values)
        if (!examples.any((demo) => demo.id == entry.id)) entry,
    ]);
  }

  static void _validate(ReminderRecord reminder) {
    if (reminder.id.trim().isEmpty || reminder.title.trim().isEmpty ||
        reminder.title.length > 160 ||
        reminder.remindAt.year < 2000 || reminder.remindAt.year > 2100 ||
        (reminder.relatedItem != null &&
         reminder.relatedItem!.type != reminder.type)) {
      throw ArgumentError('Invalid reminder data.');
    }
  }

  @override
  Future<ReminderRecord> saveReminder(ReminderRecord reminder) async {
    _validate(reminder);
    if ((await listReminders()).any((item) => item.id == reminder.id)) {
      throw StateError('Reminder ID already exists');
    }
    _changes[reminder.id] = reminder;
    return reminder;
  }

  @override
  Future<ReminderRecord> updateReminder(ReminderRecord reminder) async {
    _validate(reminder);
    if (!(await listReminders()).any((item) => item.id == reminder.id)) {
      throw StateError('Reminder not found');
    }
    _changes[reminder.id] = reminder;
    return reminder;
  }

  @override
  Future<ReminderRecord> setCompleted(String id, bool completed) async {
    final items = await listReminders();
    final index = items.indexWhere((item) => item.id == id);
    if (index < 0) throw StateError('Reminder not found');
    final next = items[index].copyWith(
      completedAt: completed ? DateTime.now() : null,
      clearCompleted: !completed,
    );
    _changes[id] = next;
    return next;
  }
}
