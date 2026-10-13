/// Backend-neutral, non-secret information entered during signup.
/// Passwords are deliberately excluded from the demo data model.
class AccountProfile {
  AccountProfile({
    required this.id,
    required this.fullName,
    required this.email,
    required this.countryIsoCode,
    required this.dialingCode,
    required this.phoneNumber,
  });

  final String id;
  final String fullName;
  final String email;
  final String countryIsoCode;
  final String dialingCode;
  final String phoneNumber;
}
