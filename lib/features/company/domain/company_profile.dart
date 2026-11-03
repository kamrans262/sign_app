/// A backend-neutral company profile. Files are represented by names only;
/// actual uploads are deliberately deferred until there is a secured API.
class CompanyProfile {
  CompanyProfile({
    required this.id,
    required this.companyName,
    required this.address,
    required this.countryIsoCode,
    required this.dialingCode,
    required this.phoneNumber,
    required this.email,
    required this.swissCompanyId,
    required this.vatNumber,
    required this.iban,
    required this.qrIban,
    required this.documentNumbering,
    this.role = 'member',
    this.logoFileName,
    this.termsFileName,
  });

  final String role;
  final String id;
  final String companyName;
  final String address;
  final String countryIsoCode;
  final String dialingCode;
  final String phoneNumber;
  final String email;
  final String swissCompanyId;
  final String vatNumber;
  final String iban;
  final String qrIban;
  final String documentNumbering;
  final String? logoFileName;
  final String? termsFileName;
}
