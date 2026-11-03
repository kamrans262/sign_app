import 'package:flutter_contacts/flutter_contacts.dart';

import '../models/import_contact_model.dart';

/// Only reads the phone address book after a deliberate user action.
/// Never syncs or transmits any contacts without a subsequent review/confirm.
abstract class PhoneContactSource {
  Future<List<ImportContactModel>> load();
}

class DevicePhoneContactSource implements PhoneContactSource {
  const DevicePhoneContactSource();

  @override
  Future<List<ImportContactModel>> load() async {
    final status = await FlutterContacts.permissions.request(PermissionType.read);
    if (status != PermissionStatus.granted) {
      throw StateError('Contacts access was not granted. You can add clients manually.');
    }
    final contacts = await FlutterContacts.getAll(properties: {
      ContactProperty.name,
      ContactProperty.phone,
      ContactProperty.email,
    });
    final result = <ImportContactModel>[];
    for (final contact in contacts) {
      final fullName = (contact.displayName ?? '').trim();
      if (fullName.isEmpty) continue;
      result.add(ImportContactModel(
        id: contact.id ?? 'contact-${result.length}',
        fullName: fullName,
        phoneNumber: contact.phones.isNotEmpty
            ? contact.phones.first.number.trim() : '',
        email: contact.emails.isNotEmpty
            ? contact.emails.first.address.trim() : '',
        isSelected: false,
      ));
    }
    result.sort((a, b) => a.fullName.toLowerCase()
        .compareTo(b.fullName.toLowerCase()));
    return result;
  }
}
