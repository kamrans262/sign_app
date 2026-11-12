import 'package:flutter/material.dart';

import '../../../../core/services/sign_api_client.dart';
import '../../../../core/navigation/sign2digital_navigation.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sign2digital_header.dart';
import '../../../../core/widgets/sign2digital_selection_sheet.dart';
import '../../../../core/widgets/sign2digital_selection_field.dart';
import '../../../../core/widgets/sign2digital_input_field.dart';
import '../../../../core/widgets/sign2digital_primary_button.dart';
import '../../../../core/widgets/sign2digital_outlined_button.dart';
import '../../../quotes/presentation/widgets/sign2digital_quote_shadow_panel.dart';
import '../../data/remote_company_repository.dart';
import 'company_roles_screen.dart';

/// M3 team management built with the approved Sign2Digital header, cards,
/// shared Switch Company bottom sheet and existing primary color.
class CompanyTeamScreen extends StatefulWidget {
  /// Checked by the invite form and the regression suite; owners are implicit.
  static List<String> defaultPermissions(String role) =>
      _CompanyTeamScreenState.defaultPermissions(role);

  /// Presentation-only permission labels; server keys stay unchanged.
  static String permissionLabel(String key) {
    final parts = key.split('.');
    if (parts.length != 2) return key;
    final area = switch (parts[0]) {
      'clients' => 'Client',
      'jobs' => 'Job',
      'documents' => 'Document',
      'quotes' => 'Quote',
      'invoices' => 'Invoice',
      'reports' => 'Report',
      'expenses' => 'Expense',
      'labour' => 'Time & Labour',
      'equipment' => 'Equipment',
      _ => parts[0],
    };
    final action = switch (parts[1]) {
      'read' => 'Read',
      'write' => 'Write',
      _ => parts[1],
    };
    return '$area - $action';
  }

  const CompanyTeamScreen({
    super.key,
    required this.companyId,
    required this.companyName,
    required this.role,
    this.repository,
  });

  final String companyId;
  final String companyName;
  final String role;
  final RemoteCompanyRepository? repository;

  @override
  State<CompanyTeamScreen> createState() => _CompanyTeamScreenState();
}

class _CompanyTeamScreenState extends State<CompanyTeamScreen> {
  late final RemoteCompanyRepository _repo =
      widget.repository ?? RemoteCompanyRepository.shared;
  final TextEditingController _email = TextEditingController();
  List<CompanyMember> _members = [];
  List<CompanyInvite> _invitations = [];
  List<CompanyRole> _roles = [];
  bool _loading = true;
  bool _saving = false;
  String _role = 'member';
  final Set<String> _permissions = <String>{};
  static List<String> defaultPermissions(String role) => role == 'admin'
      ? List<String>.from(permissionOptions)
      : permissionOptions.where((permission) => permission.endsWith('.read') ||
          const ['clients.write', 'jobs.write'].contains(permission)).toList();

  static const permissionOptions = <String>[
    'clients.read', 'clients.write',
    'jobs.read', 'jobs.write',
    'documents.read', 'documents.write',
    'quotes.read', 'quotes.write',
    'invoices.read', 'invoices.write',
    'reports.read', 'reports.write',
    'expenses.read', 'expenses.write',
    'labour.read', 'labour.write',
    'equipment.read', 'equipment.write',
  ];

  bool get _isOwner => widget.role == 'owner';
  int? _customRoleId(String key) => key.startsWith('custom:')
      ? int.tryParse(key.substring(7)) : null;

  CompanyRole? _findRole(int id) {
    for (final role in _roles) {
      if (role.id == id) return role;
    }
    return null;
  }

  String _roleLabel(String value) {
    final id = _customRoleId(value);
    if (id != null) {
      final name = _findRole(id)?.name ?? 'Custom Role';
      return name.isEmpty ? 'Custom Role'
          : '${name[0].toUpperCase()}${name.substring(1)}';
    }
    return value == 'admin' ? 'Admin' : 'Member';
  }

  List<String> get _roleOptions => [
    'member',
    if (_isOwner) 'admin',
    if (_isOwner) for (final role in _roles) 'custom:${role.id}',
  ];
  bool get _canEdit => widget.role == 'owner' || widget.role == 'admin';

