import '../../../core/services/active_company_session.dart';
import '../../../core/services/sign_api_client.dart';
import '../../auth/data/mobile_auth_repository.dart';
import '../domain/reminder_record.dart';

/// Lists verified current-company objects. Never reuses demo IDs.
class RemoteReminderReferenceSource implements ReminderReferenceSource {
  RemoteReminderReferenceSource({SignApiClient? api})
      : _api = api ?? MobileAuthRepository.shared.api;
  final SignApiClient _api;

  static const _paths = <ReminderType, String>{
    ReminderType.invoice: '/api/v1/invoices',
    ReminderType.job: '/api/v1/jobs',
    ReminderType.client: '/api/v1/clients',
    ReminderType.document: '/api/v1/documents',
    ReminderType.equipment: '/api/v1/equipment',
  };

  static int _int(Object? x) =>
      x is num ? x.toInt() : int.tryParse(x.toString()) ?? 0;

  @override
  Future<List<ReminderRelatedItem>> listForType(ReminderType type) async {
    if (type == ReminderType.other) return const [];
    final company = ActiveCompanySession.companyId;
    if (company == null || company < 1) {
      throw const SignApiException('Select a company first.');
    }
    final endpoint = _paths[type];
    if (endpoint == null) return const [];
    final result = <ReminderRelatedItem>[];
    for (var page = 1; page <= 20; page++) {
      final raw = await _api.get(endpoint,
        companyScoped: true,
        queryParameters: {'per_page':'100', 'page':page.toString()});
      if (ActiveCompanySession.companyId != company) {
        throw const SignApiException('Company changed while loading links.');
      }
      final data = raw['data'];
      if (data is! Map) {
        throw const SignApiException('Invalid related-item response.');
      }
      final rows = data['records'];
      final last = _int(data['last_page']);
      if (rows is! List || last < page || last > 20) {
        throw const SignApiException('Invalid related-item pagination.');
      }
      for (final value in rows) {
        if (value is! Map) continue;
        final id = _int(value['id']);
        final rowCompany = _int(value['company_id']);
        // Catalog entries may carry synthetic IDs; they cannot be linked
        // until their authoritative managed_document ID is known.
        if (id < 1 || (rowCompany > 0 && rowCompany != company)) continue;
        final label = [
          value['number'], value['reference_number'], value['full_name'],
          value['name'], value['title'], value['code'],
        ].whereType<String>().where((s) => s.trim().isNotEmpty);
        result.add(ReminderRelatedItem(
          type:type, id:id.toString(),
          title:label.isEmpty ? type.label + ' #' + id.toString()
              : label.first,
          project: (value['project'] ?? value['title'] ?? '').toString(),
        ));
      }
      if (page == last) return result;
    }
    throw const SignApiException('Too many related-item pages.');
  }
}