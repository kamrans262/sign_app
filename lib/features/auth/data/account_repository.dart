import '../domain/account_profile.dart';

/// A future API implementation can replace the demo version without editing UI.
abstract class AccountRepository {
  Future<void> saveDraft(AccountProfile profile);
  Future<AccountProfile?> currentAccount();
}
