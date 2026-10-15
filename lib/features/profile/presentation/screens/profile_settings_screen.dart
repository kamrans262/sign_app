import 'package:flutter/material.dart';

import '../../../../core/assets/dashboard_assets.dart';
import '../../../../core/services/profile_photo_session.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/dashboard_colors.dart';
import '../../../../core/widgets/sign2digital_bottom_navigation_bar.dart';
import '../../../../core/widgets/sign2digital_dashboard_header.dart';
import '../../../auth/data/account_repository.dart';
import '../../../auth/data/demo_account_repository.dart';
import '../../../auth/domain/account_profile.dart';
import '../../../quotes/presentation/widgets/sign2digital_quote_shadow_panel.dart';
import '../widgets/profile_settings_action_card.dart';
import 'edit_profile_screen.dart';
import 'profile_sections_screen.dart';

/// Profile entry point for More and the dashboard avatar.
/// Reads the existing session account, never an independent profile fixture.
class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({
    super.key,
    this.accountRepository,
    this.onNotificationTap,
    this.onNavigationSelected,
    this.onBusinessInformation,
    this.onPreferences,
    this.onSecurity,
    this.onAppSettings,
  });

  final AccountRepository? accountRepository;
  final VoidCallback? onNotificationTap;
  final ValueChanged<int>? onNavigationSelected;
  final VoidCallback? onBusinessInformation;
  final VoidCallback? onPreferences;
  final VoidCallback? onSecurity;
  final VoidCallback? onAppSettings;

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  late final AccountRepository _repository;
  AccountProfile? _account;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repository = widget.accountRepository ?? DemoAccountRepository.shared;
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() { _loading = true; _error = null; });
    try {
      final account = await _repository.currentAccount();
      if (!mounted) return;
      setState(() { _account = account; _loading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _error = 'Unable to load profile.'; _loading = false; });
    }
  }

  Future<void> _edit() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => EditProfileScreen(
        repository: _repository,
        initialAccount: _account,
      )),
    );
    if (changed == true && mounted) await _load();
  }

  void _open(Widget destination) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => destination));
  }

  void _showUnavailable(String action) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('$action is not connected yet.')));
  }

  void _navigate(int index) {
    if (index == 4) {
      Navigator.of(context).maybePop();
      return;
    }
    final callback = widget.onNavigationSelected;
    if (callback == null) {
      _showUnavailable('Navigation');
      return;
    }
    Navigator.of(context).maybePop();
    callback(index);
  }

  void _business() {
    if (widget.onBusinessInformation != null) {
      widget.onBusinessInformation!();
      return;
    }
    _open(const ProfileBusinessInformationScreen());
  }

  void _section(String title, String description, VoidCallback? callback) {
    if (callback != null) { callback(); return; }
    _open(ProfileSectionUnavailableScreen(
      title: title,
      details: description,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final account = _account;
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(bottom: false, child: Column(children: [
        Sign2DigitalDashboardHeader(
          onNotificationTap: widget.onNotificationTap ??
              () => _showUnavailable('Notifications'),
          onProfileTap: _edit,
        ),
        Expanded(child: Center(child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              key: const Key('profile-settings-scroll'),
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              children: [
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.only(top: 30),
                    child: Center(child: CircularProgressIndicator()))
                else if (_error != null)
                  Center(child: TextButton(
                    key: const Key('profile-settings-retry'),
                    onPressed: _load,
                    child: Text('$_error Tap to retry.')))
                else ...[
                  _profileCard(account),
                  const SizedBox(height: 20),
                  ProfileSettingsActionCard(
                    key: const Key('profile-action-personal'),
                    icon: Icons.manage_accounts_outlined,
                    title: 'Personal Information',
                    subtitle: 'Name, email, phone and photo',
                    onTap: _edit,
                  ),
                  const SizedBox(height: 20),
                  ProfileSettingsActionCard(
                    key: const Key('profile-action-business'),
                    icon: Icons.info_outline_rounded,
                    title: 'Business Information',
                    subtitle: 'Company, address and tax details',
                    onTap: _business,
                  ),
                  const SizedBox(height: 20),
                  ProfileSettingsActionCard(
                    key: const Key('profile-action-preferences'),
                    icon: Icons.tune_rounded,
                    title: 'Preferences',
                    subtitle: 'Language, data, time and notification',
                    onTap: () => _section('Preferences',
                      'Language, date, time and notification settings '
                      'are not connected to user preferences yet.',
                      widget.onPreferences),
                  ),
                  const SizedBox(height: 20),
                  ProfileSettingsActionCard(
                    key: const Key('profile-action-security'),
                    icon: Icons.shield_outlined,
                    title: 'Security & Access',
                    subtitle: 'Password, and active sessions',
                    onTap: () => _section('Security & Access',
                      'Secure password and active-session management '
                      'require an authenticated backend connection.',
                      widget.onSecurity),
                  ),
                  const SizedBox(height: 20),
                  ProfileSettingsActionCard(
                    key: const Key('profile-action-app-settings'),
                    icon: Icons.settings_outlined,
                    title: 'App Settings',
                    subtitle: 'Appearance, units and default',
                    onTap: () => _section('App Settings',
                      'Appearance, units and default settings '
                      'are not connected to persistent application preferences.',
                      widget.onAppSettings),
                  ),
                ],
              ],
            ),
          ),
        ))),
      ])),
      bottomNavigationBar: Sign2DigitalBottomNavigationBar(
        selectedIndex: 4, onSelected: _navigate),
    );
  }

  Widget _profileCard(AccountProfile? account) {
    final name = account?.fullName ?? 'Jean Dupont';
    final email = account?.email ?? 'jeandupont@sign2digital.com';
    final phone = account == null
        ? '+41 78 123 456 78'
        : '${account.dialingCode} ${account.phoneNumber}';
    return Sign2DigitalQuoteShadowPanel(
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          ValueListenableBuilder(
            valueListenable: ProfilePhotoSession.bytes,
            builder: (context, photo, child) => CircleAvatar(
              radius: 25,
              backgroundColor: DashboardColors.paleBlue,
              backgroundImage: photo == null
                  ? const AssetImage(DashboardAssets.demoAvatar)
                  : MemoryImage(photo),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name,
                key: const Key('profile-display-name'),
                maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Inter', fontSize: 18,
                  fontWeight: FontWeight.w600, letterSpacing: -0.3,
                  color: AppColors.dark)),
              const SizedBox(height: 5),
              Text(email,
                key: const Key('profile-display-email'),
                maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Inter', fontSize: 12,
                  fontWeight: FontWeight.w400, letterSpacing: -0.3,
                  color: AppColors.placeholder)),
              const SizedBox(height: 5),
              Text(phone,
                key: const Key('profile-display-phone'),
                maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Inter', fontSize: 12,
                  fontWeight: FontWeight.w400, letterSpacing: -0.3,
                  color: AppColors.placeholder)),
            ],
          )),
          const SizedBox(width: 5),
          Align(
            alignment: Alignment.topRight,
            child: IconButton(
              key: const Key('profile-edit'),
              tooltip: 'Edit profile',
              onPressed: _edit,
              icon: const Icon(Icons.edit_outlined,
                color: AppColors.primary, size: 24),
            ),
          ),
        ]),
        if (account == null) ...[
          const SizedBox(height: 8),
          const Text('Demo preview · No account profile is connected.',
            key: Key('profile-demo-notice'),
            style: TextStyle(
              fontFamily: 'Inter', fontSize: 11,
              color: AppColors.placeholder)),
        ],
      ]),
    );
  }
}
