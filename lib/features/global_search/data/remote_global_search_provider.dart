import '../../../core/services/active_company_session.dart';
import '../../../core/services/sign_api_client.dart';
import '../../auth/data/mobile_auth_repository.dart';
import 'global_search_source.dart';

/// Paginated, company-scoped M21 search: the server alone decides visibility.
class GlobalSearchPage {
  const GlobalSearchPage({
    required this.records, required this.total,
    required this.page, required this.hasMore,
  });
  final List<GlobalSearchResult> records;
  final int total, page;
  final bool hasMore;
}

class GlobalSearchFilters {
  const GlobalSearchFilters({
    this.clientId, this.jobId, this.documentType,
    this.dateFrom, this.dateTo, this.status,
  });
  final String? clientId, jobId, documentType, dateFrom, dateTo, status;

  bool get active => [clientId, jobId, documentType, dateFrom,
      dateTo, status].any((value) => value != null && value.isNotEmpty);
}

class GlobalSearchHit {
  const GlobalSearchHit({required this.type, required this.id,
    required this.companyId});
  final String type;
  final int id, companyId;
}

class RemoteGlobalSearchProvider implements GlobalSearchProvider {
  RemoteGlobalSearchProvider({SignApiClient? api})
      : _api = api ?? MobileAuthRepository.shared.api;

  final SignApiClient _api;

  static int _number(Object? value) =>
    value is int ? value : int.tryParse('$value') ?? 0;

  static GlobalSearchCategory _category(String type) => switch(type) {
    'clients' => GlobalSearchCategory.clients,
    'jobs' => GlobalSearchCategory.jobs,
    'quotes' => GlobalSearchCategory.quotes,
    'documents' => GlobalSearchCategory.documents,
    'general_documents' => GlobalSearchCategory.generalDocuments,
    'invoices' => GlobalSearchCategory.invoices,
    'expenses' => GlobalSearchCategory.expenses,
    'equipment' => GlobalSearchCategory.equipment,
    'deposits' => GlobalSearchCategory.deposits,
    'reports' => GlobalSearchCategory.reports,
    'reminders' => GlobalSearchCategory.reminders,
    _ => throw const SignApiException('Unsupported search category.'),
  };

  static String _types(GlobalSearchTab tab) => switch(tab) {
    GlobalSearchTab.all => '',
    GlobalSearchTab.jobs => 'jobs',
    GlobalSearchTab.clients => 'clients',
    GlobalSearchTab.documents => 'documents,general_documents,reports',
    GlobalSearchTab.invoices => 'invoices',
    GlobalSearchTab.more => 'quotes,expenses,equipment,deposits,reports,reminders',
  };

  Future<GlobalSearchPage> search({
    required String query,
    required GlobalSearchTab tab,
    required int page,
    GlobalSearchFilters filters = const GlobalSearchFilters(),
    int perPage = 25,
  }) async {
    final company = ActiveCompanySession.companyId;
    if (company == null || company <= 0) {
      throw const SignApiException('Select a company to search.');
    }
    final q = <String, String>{
      'page': '$page', 'per_page': '$perPage',
      'company_id': '$company',
      if (query.trim().isNotEmpty) 'q': query.trim(),
      if (_types(tab).isNotEmpty) 'types': _types(tab),
      if (filters.clientId?.isNotEmpty ?? false)
        'client_id': filters.clientId!,
      if (filters.jobId?.isNotEmpty ?? false)
        'job_id': filters.jobId!,
      if (filters.documentType?.isNotEmpty ?? false)
        'document_type': filters.documentType!,
      if (filters.dateFrom?.isNotEmpty ?? false)
        'date_from': filters.dateFrom!,
      if (filters.dateTo?.isNotEmpty ?? false)
        'date_to': filters.dateTo!,
      if (filters.status?.isNotEmpty ?? false)
        'status': filters.status!,
    };
    final response = await _api.get('/api/v1/search',
      companyScoped: true, queryParameters: q);
    if (ActiveCompanySession.companyId != company) {
      throw const SignApiException('Company changed during search.');
    }
    final data = response['data'];
    if (data is! Map<String, dynamic> ||
        data['records'] is! List ||
        data['pagination'] is! Map<String, dynamic>) {
      throw const SignApiException('Invalid search response.');
    }
    final pagination = data['pagination'] as Map<String, dynamic>;
    final total = _number(pagination['total']);
    final actualPage = _number(pagination['page']);
    if (total < 0 || actualPage != page ||
        pagination['has_more'] is! bool) {
      throw const SignApiException('Invalid search pagination.');
    }
    final list = <GlobalSearchResult>[];
    for (final value in data['records'] as List) {
      if (value is! Map<String, dynamic>) {
        throw const SignApiException('Invalid search result.');
      }
      final id = _number(value['id']);
      final fromCompany = _number(value['company_id']);
      final type = value['type']?.toString() ?? '';
      if (id <= 0 || fromCompany != company) {
        throw const SignApiException('Cross-company search result rejected.');
      }
      final category = _category(type);
      list.add(GlobalSearchResult(
        category: category, id: '$id',
        title: (value['title'] ?? '').toString(),
        subtitle: (value['subtitle'] ?? '').toString(),
        details: (value['reference'] ?? '').toString(),
        searchTerms: [
          (value['status'] ?? '').toString(),
          (value['document_type'] ?? '').toString(),
        ],
        record: GlobalSearchHit(type: type, id: id, companyId: company),
      ));
    }
    return GlobalSearchPage(records: List.unmodifiable(list),
      total: total, page: actualPage,
      hasMore: pagination['has_more'] as bool);
  }

  @override
  Future<List<GlobalSearchResult>> loadAll() async =>
      (await search(query: '', tab: GlobalSearchTab.all, page: 1)).records;
}
