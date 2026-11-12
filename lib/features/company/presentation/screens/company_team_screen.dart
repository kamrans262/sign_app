import 'package:flutter/material.dart';

import '../../../../core/services/sign_api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sign2digital_header.dart';
import '../../../../core/widgets/sign2digital_selection_sheet.dart';
import '../../../../core/widgets/sign2digital_selection_field.dart';
import '../../../../core/widgets/sign2digital_input_field.dart';
import '../../../../core/widgets/sign2digital_primary_button.dart';
import '../../../../core/widgets/sign2digital_outlined_button.dart';
import '../../../quotes/presentation/widgets/sign2digital_quote_shadow_panel.dart';
import '../../data/remote_company_repository.dart';

/// M3 team management built with the approved Sign2Digital header, cards,
/// shared Switch Company bottom sheet and existing primary color.
class CompanyTeamScreen extends StatefulWidget {
  /// Presentation-only permission labels; server keys stay unchanged.
  static String permissionLabel(String key) {
    final parts = key.split('.');
    if (parts.length != 2) return key;
    final area = switch (parts[0]) {
      'clients' => 'Clients',
      'jobs' => 'Jobs',
      'documents' => 'Documents',
      'quotes' => 'Quotes',
      'invoices' => 'Invoices',
      'reports' => 'Reports',
      'expenses' => 'Expenses',
      'labour' => 'Time & Labour',
      'equipment' => 'Equipment',
      _ => parts[0],
    };
    final action = switch (parts[1]) {
      'read' => 'View',
      'write' => 'Manage',
      _ => parts[1],
    };
    return '$action $area';
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
  bool get _canEdit => widget.role == 'owner' || widget.role == 'admin';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void initState() {
    super.initState();
    _permissions.addAll(defaultPermissions(_role));
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
      final invites = _canEdit
          ? await _repo.invitations(widget.companyId)
          : <CompanyInvite>[];
      if (!mounted) return;
      setState(() {
        _members = members;
        _invitations = invites;
      });
    } catch (error) {
      _message(error is SignApiException
          ? error.message : 'Unable to load team members.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _chooseRole() async {
    final choices = _isOwner ? ['member', 'admin'] : ['member'];
    final selected = await Sign2DigitalSelectionSheet.show(
      context, title: 'Company role',
      options: choices, selected: _role, icon: Icons.people_outline,
      iconForOption: (role) => role == 'admin'
          ? Icons.admin_panel_settings_outlined
          : Icons.person_outline_rounded,
    );
    if (selected != null && mounted) setState(() {
      _role = selected;
      _permissions..clear()..addAll(defaultPermissions(selected));
    });
  }

  Future<List<String>?> _selectPermissions(Set<String> original) async {
    final selected = Set<String>.from(original);
    final result = await Sign2DigitalSelectionSheet.showCustom<List<String>>(
      context: context,
      title: 'Team permissions',
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
    final result = await _selectPermissions(_permissions);
    if (result != null && mounted) {
      setState(() { _permissions..clear()..addAll(result); });
    }
  }

  Future<void> _editPermissions(CompanyMember member) async {
    if (!_canEdit || member.role == 'owner' ||
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
      await _repo.invite(widget.companyId, email, role: _role,
        permissions: _permissions.toList());
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
      title: 'Member actions',
      options: const ['Change Role', 'Edit Permissions', 'Remove'],
      icon: Icons.manage_accounts_outlined,
    );
    if (!mounted) return;
    if (choice == 'Change Role') await _changeRole(member);
    if (choice == 'Edit Permissions') await _editPermissions(member);
    if (choice == 'Remove') await _remove(member);
  }

  Future<void> _changeRole(CompanyMember member) async {
    if (!_canEdit || member.role == 'owner' || (!_isOwner && member.role == 'admin')) {
      return;
    }
    final role = await Sign2DigitalSelectionSheet.show(
      context, title: 'Change team role',
      options: _isOwner ? ['member', 'admin'] : ['member'],
      selected: member.role, icon: Icons.manage_accounts_outlined,
    );
    if (role == null || !mounted) return;
    try {
      await _repo.updateMember(widget.companyId, member.id, role,
        permissions: member.permissions);
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
    if (!_canEdit || member.role == 'owner' || (!_isOwner && member.role == 'admin')) return;
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
            Text(widget.companyName, style: const TextStyle(fontFamily: 'Inter',
              fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.dark)),
            const SizedBox(height: 20),
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
                    value: 'Role: $_role',
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
                    value: 'Permissions (${_permissions.length})',
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
                    subtitle: Text('${member.email} · ${member.role}'),
                    trailing: _canEdit && member.role != 'owner' &&
                        (_isOwner || member.role == 'member')
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
                      subtitle: Text('${invitation.role} · ${invitation.status}'),
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
