import '../models/import_contact_model.dart';
import '../../../core/assets/dashboard_assets.dart';

/// Demo records, not read from the user's device or a backend.
List<ImportContactModel> buildDemoImportContacts() => List.generate(
  6,
  (index) => ImportContactModel(
    id: 'demo-import-contact-${index + 1}',
    fullName: 'Jean Dupont',
    phoneNumber: '044 123 44 55',
    email: 'dummymail@gmail.com',
    avatarAsset: DashboardAssets.demoAvatar,
    isSelected: index != 1,
  ),
);
