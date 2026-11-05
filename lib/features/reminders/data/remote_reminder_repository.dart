import '../../../core/services/active_company_session.dart';
import '../../../core/services/sign_api_client.dart';
import '../../auth/data/mobile_auth_repository.dart';
import '../domain/reminder_record.dart';

/// M20 tenant-authoritative reminders. Never substitutes sample data on
/// authentication failure, HTTP errors, or company-context changes.
class RemoteReminderRepository implements ReminderRepository {
  RemoteReminderRepository({SignApiClient? api})
      : _api = api ?? MobileAuthRepository.shared.api;

  static final shared = RemoteReminderRepository();
  final SignApiClient _api;

  int _company() {
    final company = ActiveCompanySession.companyId;
    if (company == null || company < 1) {
      throw const SignApiException('Select a company to view reminders.');
    }
    return company;
  }

  void _check(int id) {
    if (ActiveCompanySession.companyId != id) {
      throw const SignApiException('Company changed while loading reminders.');
    }
  }

  static Map<String, dynamic> _map(Object? raw) {
    if (raw is! Map) throw const SignApiException('Invalid reminder response.');
    return Map<String, dynamic>.from(raw);
  }

  static Map<String, dynamic> _data(Map<String, dynamic> raw) =>
      _map(raw['data']);

  static int _integer(Object? value) =>
      value is num ? value.toInt() : int.tryParse(value.toString()) ?? 0;

  static DateTime _utc(Object? raw) {
    if (raw is! String || raw.isEmpty) {
      throw const SignApiException('Missing reminder date.');
    }
    final parsed = DateTime.tryParse(
      raw.contains('Z') || raw.contains('+')
          ? raw
          : "${raw.replaceFirst(' ', 'T')}Z",
    );
    if (parsed == null || parsed.year < 2000 || parsed.year > 2100) {
      throw const SignApiException('Invalid reminder date.');
    }
    return parsed.toLocal();
  }

  static DateTime? _optionalDate(Object? raw) =>
      raw == null ? null : _utc(raw);

  static String _path(String id) {
    final parsed = int.tryParse(id);
    if (parsed == null || parsed < 1) {
      throw const SignApiException('Invalid saved reminder ID.');
    }
    return '/api/v1/reminders/$parsed';
  }

  ReminderRecord _parse(Object? raw, int company) {
    final row = _map(raw);
    final id = _integer(row['id']);
    final version = _integer(row['lock_version']);
    if (id < 1 || version < 1 || _integer(row['company_id']) != company) {
      throw const SignApiException('Invalid or cross-company reminder.');
    }
    final typeName = (row['type'] ?? '').toString();
    final matching = ReminderType.values.where((t) => t.name == typeName);
    if (matching.isEmpty) {
      throw const SignApiException('Unrecognized reminder type.');
    }
    final status = (row['status'] ?? '').toString();
    if (!['active', 'completed', 'archived'].contains(status)) {
      throw const SignApiException('Unrecognized reminder status.');
    }
    ReminderRelatedItem? related;
    final relatedType = row['related_type']?.toString();
    final relatedId = _integer(row['related_id']);
    if (relatedType != null && relatedId > 0 && relatedType == typeName) {
      related = ReminderRelatedItem(
        type: matching.first,
        id: relatedId.toString(),
        title: 'Linked ${matching.first.label}',
      );
    }
    return ReminderRecord(
      id: id.toString(),
      title: (row['title'] ?? '').toString(),
      type: matching.first,
      remindAt: _utc(row['due_at']),
      relatedItem: related,
      notes: (row['notes'] ?? '').toString(),
      sendNotification: row['send_notification'] == true ||
          row['send_notification'] == 1,
      completedAt: _optionalDate(row['completed_at']),
      createdAt: _optionalDate(row['created_at']),
      lockVersion: version,
    );
  }

  Map<String, dynamic> _body(ReminderRecord item) {
    if (item.title.trim().isEmpty || item.title.length > 160) {
      throw const SignApiException('Enter a valid reminder title.');
    }
    final body = <String, dynamic>{
      'title': item.title.trim(),
      'type': item.type.name,
      'due_at': item.remindAt.toUtc().toIso8601String(),
      'timezone': 'UTC',
      'notes': item.notes,
      'send_notification': item.sendNotification,
    };
    if (item.relatedItem != null) {
      if (item.relatedItem!.type != item.type) {
        throw const SignApiException('Related reminder item type mismatch.');
      }
      final relatedId = int.tryParse(item.relatedItem!.id);
      if (relatedId == null || relatedId < 1) {
        throw const SignApiException(
          'Select a real company record before saving this reminder.',
        );
      }
      body['related_type'] = item.type.name;
      body['related_id'] = relatedId;
    }
    return body;
  }

  @override
  Future<List<ReminderRecord>> listReminders() async {
    final company = _company();
    final records = <ReminderRecord>[];
    for (var page = 1; page <= 100; page++) {
      final data = _data(await _api.get(
        '/api/v1/reminders',
        companyScoped: true,
        queryParameters: {'page': page.toString(), 'per_page': '100'},
      ));
      _check(company);
      final rows = data['records'];
      final lastPage = _integer(data['last_page']);
      if (rows is! List || lastPage < page || lastPage > 100) {
        throw const SignApiException('Invalid reminder page response.');
      }
      records.addAll(rows.map((row) => _parse(row, company)));
      if (page == lastPage) return records;
    }
    throw const SignApiException('Reminder pagination limit exceeded.');
  }

  @override
  Future<ReminderRecord> saveReminder(ReminderRecord reminder) async {
    final company = _company();
    if (!reminder.id.startsWith('reminder-local-')) {
      throw const SignApiException('Cannot create a reminder with a saved ID.');
    }
    final data = _data(await _api.post(
      '/api/v1/reminders',
      companyScoped: true,
      data: _body(reminder),
    ));
    _check(company);
    return _parse(_map(data['reminder']), company);
  }

  @override
  Future<ReminderRecord> updateReminder(ReminderRecord reminder) async {
    final company = _company();
    final path = _path(reminder.id);
    final data = _data(await _api.request(
      'PATCH', path, companyScoped: true,
      data: _body(reminder)..['lock_version'] = reminder.lockVersion,
    ));
    _check(company);
    final updated = _parse(data['reminder'], company);
    if (updated.completed != reminder.completed) {
      return setCompleted(updated.id, reminder.completed);
    }
    return updated;
  }

  @override
  Future<ReminderRecord> setCompleted(String id, bool completed) async {
    final company = _company();
    final path = _path(id);
    final details = _data(await _api.get(path, companyScoped: true));
    _check(company);
    final current = _parse(details['reminder'], company);
    final response = _data(await _api.post(
      '$path/status',
      companyScoped: true,
      data: {
        'lock_version': current.lockVersion,
        'action': completed ? 'complete' : 'reopen',
      },
    ));
    _check(company);
    return _parse(response['reminder'], company);
  }
}