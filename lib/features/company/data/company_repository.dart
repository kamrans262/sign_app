import '../domain/company_profile.dart';

/// Swap this implementation with a Laravel API repository in the backend phase.
abstract class CompanyRepository {
  Future<CompanyProfile> save(CompanyProfile profile);
  Future<CompanyProfile?> byId(String id);
  Future<List<CompanyProfile>> list();
}
