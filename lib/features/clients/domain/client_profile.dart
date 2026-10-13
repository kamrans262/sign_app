import 'package:flutter/foundation.dart';

@immutable
class ClientProfile {
  const ClientProfile({
    required this.id,
    required this.companyName,
    required this.companyType,
    required this.email,
    required this.phone,
    required this.jobCount,
    this.logoAsset,
    this.fullName = '',
    this.address = '',
    this.notes = '',
    this.countryIsoCode = '',
    this.dialingCode = '',
    this.nationalPhoneNumber = '',
  });

  final String id;
  final String companyName;
  final String companyType;
  final String email;
  final String phone;
  final int jobCount;
  final String? logoAsset;
  final String fullName;
  final String address;
  final String notes;
  final String countryIsoCode;
  final String dialingCode;
  final String nationalPhoneNumber;

  String get initials {
    final words = companyName.trim().split(RegExp(r'\s+'));
    if (words.isEmpty || words.first.isEmpty) return '?';
    return words.take(2).map((word) => word[0].toUpperCase()).join();
  }

  bool matches(String query) {
    final term = query.trim().toLowerCase();
    if (term.isEmpty) return true;
    return [
      companyName,
      companyType,
      email,
      phone,
      fullName,
      address,
    ].any((field) => field.toLowerCase().contains(term));
  }
}
