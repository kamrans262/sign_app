import 'client_repository.dart';
import '../domain/client_draft.dart';
import '../domain/client_profile.dart';

/// Mutable session-local data: when Laravel is ready, replace this repository
/// with an API-backed implementation without changing the forms or cards.
class DemoClientRepository implements ClientRepository {
  DemoClientRepository();

  int _nextLocalId = 1;
  final List<ClientProfile> _clients = List.generate(
    12,
    (index) => ClientProfile(
      id: 'demo-client-${index + 1}',
      companyName: 'Dupont Construction SA',
      companyType: 'Construction company',
      email: 'Contact@dupontconstruction.com',
      phone: '+41 21 123 45 67',
      jobCount: 12,
    ),
  );

  @override
  Future<List<ClientProfile>> listClients() async => List.of(_clients);

  @override
  Future<ClientProfile> createClient(ClientDraft draft) async {
    final profile = ClientProfile(
      id: 'local-client-${_nextLocalId++}',
      companyName: draft.displayName,
      companyType: draft.companyName.trim().isEmpty
          ? 'Individual client'
          : 'Client',
      fullName: draft.fullName,
      address: draft.address,
      email: draft.email,
      phone: draft.formattedPhone,
      jobCount: 0,
      notes: draft.notes,
      countryIsoCode: draft.countryIsoCode,
      dialingCode: draft.dialingCode,
      nationalPhoneNumber: draft.phoneNumber,
    );
    _clients.insert(0, profile);
    return profile;
  }

  @override
  Future<ClientProfile> updateClient(String id, ClientDraft draft) async {
    final index = _clients.indexWhere((item) => item.id == id);
    if (index < 0) {
      throw StateError('Client is no longer in the demo list');
    }
    final old = _clients[index];
    final updated = ClientProfile(
      id: old.id,
      companyName: draft.displayName,
      companyType: draft.companyName.isEmpty
          ? 'Individual client'
          : old.companyType,
      fullName: draft.fullName,
      email: draft.email,
      phone: draft.formattedPhone,
      jobCount: old.jobCount,
      logoAsset: old.logoAsset,
      address: draft.address,
      notes: draft.notes,
      countryIsoCode: draft.countryIsoCode,
      dialingCode: draft.dialingCode,
      nationalPhoneNumber: draft.phoneNumber,
    );
    _clients[index] = updated;
    return updated;
  }
}
