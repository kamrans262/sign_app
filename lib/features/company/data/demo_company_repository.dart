import '../domain/company_profile.dart';
import 'company_repository.dart';

/// In-memory demo records; changes disappear when the process restarts.
class DemoCompanyRepository implements CompanyRepository {
  DemoCompanyRepository({List<CompanyProfile>? seed})
    : _items = <String, CompanyProfile>{
        for (final item in seed ?? demoCompanies) item.id: item,
      };

  static final DemoCompanyRepository shared = DemoCompanyRepository();

  static final List<CompanyProfile> demoCompanies = [
    CompanyProfile(
      id: 'demo-northstar-renovations',
      companyName: 'Northstar Renovations GmbH',
      address: 'Sample Street 8, 8000 Zürich, Switzerland',
      countryIsoCode: 'CH',
      dialingCode: '+41',
      phoneNumber: '790000000',
      email: 'hello@northstar.example',
      swissCompanyId: '',
      vatNumber: '',
      iban: '',
      qrIban: '',
      documentNumbering: 'Q-2900',
    ),
    CompanyProfile(
      id: 'demo-alpine-studio',
      companyName: 'Alpine Studio',
      address: 'Zürich, Switzerland',
      countryIsoCode: 'CH',
      dialingCode: '+41',
      phoneNumber: '791234567',
      email: 'hello@alpine.example',
      swissCompanyId: '',
      vatNumber: '',
      iban: '',
      qrIban: '',
      documentNumbering: 'INV-0001',
    ),
  ];

  final Map<String, CompanyProfile> _items;

  @override
  Future<CompanyProfile> save(CompanyProfile profile) async {
    _items[profile.id] = profile;
    return profile;
  }

  @override
  Future<CompanyProfile?> byId(String id) async => _items[id];

  @override
  Future<List<CompanyProfile>> list() async => List.unmodifiable(_items.values);
}
