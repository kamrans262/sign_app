import '../domain/account_profile.dart';
import 'account_repository.dart';

/// Session-only, non-persistent fake data. No authentication takes place.
class DemoAccountRepository implements AccountRepository {
  DemoAccountRepository();

  static final DemoAccountRepository shared = DemoAccountRepository();
  AccountProfile? _current;

  @override
  Future<void> saveDraft(AccountProfile profile) async {
    _current = profile;
  }

  @override
  Future<AccountProfile?> currentAccount() async => _current;
}
