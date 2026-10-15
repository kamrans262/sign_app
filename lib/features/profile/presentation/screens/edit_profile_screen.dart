import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/assets/dashboard_assets.dart';
import '../../../../core/services/profile_photo_session.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/dashboard_colors.dart';
import '../../../../core/widgets/sign2digital_header.dart';
import '../../../../core/widgets/sign2digital_input_field.dart';
import '../../../../core/widgets/sign2digital_primary_button.dart';
import '../../../auth/data/account_repository.dart';
import '../../../auth/domain/account_profile.dart';

/// Edits the SAME account record used by the existing sign-up flow.
/// DemoAccountRepository remains session-only; this is not server persistence.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({
    super.key,
    required this.repository,
    this.initialAccount,
    this.imagePicker,
  });

  final AccountRepository repository;
  final AccountProfile? initialAccount;
  final ImagePicker? imagePicker;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  Uint8List? _photo;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final account = widget.initialAccount;
    _name = TextEditingController(text: account?.fullName ?? 'Jean Dupont');
    _email = TextEditingController(
      text: account?.email ?? 'jeandupont@sign2digital.com');
    _phone = TextEditingController(
      text: account?.phoneNumber ?? '78 123 456 78');
    _photo = ProfilePhotoSession.bytes.value;
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _choosePhoto() async {
    try {
      final file = await (widget.imagePicker ?? ImagePicker()).pickImage(
        source: ImageSource.gallery,
        imageQuality: 75,
        maxWidth: 900,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (mounted) setState(() => _photo = bytes);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Unable to access photos on this device.')));
    }
  }

  Future<void> _save() async {
    if (_saving || !(_form.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final original = widget.initialAccount;
      await widget.repository.saveDraft(AccountProfile(
        id: original?.id ?? 'demo-current-account',
        fullName: _name.text.trim(),
        email: _email.text.trim(),
        countryIsoCode: original?.countryIsoCode ?? 'CH',
        dialingCode: original?.dialingCode ?? '+41',
        phoneNumber: _phone.text.trim(),
      ));
      ProfilePhotoSession.setPhoto(_photo);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Unable to save your profile. Please try again.')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.white,
    body: SafeArea(bottom: false, child: Column(children: [
      const Sign2DigitalHeader(title: 'Personal Information'),
      Expanded(child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          key: const Key('profile-edit-scroll'),
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          children: [
            Center(child: Semantics(
              label: 'Change profile photo',
              button: true,
              child: InkWell(
                key: const Key('profile-edit-photo'),
                onTap: _choosePhoto,
                customBorder: const CircleBorder(),
                child: Stack(alignment: Alignment.bottomRight, children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: DashboardColors.paleBlue,
                    backgroundImage: _photo == null
                        ? const AssetImage(DashboardAssets.demoAvatar)
                        : MemoryImage(_photo!),
                  ),
                  const CircleAvatar(
                    radius: 13,
                    backgroundColor: AppColors.primary,
                    child: Icon(Icons.edit, color: Colors.white, size: 14),
                  ),
                ]),
              ),
            )),
            const SizedBox(height: 20),
            Form(
              key: _form,
              child: Column(children: [
                Sign2DigitalInputField(
                  key: const Key('profile-edit-name'),
                  label: 'Full Name',
                  hintText: 'Your name',
                  iconAsset: '',
                  leadingIcon: Icons.person_outline,
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter your name' : null,
                ),
                const SizedBox(height: 15),
                Sign2DigitalInputField(
                  key: const Key('profile-edit-email'),
                  label: 'Email',
                  hintText: 'Your email address',
                  iconAsset: '',
                  leadingIcon: Icons.email_outlined,
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) =>
                      value == null || !value.trim().contains('@')
                          ? 'Enter a valid email' : null,
                ),
                const SizedBox(height: 15),
                Sign2DigitalInputField(
                  key: const Key('profile-edit-phone'),
                  label: 'Phone',
                  hintText: 'Your phone number',
                  iconAsset: '',
                  leadingIcon: Icons.phone_outlined,
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  inputPrefix: Text(widget.initialAccount?.dialingCode ?? '+41',
                    style: const TextStyle(
                      fontFamily: 'Inter', color: AppColors.dark)),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter a phone number' : null,
                ),
              ]),
            ),
            const SizedBox(height: 15),
            const Text('Changes are saved to the current demo session only.',
              style: TextStyle(fontFamily: 'Inter',
                fontSize: 12, color: AppColors.placeholder)),
          ],
        ),
      ))),
    ])),
    bottomNavigationBar: SafeArea(
      top: false,
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
            child: Sign2DigitalPrimaryButton(
              key: const Key('profile-edit-save'),
              label: _saving ? 'Saving...' : 'Save Changes',
              height: 48,
              onPressed: _saving ? () {} : _save,
            ),
          ),
        ),
      ),
    ),
  );
}
