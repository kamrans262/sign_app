import '../domain/client_draft.dart';
import '../domain/client_profile.dart';

/// Flutter UI depends on this contract, not a particular backend provider.
abstract class ClientRepository {
  Future<List<ClientProfile>> listClients();

  /// Stores an entry in the current repository (in-memory during UI phase).
  Future<ClientProfile> createClient(ClientDraft draft);

  /// Optional for other repository implementations; demo repository supports it.
  Future<ClientProfile> updateClient(String id, ClientDraft draft) =>
      Future<ClientProfile>.error(
        UnsupportedError('Updating clients is not supported'),
      );
}
