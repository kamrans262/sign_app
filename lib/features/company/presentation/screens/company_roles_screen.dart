import 'package:flutter/material.dart';

import '../../../../core/services/sign_api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sign2digital_header.dart';
import '../../../../core/widgets/sign2digital_input_field.dart';
import '../../../../core/widgets/sign2digital_selection_sheet.dart';
import '../../../../core/widgets/sign2digital_primary_button.dart';
import '../../../../core/widgets/sign2digital_outlined_button.dart';
import '../../../quotes/presentation/widgets/sign2digital_quote_shadow_panel.dart';
import '../../data/remote_company_repository.dart';
import 'company_team_screen.dart';

class _RoleDraft {
  const _RoleDraft(this.name, this.permissions);
  final String name;
  final List<String> permissions;
}

/// Company owner role definitions. Reuses the approved team cards and sheets;
/// backend authorization still determines who may make any change.
class CompanyRolesScreen extends StatefulWidget {
  const CompanyRolesScreen({super.key, required this.companyId, this.repository});
  final String companyId;
  final RemoteCompanyRepository? repository;

  @override
  State<CompanyRolesScreen> createState() => _CompanyRolesScreenState();
}

class _CompanyRolesScreenState extends State<CompanyRolesScreen> {
  late final RemoteCompanyRepository _repo =
      widget.repository ?? RemoteCompanyRepository.shared;
  List<CompanyRole> _roles = const [];
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final roles = await _repo.roles(widget.companyId);
      if (mounted) setState(() => _roles = roles);
    } catch (error) {
      _notify(error is SignApiException ? error.message : 'Unable to load roles.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<_RoleDraft?> _editor(CompanyRole? role) async {
    final name = TextEditingController(text: role?.name ?? '');
    final selected = Set<String>.from(role?.permissions ?? const <String>[]);
    try {
      return await Sign2DigitalSelectionSheet.showCustom<_RoleDraft>(
        context: context,
        title: role == null ? 'Create Role' : 'Edit Role',
        icon: Icons.shield_outlined,
        subtitle: 'Assign View or Manage access to each module',
        builder: (sheet) => StatefulBuilder(builder: (context, update) =>
          Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Sign2DigitalInputField(
                key: const Key('custom-role-name'),
                label: 'Role Name',
                hintText: 'e.g. Project Supervisor',
                controller: name,
                iconAsset: '',
                leadingIcon: Icons.badge_outlined,
                leadingIconSize: 24,
              ),
            ),
            Expanded(child: ListView(
              key: const Key('custom-role-permission-list'),
              children: [
                for (final key in const [
                  'clients.read', 'clients.write', 'jobs.read', 'jobs.write',
                  'documents.read', 'documents.write',
                  'quotes.read', 'quotes.write', 'invoices.read', 'invoices.write',
                  'reports.read', 'reports.write', 'expenses.read', 'expenses.write',
                  'labour.read', 'labour.write', 'equipment.read', 'equipment.write',
                ])
                  CheckboxListTile(
                    key: Key('custom-role-permission-$key'),
                    title: Text(CompanyTeamScreen.permissionLabel(key),
                      style: const TextStyle(fontFamily: 'Inter',
                        fontSize: 14, color: AppColors.dark)),
                    activeColor: AppColors.primary,
                    value: selected.contains(key),
                    onChanged: (checked) => update(() {
                      if (checked == true) {
                        selected.add(key);
                        if (key.endsWith('.write')) {
                          selected.add(key.replaceFirst('.write', '.read'));
                        }
                      } else {
                        selected.remove(key);
                        if (key.endsWith('.read')) {
                          selected.remove(key.replaceFirst('.read', '.write'));
                        }
                      }
                    }),
                  ),
              ],
            )),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Sign2DigitalPrimaryButton(
                key: const Key('custom-role-save'),
                label: role == null ? 'Create Role' : 'Save Role',
                onPressed: () {
                  final value = name.text.trim();
                  if (value.length < 2 || value.length > 60) {
                    ScaffoldMessenger.of(sheet).showSnackBar(const SnackBar(
                      content: Text('Enter a role name of 2–60 characters.')));
                    return;
                  }
                  Navigator.of(sheet).pop(_RoleDraft(value, selected.toList()));
                },
              ),
            ),
          ]),
        ),
      );
    } finally {
      name.dispose();
    }
  }

  Future<void> _save(CompanyRole? existing) async {
    if (_saving) return;
    final draft = await _editor(existing);
    if (draft == null || !mounted) return;
    setState(() => _saving = true);
    try {
      if (existing == null) {
        await _repo.createRole(widget.companyId, draft.name, draft.permissions);
      } else {
        await _repo.updateRole(widget.companyId, existing.id,
          draft.name, draft.permissions);
      }
      await _load();
      _notify(existing == null ? 'Role created.' :
          'Role updated for all assigned members.');
    } catch (error) {
      _notify(error is SignApiException ? error.message : 'Unable to save role.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete(CompanyRole role) async {
    if (_saving) return;
    final confirmed = await Sign2DigitalSelectionSheet.showCustom<bool>(
      context: context,
      title: 'Delete Role?',
      icon: Icons.warning_amber_rounded,
      subtitle: 'Reassign members and revoke pending invitations before deleting this role.',
      builder: (sheet) => Padding(
        padding: const EdgeInsets.all(20),
        child: Row(children: [
          Expanded(child: Sign2DigitalOutlinedButton(
            label: 'Cancel', primaryOutline: true,
            onPressed: () => Navigator.of(sheet).pop(false))),
          const SizedBox(width: 10),
          Expanded(child: Sign2DigitalPrimaryButton(
            label: 'Delete Role',
            onPressed: () => Navigator.of(sheet).pop(true))),
        ]),
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await _repo.deleteRole(widget.companyId, role.id);
      await _load();
      _notify('Role deleted.');
    } catch (error) {
      _notify(error is SignApiException ? error.message :
          'This role cannot be deleted while assigned.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _actions(CompanyRole role) async {
    if (_saving) return;
    final action = await Sign2DigitalSelectionSheet.show(
      context,
      title: role.name,
      icon: Icons.manage_accounts_outlined,
      options: const ['Edit Role', 'Delete Role'],
    );
    if (!mounted) return;
    if (action == 'Edit Role') await _save(role);
    if (action == 'Delete Role') await _delete(role);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.white,
    body: SafeArea(child: Column(children: [
      const Sign2DigitalHeader(title: 'Roles & Permissions'),
      Expanded(child: Center(child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth:
            MediaQuery.orientationOf(context) == Orientation.landscape
                ? double.infinity : 720),
        child: ListView(
          key: const Key('company-roles-scroll'),
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 25),
          children: [
            Sign2DigitalQuoteShadowPanel(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Company Roles', style: TextStyle(
                    fontFamily: 'Inter', fontSize: 18,
                    fontWeight: FontWeight.w600, color: AppColors.dark)),
                  const SizedBox(height: 10),
                  const Text('Create reusable roles with View and Manage permissions. Changes to a role update access for every assigned member.',
                    style: TextStyle(fontFamily: 'Inter', fontSize: 14,
                      color: AppColors.secondaryText)),
                  const SizedBox(height: 15),
                  Sign2DigitalPrimaryButton(
                    key: const Key('company-create-role'),
                    label: 'Create Role',
                    enabled: !_saving,
                    onPressed: () => _save(null),
                  ),
                ]),
            ),
            const SizedBox(height: 20),
            Sign2DigitalQuoteShadowPanel(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Saved Roles', style: TextStyle(
                    fontFamily: 'Inter', fontSize: 16,
                    fontWeight: FontWeight.w600, color: AppColors.dark)),
                  const SizedBox(height: 12),
                  if (_loading)
                    const Center(child: CircularProgressIndicator())
                  else if (_roles.isEmpty)
                    const Text('No custom roles yet.')
                  else for (final role in _roles) ...[
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(role.name),
                      subtitle: Text('${role.permissions.length} permissions · '
                        '${role.assignedMembers} members'),
                      trailing: IconButton(
                        key: Key('manage-role-${role.id}'),
                        icon: const Icon(Icons.more_vert_rounded,
                          color: AppColors.primary),
                        onPressed: _saving ? null : () => _actions(role),
                      ),
                    ),
                    const Divider(height: 1),
                  ],
                ]),
            ),
          ],
        ),
      ))),
    ])),
  );
}
