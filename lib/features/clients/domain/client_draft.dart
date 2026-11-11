import 'package:flutter/foundation.dart';

/// Values entered locally before a client is submitted to a repository.
/// Keeps the national phone number separate from its dialing code.
@immutable
class ClientDraft {
  const ClientDraft({
    this.requestKey,
    required this.fullName,
    required this.companyName,
    required this.address,
    required this.countryIsoCode,
    required this.dialingCode,
    required this.phoneNumber,
    required this.email,
    required this.notes,
  });

  /// Stable for retries of one new client, not used on updates.
  final String? requestKey;
  final String fullName;
  final String companyName;
  final String address;
  final String countryIsoCode;
  final String dialingCode;
  final String phoneNumber;
  final String email;
  final String notes;

  String get displayName => companyName.trim().isEmpty ? fullName : companyName;
  String get formattedPhone =>
      phoneNumber.isEmpty ? '' : '$dialingCode $phoneNumber';
}