  @override
  void initState() {
    super.initState();
    _permissions.addAll(defaultPermissions(_role));
    _load();
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final members = await _repo.members(widget.companyId);
      final roles = _isOwner ? await _repo.roles(widget.companyId)
          : <CompanyRole>[];
      final invites = _canEdit
          ? await _repo.invitations(widget.companyId)
          : <CompanyInvite>[];
      if (!mounted) return;
      setState(() {
        _members = members;
        _roles = roles;
        _invitations = invites;
        if (_customRoleId(_role) != null &&
            !_roles.any((role) => role.id == _customRoleId(_role))) {
          _role = 'member';
          _permissions..clear()..addAll(defaultPermissions('member'));
        } else if (_customRoleId(_role) != null) {
          _permissions..clear()..addAll(_findRole(_customRoleId(_role)!)!.permissions);
        }
      });
    } catch (error) {
      _message(error is SignApiException
          ? error.message : 'Unable to load team members.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _chooseRole() async {
    final selected = await Sign2DigitalSelectionSheet.show(
      context, title: 'Company Role',
      options: _roleOptions, selected: _role, icon: Icons.people_outline,
      labelForOption: _roleLabel,
      iconForOption: (value) => value == 'admin'
          ? Icons.admin_panel_settings_outlined
          : (_customRoleId(value) != null ? Icons.shield_outlined
              : Icons.person_outline_rounded),
    );
    if (selected != null && mounted) setState(() {
      _role = selected;
      final customId = _customRoleId(selected);
      _permissions..clear()..addAll(customId != null
          ? (_findRole(customId)?.permissions ?? const <String>[])
          : defaultPermissions(selected));
    });
  }

  Future<List<String>?> _selectPermissions(Set<String> original) async {
    final selected = Set<String>.from(original);
    final result = await Sign2DigitalSelectionSheet.showCustom<List<String>>(
      context: context,
      title: 'Team Permissions',
      icon: Icons.shield_outlined,
      subtitle: 'Choose access for this team member',
      builder: (sheetContext) => StatefulBuilder(builder: (context, update) =>
        Column(children: [
          Expanded(child: ListView(
            children: [
              for (final permission in permissionOptions)
                CheckboxListTile(
                  key: Key('team-permission-$permission'),
                  title: Text(CompanyTeamScreen.permissionLabel(permission),
                    style: const TextStyle(fontFamily: 'Inter', fontSize: 14,
                      color: AppColors.dark)),
                  activeColor: AppColors.primary,
                  value: selected.contains(permission),
                  onChanged: (value) => update(() {
                    if (value == true) {
                      selected.add(permission);
                      if (permission.endsWith('.write')) {
                        selected.add(permission.replaceFirst('.write', '.read'));
                      }
                    } else {
                      selected.remove(permission);
                      if (permission.endsWith('.read')) {
                        selected.remove(permission.replaceFirst('.read', '.write'));
                      }
                    }
                  }),
                ),
            ],
          )),
          Padding(padding: const EdgeInsets.all(16),
            child: Sign2DigitalPrimaryButton(
              label: 'Apply Permissions',
              onPressed: () => Navigator.of(sheetContext).pop(selected.toList()),
            )),

        ]),
      ),
    );
    return result;
  }

  Future<void> _choosePermissions() async {
    if (_customRoleId(_role) != null) {
      _message('Permissions are managed in Roles & Permissions.');
      return;
    }
    final result = await _selectPermissions(_permissions);
    if (result != null && mounted) {
      setState(() { _permissions..clear()..addAll(result); });
    }
  }

  Future<void> _editPermissions(CompanyMember member) async {
    if (!_canEdit || member.role == 'owner' ||
        member.companyRoleId != null ||
        (!_isOwner && member.role == 'admin')) {
      return;
    }
    final selected = await _selectPermissions(member.permissions.toSet());
    if (selected == null || !mounted) return;
    try {
      await _repo.updateMember(widget.companyId, member.id, member.role,
        permissions: selected);
      await _load();
      _message('Member permissions updated.');
    } catch (error) {
      _message(error is SignApiException
          ? error.message : 'Unable to update permissions.');
    }
  }

  Future<void> _invite() async {
    if (_saving || !_canEdit) return;
    final email = _email.text.trim();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      _message('Enter a valid team member email.');
      return;
    }
    setState(() => _saving = true);
    try {
      final customId = _customRoleId(_role);
      await _repo.invite(widget.companyId, email,
        role: customId == null ? _role : 'member',
        companyRoleId: customId,
        permissions: customId == null ? _permissions.toList() : const []);
      _email.clear();
      setState(() { _role = 'member';
        _permissions..clear()..addAll(defaultPermissions('member')); });
      _message('Company invitation sent by email.');
      await _load();
    } catch (error) {
      _message(error is SignApiException
          ? error.message : 'Unable to invite this member.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _memberActions(CompanyMember member) async {
    final choice = await Sign2DigitalSelectionSheet.show(
      context,
      title: 'Member Actions',
      options: [
        'Change Role',
        if (member.companyRoleId == null) 'Edit Permissions',
        'Remove',
      ],
      icon: Icons.manage_accounts_outlined,
    );
    if (!mounted) return;
    if (choice == 'Change Role') await _changeRole(member);
    if (choice == 'Edit Permissions') await _editPermissions(member);
    if (choice == 'Remove') await _remove(member);
  }

  Future<void> _changeRole(CompanyMember member) async {
    if (!_canEdit || member.role == 'owner' ||
        (!_isOwner && (member.role == 'admin' ||
          member.companyRoleId != null))) return;
    final current = member.companyRoleId == null
        ? member.role : 'custom:${member.companyRoleId}';
    final role = await Sign2DigitalSelectionSheet.show(
      context, title: 'Change Team Role',
      options: _roleOptions, labelForOption: _roleLabel,
      selected: current, icon: Icons.manage_accounts_outlined,
    );
    if (role == null || !mounted || role == current) return;
    final customId = _customRoleId(role);
    // Standard-role grants can still be individually customized.
    // Custom role permissions always come from the saved owner-defined role.
    final grants = customId == null
        ? await _selectPermissions(defaultPermissions(role).toSet()) : null;
    if (customId == null && grants == null || !mounted) return;
    try {
      await _repo.updateMember(widget.companyId, member.id,
        customId == null ? role : 'member',
        companyRoleId: customId,
        permissions: grants ?? const []);
      await _load();
      _message('Team member updated.');
    } catch (error) {
      _message(error is SignApiException ? error.message : 'Unable to update team member.');
    }
  }

  Future<bool> _confirm(String title) async {
    final result = await Sign2DigitalSelectionSheet.showCustom<bool>(
      context: context,
      title: title,
      icon: Icons.warning_amber_rounded,
      subtitle: 'This change affects company access immediately',
      builder: (sheet) => Padding(
        padding: const EdgeInsets.all(20),
        child: Row(children: [
          Expanded(child: Sign2DigitalOutlinedButton(
            label: 'Cancel',
            primaryOutline: true,
            onPressed: () => Navigator.pop(sheet, false),
          )),
          const SizedBox(width: 10),
          Expanded(child: Sign2DigitalPrimaryButton(
            label: 'Confirm',
            onPressed: () => Navigator.pop(sheet, true),
          )),
        ]),
      ),
    );
    return result == true;
  }

  Future<void> _remove(CompanyMember member) async {
    if (!_canEdit || member.role == 'owner' ||
        (!_isOwner && (member.role == 'admin' ||
            member.companyRoleId != null))) return;
    if (!await _confirm('Remove team member?')) return;
    try {
      await _repo.removeMember(widget.companyId, member.id);
      await _load();
      _message('Team member removed.');
    } catch (error) {
      _message(error is SignApiException ? error.message : 'Unable to remove team member.');
    }
  }

  Future<void> _revoke(CompanyInvite invitation) async {
    if (!await _confirm('Revoke invitation?')) return;
    try {
      await _repo.revokeInvite(widget.companyId, invitation.id);
      await _load();
      _message('Invitation revoked.');
    } catch (error) {
      _message(error is SignApiException ? error.message : 'Unable to revoke invitation.');
    }
  }

  Future<void> _manageRoles() async {
    if (!_isOwner) return;
    await Sign2DigitalNavigation.push<void>(context,
      MaterialPageRoute<void>(builder: (_) => CompanyRolesScreen(
        companyId: widget.companyId, repository: _repo)));
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.white,
    body: SafeArea(child: Column(children: [
      Sign2DigitalHeader(title: 'Team Members'),
      Expanded(child: Center(child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth:
            MediaQuery.orientationOf(context) == Orientation.landscape
                ? double.infinity : 720),
        child: ListView(
          key: const Key('company-team-scroll'),
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 25),
          children: [
            if (_isOwner) ...[
              Sign2DigitalQuoteShadowPanel(
                padding: const EdgeInsets.all(20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Roles & Permissions', style: TextStyle(
                      fontFamily: 'Inter', fontSize: 16,
                      fontWeight: FontWeight.w600, color: AppColors.dark)),
                    const SizedBox(height: 10),
                    const Text('Create reusable roles and assign permissions to your team.',
                      style: TextStyle(fontFamily: 'Inter', fontSize: 14,
                        color: AppColors.secondaryText)),
                    const SizedBox(height: 15),
                    Sign2DigitalOutlinedButton(
                      key: const Key('company-manage-roles'),
                      label: 'Manage Roles',
                      primaryOutline: true,
                      onPressed: _manageRoles),
                  ]),
              ),
              const SizedBox(height: 20),
            ],
            if (_canEdit) ...[
              Sign2DigitalQuoteShadowPanel(
                padding: const EdgeInsets.all(20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const Text('Invite Team Member', style: TextStyle(
                    fontFamily: 'Inter', fontWeight: FontWeight.w600,
                    fontSize: 16, color: AppColors.dark)),
                  const SizedBox(height: 15),
                  Sign2DigitalInputField(
                    key: const Key('company-invite-email'),
                    controller: _email,
                    label: 'Email Address',
                    hintText: 'team@example.com',
                    iconAsset: '',
                    leadingIcon: Icons.mail_outline_rounded,
                    leadingIconSize: 24,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                  ),
                  const SizedBox(height: 12),
                  Sign2DigitalSelectionField(
                    key: const Key('company-role-picker'),
                    label: 'Role',
                    value: 'Role: ${_roleLabel(_role)}',
                    hintText: 'Select team role',
                    iconAsset: '',
                    leadingIcon: Icons.people_outline,
                    leadingIconSize: 24,
                    trailing: const Icon(Icons.keyboard_arrow_down_rounded,
                      size: 24, color: AppColors.secondaryText),
                    onTap: _chooseRole,
                  ),
                  const SizedBox(height: 12),
                  Sign2DigitalSelectionField(
                    key: const Key('company-permissions-picker'),
                    label: 'Permissions',
                    value: _customRoleId(_role) != null
                        ? 'Inherited from role (${_permissions.length})'
                        : 'Permissions (${_permissions.length})',
                    hintText: 'Choose team permissions',
                    iconAsset: '',
                    leadingIcon: Icons.shield_outlined,
                    leadingIconSize: 24,
                    trailing: const Icon(Icons.keyboard_arrow_down_rounded,
                      size: 24, color: AppColors.secondaryText),
                    onTap: _choosePermissions,
                  ),
                  const SizedBox(height: 15),
                  Sign2DigitalPrimaryButton(
                    key: const Key('company-send-invite'),
                    label: 'Send Invitation',
                    loading: _saving,
                    onPressed: _invite,
                  ),
                ]),
              ),
              const SizedBox(height: 20),
            ],
            Sign2DigitalQuoteShadowPanel(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Team Members', style: TextStyle(
                  fontFamily: 'Inter', fontWeight: FontWeight.w600,
                  fontSize: 16, color: AppColors.dark)),
                const SizedBox(height: 12),
                if (_loading) const Center(child: CircularProgressIndicator())
                else if (_members.isEmpty) const Text('No company members yet.')
                else for (final member in _members) ...[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(member.name),
                    subtitle: Text('${member.email} · ${member.roleName}'),
                    trailing: _canEdit && member.role != 'owner' &&
                        (_isOwner || (member.role == 'member' &&
                          member.companyRoleId == null))
                        ? IconButton(
                            key: Key('member-actions-${member.id}'),
                            icon: const Icon(Icons.more_vert_rounded),
                            onPressed: () => _memberActions(member),
                          )
                        : null,
                  ),
                  const Divider(height: 1),
                ],
              ]),
            ),
            if (_canEdit) ...[
              const SizedBox(height: 20),
              Sign2DigitalQuoteShadowPanel(
                padding: const EdgeInsets.all(20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Invitations', style: TextStyle(
                    fontFamily: 'Inter', fontWeight: FontWeight.w600,
                    fontSize: 16, color: AppColors.dark)),
                  const SizedBox(height: 12),
                  if (_invitations.isEmpty) const Text('No invitations yet.')
                  else for (final invitation in _invitations)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(invitation.email),
                      subtitle: Text('${invitation.roleName} · ${invitation.status}'),
                      trailing: invitation.status == 'pending'
                          ? IconButton(
                              icon: const Icon(Icons.cancel_outlined,
                                color: AppColors.primary),
                              onPressed: () => _revoke(invitation),
                            ) : null,
                    ),
                ]),
              ),
            ],
          ],
        ),
      ))),
    ])),
  );
}
