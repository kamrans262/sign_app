import '../../../core/services/active_company_session.dart';
import '../../../core/services/sign_api_client.dart';
import '../../auth/data/mobile_auth_repository.dart';

class InAppNotification {
  const InAppNotification({
    required this.id, required this.companyId,
    required this.title, required this.body,
    required this.createdAt, required this.isRead,
    this.linkType, this.linkId,
  });

  final int id, companyId;
  final String title, body;
  final DateTime createdAt;
  final bool isRead;
  final String? linkType;
  final int? linkId;
}

class NotificationInboxSnapshot {
  const NotificationInboxSnapshot(this.records, this.unreadCount);
  final List<InAppNotification> records;
  final int unreadCount;
}

/// In-app only; never assumes that a provider accepted or delivered a push.
class RemoteNotificationRepository {
  RemoteNotificationRepository({SignApiClient? api})
      : _api = api ?? MobileAuthRepository.shared.api;

  static final shared = RemoteNotificationRepository();
  final SignApiClient _api;

  int _company() {
    final id = ActiveCompanySession.companyId;
    if (id == null || id < 1) {
      throw const SignApiException('Select a company before opening notifications.');
    }
    return id;
  }

  void _check(int id) {
    if (ActiveCompanySession.companyId != id) {
      throw const SignApiException('Company changed during notifications.');
    }
  }

  static Map<String, dynamic> _map(Object? raw) {
    if (raw is! Map) throw const SignApiException('Invalid notification response.');
    return Map<String, dynamic>.from(raw);
  }

  static int _int(Object? raw) =>
      raw is num ? raw.toInt() : int.tryParse(raw.toString()) ?? 0;

  Future<NotificationInboxSnapshot> list() async {
    final company = _company(), records = <InAppNotification>[];
    var unreadCount = 0;
    for (var page = 1; page <= 100; page++) {
      final response = await _api.get('/api/v1/notifications',
        companyScoped: true, queryParameters: {
          'page': page.toString(), 'per_page': '100',
        });
      _check(company);
      final data = _map(response['data']);
      final rows = data['records'];
      final lastPage = _int(data['last_page']);
      if (rows is! List || lastPage < page || lastPage > 100) {
        throw const SignApiException('Invalid notification list.');
      }
      if (page == 1) unreadCount = _int(data['unread_count']);
      for (final raw in rows) {
        final row = _map(raw);
        final id = _int(row['id']);
        if (id < 1 || _int(row['company_id']) != company ||
            _int(row['recipient_user_id']) < 1) {
          throw const SignApiException('Cross-company notification rejected.');
        }
        final date = DateTime.tryParse((row['created_at'] ?? '').toString());
        if (date == null) {
          throw const SignApiException('Invalid notification timestamp.');
        }
        final linkType = row['link_type']?.toString();
        if (linkType != null && linkType != 'reminder') {
          throw const SignApiException('Unsupported notification link type.');
        }
        records.add(InAppNotification(
          id: id, companyId: company,
          title: (row['title'] ?? '').toString(),
          body: (row['body'] ?? '').toString(),
          createdAt: date.toLocal(),
          isRead: row['read_at'] != null,
          linkType: linkType, linkId: row['link_id'] == null
              ? null : _int(row['link_id']),
        ));
      }
      if (page == lastPage) {
        return NotificationInboxSnapshot(records, unreadCount);
      }
    }
    throw const SignApiException('Notification pagination limit exceeded.');
  }

  Future<void> markRead(int id) async {
    if (id < 1) throw const SignApiException('Invalid notification.');
    final company = _company();
    await _api.post('/api/v1/notifications/$id/read',
      companyScoped: true);
    _check(company);
  }

  Future<void> markAllRead() async {
    final company = _company();
    await _api.post('/api/v1/notifications/read-all', companyScoped: true);
    _check(company);
  }

  Future<void> dismiss(int id) async {
    if (id < 1) throw const SignApiException('Invalid notification.');
    final company = _company();
    await _api.delete('/api/v1/notifications/$id',
      companyScoped: true);
    _check(company);
  }
}