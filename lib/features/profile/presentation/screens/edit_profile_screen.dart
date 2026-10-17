import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/assets/dashboard_assets.dart';
import '../../../../core/services/profile_photo_session.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/dashboard_colors.dart';
import '../../../../core/widgets/sign2digital_bottom_navigation_bar.dart';
import '../../../../core/widgets/sign2digital_country_selector.dart';
import '../../../../core/widgets/sign2digital_header.dart';
import '../../../../core/widgets/sign2digital_input_field.dart';
import '../../../../core/widgets/sign2digital_outlined_button.dart';
import '../../../../core/widgets/sign2digital_primary_button.dart';
import '../../../../core/widgets/sign2digital_selection_field.dart';
import '../../../../core/widgets/sign2digital_selection_sheet.dart';
import '../../../auth/data/account_repository.dart';
import '../../../auth/domain/account_profile.dart';

/// Edits the existing signup account, preserving its identifier and other data.
/// Profile and photo changes are only committed after Save Changes.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({
    super.key,
    required this.repository,
    this.initialAccount,
    this.imagePicker,
    this.pickPhotoBytes,
    this.onNavigationSelected,
    this.availableTitles = const [
      'Project Manager',
      'Site Manager',
      'Director',
      'Administrator',
    ],
  });

  final AccountRepository repository;
  final AccountProfile? initialAccount;
  final ImagePicker? imagePicker;
  /// Optional picker adapter for platform tests and injected gallery sources.
  final Future<Uint8List?> Function()? pickPhotoBytes;
  final ValueChanged<int>? onNavigationSelected;
  /// Display suggestions, not an assumed backend directory of job titles.
  final List<String> availableTitles;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late Sign2DigitalCountry _country;
  String? _title;
  Uint8List? _photo;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final account = widget.initialAccount;
    final fullName = (account?.fullName ?? 'Jean Dupont').trim();
    final divider = fullName.indexOf(' ');
    _firstName = TextEditingController(
      text: divider < 0 ? fullName : fullName.substring(0, divider));
    _lastName = TextEditingController(
      text: divider < 0 ? '' : fullName.substring(divider + 1).trim());
    _email = TextEditingController(
      text: account?.email ?? 'jeandupont@sign2digital.com');
    _phone = TextEditingController(
      text: account?.phoneNumber ?? '78 123 456 78');
    _country = Sign2DigitalCountries.all.firstWhere(
      (item) => item.isoCode == account?.countryIsoCode,
      orElse: () => Sign2DigitalCountries.switzerland,
    );
    _title = account?.title;
    _photo = ProfilePhotoSession.bytes.value;
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _cancel() { Navigator.of(context).maybePop(); }

  Future<void> _choosePhoto() async {
    try {
      if (widget.pickPhotoBytes != null) {
        final bytes = await widget.pickPhotoBytes!();
        if (mounted && bytes != null) setState(() => _photo = bytes);
        return;
      }
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

  Future<void> _chooseTitle() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final options = {...widget.availableTitles, ?_title}
      .where((item) => item.trim().isNotEmpty).toList();
    final choice = await Sign2DigitalSelectionSheet.show(
      context,
      title: 'Job Title',
      subtitle: 'Choose your job title or enter another',
      options: [...options, '__other__'],
      selected: _title,
      icon: Icons.description_outlined,
      labelForOption: (value) =>
          value == '__other__' ? 'Other title...' : value,
      keyForOption: (value) => value == '__other__'
          ? const Key('profile-title-other')
          : Key('profile-title-${value.toLowerCase().replaceAll(' ', '-')}'),
    );
    if (!mounted || choice == null) return;
    if (choice != '__other__') {
      setState(() => _title = choice);
      return;
    }
    // Let TextFormField own its controller until the dialog widget unmounts.
    // Disposing a manual controller when showDialog completes is too early:
    // the exit animation can still rebuild the TextField.
    var draftTitle = _title ?? '';
    final entered = await showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Job Title'),
        content: TextFormField(
          key: const Key('profile-title-custom-input'),
          initialValue: draftTitle,
          autofocus: true,
          onChanged: (value) => draftTitle = value,
          decoration: const InputDecoration(hintText: 'e.g. Project Manager'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            key: const Key('profile-title-custom-save'),
            onPressed: () => Navigator.of(dialog).pop(draftTitle.trim()),
            child: const Text('Use Title'),
          ),
        ],
      ),
    );
    if (mounted && entered != null && entered.isNotEmpty) {
      setState(() => _title = entered);
    }
  }

  Future<void> _save() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_saving || !(_form.currentState?.validate() ?? false)) return;
    setState(() { _saving = true; _error = null; });
    try {
      final original = widget.initialAccount;
      await widget.repository.saveDraft(AccountProfile(
        id: original?.id ?? 'demo-current-account',
        fullName: '${_firstName.text.trim()} ${_lastName.text.trim()}',
        email: _email.text.trim(),
        countryIsoCode: _country.isoCode,
        dialingCode: _country.dialCode,
        phoneNumber: _phone.text.trim(),
        title: _title,
      ));
      ProfilePhotoSession.setPhoto(_photo);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() =>
          _error = 'Unable to save your profile. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _navigation(int index) {
    if (index == 4) {
      _cancel();
      return;
    }
    final callback = widget.onNavigationSelected;
    if (callback == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Navigation is not connected yet.')));
      return;
    }
    // Leaving this unsaved form discards its edits.
    Navigator.of(context).pop(false);
    callback(index);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.white,
    resizeToAvoidBottomInset: true,
    body: SafeArea(bottom: false, child: Column(children: [
      const Sign2DigitalHeader(title: 'Profile'),
      Expanded(child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          key: const Key('profile-edit-scroll'),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          children: [
            Center(child: Column(children: [
              SizedBox(
                width: 110,
                height: 100,
                child: Stack(clipBehavior: Clip.none, children: [
                  Positioned(left: 5, child: CircleAvatar(
                    radius: 50,
                    backgroundColor: DashboardColors.paleBlue,
                    backgroundImage: _photo == null
                        ? const AssetImage(DashboardAssets.demoAvatar)
                        : MemoryImage(_photo!),
                  )),
                  Positioned(
                    right: 0, bottom: 2,
                    child: Material(
                      color: AppColors.primary,
                      shape: const CircleBorder(side: BorderSide(
                        color: AppColors.white, width: 2)),
                      child: InkWell(
                        key: const Key('profile-edit-camera'),
                        onTap: _choosePhoto,
                        customBorder: const CircleBorder(),
                        child: const SizedBox(
                          width: 28, height: 28,
                          child: Icon(Icons.camera_alt_rounded,
                            size: 17, color: AppColors.white),
                        ),
                      ),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 5),
              TextButton(
                key: const Key('profile-edit-photo'),
                onPressed: _choosePhoto,
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 20),
                  padding: EdgeInsets.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: AppColors.primary,
                ),
                child: const Text('Change Photo', style: TextStyle(
                  fontFamily: 'Inter', fontSize: 14,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.3,
                  color: AppColors.primary)),
              ),
            ])),
            const SizedBox(height: 25),
            Form(
              key: _form,
              child: Column(children: [
                Sign2DigitalInputField(
                  key: const Key('profile-edit-first-name'),
                  label: 'First Name',
                  hintText: 'e.g. Marc',
                  iconAsset: '',
                  leadingIcon: Icons.person_outline_rounded,
                  leadingIconSize: 24,
                  controller: _firstName,
                  textCapitalization: TextCapitalization.words,
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter first name' : null,
                ),
                const SizedBox(height: 20),
                Sign2DigitalInputField(
                  key: const Key('profile-edit-last-name'),
                  label: 'Last Name',
                  hintText: 'e.g. Dupont',
                  iconAsset: '',
                  leadingIcon: Icons.person_outline_rounded,
                  leadingIconSize: 24,
                  controller: _lastName,
                  textCapitalization: TextCapitalization.words,
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter last name' : null,
                ),
                const SizedBox(height: 20),
                Sign2DigitalInputField(
                  key: const Key('profile-edit-email'),
                  label: 'E-mail',
                  hintText: 'e.g. Marc@company.ch',
                  iconAsset: '',
                  leadingIcon: Icons.mail_outline_rounded,
                  leadingIconSize: 24,
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) => value == null ||
                      !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim())
                      ? 'Enter a valid e-mail' : null,
                ),
                const SizedBox(height: 20),
                Sign2DigitalInputField(
                  key: const Key('profile-edit-phone'),
                  label: 'Phone',
                  hintText: 'Phone number',
                  iconAsset: '',
                  leadingIcon: Icons.phone_outlined,
                  leadingIconSize: 24,
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  inputPrefix: Sign2DigitalCountrySelector(
                    selected: _country,
                    onChanged: (country) => setState(() => _country = country),
                  ),
                  validator: (value) {
                    final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
                    return digits.length < 5 || digits.length > 15
                        ? 'Enter a valid phone number' : null;
                  },
                ),
                const SizedBox(height: 20),
                Sign2DigitalSelectionField(
                  key: const Key('profile-edit-title'),
                  label: 'Title',
                  hintText: 'e.g. Project Manager',
                  iconAsset: '',
                  leadingIcon: Icons.description_outlined,
                  leadingIconSize: 24,
                  value: _title,
                  trailing: const Icon(Icons.keyboard_arrow_down_rounded,
                    color: AppColors.secondaryText),
                  onTap: _chooseTitle,
                ),
              ]),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, key: const Key('profile-edit-error'),
                style: const TextStyle(color: Color(0xFFB42318))),
            ],
            const SizedBox(height: 25),
            Row(children: [
              Expanded(child: Sign2DigitalOutlinedButton(
                key: const Key('profile-edit-cancel'),
                label: 'Cancel',
                primaryOutline: true,
                onPressed: _cancel,
              )),
              const SizedBox(width: 10),
              Expanded(child: Sign2DigitalPrimaryButton(
                key: const Key('profile-edit-save'),
                label: 'Save Changes',
                loading: _saving,
                onPressed: _save,
              )),
            ]),
          ],
        ),
      ))),
    ])),
    bottomNavigationBar: Sign2DigitalBottomNavigationBar(
      selectedIndex: 4,
      onSelected: _navigation,
    ),
  );
}
