import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sign2digital_bottom_navigation_bar.dart';
import '../../../../core/widgets/sign2digital_header.dart';
import '../../../../core/widgets/sign2digital_info_banner.dart';
import '../../../../core/widgets/sign2digital_input_field.dart';
import '../../../../core/widgets/sign2digital_outlined_button.dart';
import '../../data/security_access_repository.dart';
import '../widgets/profile_notification_row.dart';
import '../widgets/security_session_card.dart';

/// Profile & Settings -> Security. Only authenticated repository responses
/// can change 2FA status or revoke sessions; Figma demo is read-only.
class SecurityAccessScreen extends StatefulWidget {
  const SecurityAccessScreen({
    super.key,
    this.repository = const PreviewSecurityAccessRepository(),
    this.onNavigationSelected,
  });

  final SecurityAccessRepository repository;
  final ValueChanged<int>? onNavigationSelected;

  @override
  State<SecurityAccessScreen> createState() => _SecurityAccessScreenState();
}

class _SecurityAccessScreenState extends State<SecurityAccessScreen> {
  static const _heading = TextStyle(
    fontFamily: 'Inter',
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1,
    letterSpacing: -0.3,
    color: AppColors.dark,
  );

  final _password = TextEditingController();
  SecurityOverview? _snapshot;
  bool _loading = true;
  bool _busy = false;
  bool _showPassword = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) {
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final value = await widget.repository.load();
      if (!mounted) {
        return;
      }
      setState(() { _snapshot = value; _loading = false; });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _snapshot = null;
        _loading = false;
        _error = 'Could not load account security.';
      });
    }
  }

  void _message(String text) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  bool _hasPassword() {
    if (_password.text.isNotEmpty) {
      return true;
    }
    _message('Enter your password to confirm this security action.');
    return false;
  }

  Future<bool> _confirm({
    required String title,
    required String description,
    required String action,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(title),
        content: Text(description),
        actions: [
          TextButton(
            key: const Key('security-dialog-cancel'),
            onPressed: () => Navigator.of(dialog).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            key: const Key('security-dialog-confirm'),
            onPressed: () => Navigator.of(dialog).pop(true),
            child: Text(action),
          ),
        ],
      ),
    );
    return mounted && confirmed == true;
  }

  Future<void> _changeTwoFactor(bool enabled) async {
    final snapshot = _snapshot;
    if (_busy || snapshot == null) {
      return;
    }
    if (snapshot.twoFactorEnabled == null) {
      _message('Two-factor status is unavailable from the account service.');
      return;
    }
    if (!_hasPassword()) {
      return;
    }
    final confirmed = await _confirm(
      title: enabled ? 'Enable Two-Factor Authentication?' :
          'Disable Two-Factor Authentication?',
      description: 'This request requires verified authentication from '
          'your security service. Your selection will not change until '
          'that service confirms it.',
      action: 'Continue',
    );
    if (!confirmed) {
      return;
    }
    setState(() => _busy = true);
    try {
      final accepted = await widget.repository.changeTwoFactor(
        enable: enabled,
        confirmationPassword: _password.text,
      );
      if (!mounted) {
        return;
      }
      if (accepted) {
        _password.clear();
        await _load();
        _message('Two-factor settings updated.');
      } else {
        _message('Two-factor authentication is not connected or verified.');
      }
    } catch (_) {
      _message('Unable to update two-factor authentication.');
    } finally {
      // Credentials are never retained after a completed security request.
      _password.clear();
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _logoutAll() async {
    if (_busy) {
      return;
    }
    final confirmed = await _confirm(
      title: 'Log Out From All Devices?',
      description: 'Other sessions will be signed out after the account '
          'service verifies your request. Whether this device is also '
          'signed out depends on your account service.',
      action: 'Log Out',
    );
    if (!confirmed || !_hasPassword()) {
      return;
    }
    setState(() => _busy = true);
    try {
      final success = await widget.repository.revokeOtherSessions(
        confirmationPassword: _password.text,
      );
      if (!mounted) {
        return;
      }
      if (success) {
        _password.clear();
        await _load();
        _message('Session revocation confirmed by the account service.');
      } else {
        _message('Device logout is not connected. No sessions were changed.');
      }
    } catch (_) {
      _message('Unable to log out other devices.');
    } finally {
      // Credentials are never retained after a completed security request.
      _password.clear();
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _revokeSession(SecurityDeviceSession session,
      {bool fromAll = false}) async {
    if (_busy || session.isCurrent) {
      return;
    }
    final confirmed = await _confirm(
      title: 'Sign Out ${session.deviceName}?',
      description: 'The selected device will only be signed out after '
          'the account service verifies your request.',
      action: 'Sign Out',
    );
    if (!confirmed || !_hasPassword()) {
      return;
    }
    setState(() => _busy = true);
    try {
      final done = await widget.repository.revokeSession(
        sessionId: session.id,
        confirmationPassword: _password.text,
      );
      if (!mounted) {
        return;
      }
      if (done) {
        _password.clear();
        await _load();
        if (fromAll && mounted) {
          Navigator.of(context).pop();
        }
        _message('Session revoked by the account service.');
      } else {
        _message('Session revocation is not connected. No changes were made.');
      }
    } catch (_) {
      _message('Could not revoke this session.');
    } finally {
      // Credentials are never retained after a completed security request.
      _password.clear();
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _sessionDetails(SecurityDeviceSession session,
      {bool fromAll = false}) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (sheet) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(session.deviceName, style: _heading),
            const SizedBox(height: 10),
            Text(session.location, style: const TextStyle(
              fontFamily: 'Inter', color: AppColors.placeholder)),
            Text(session.agentAndLastSeen, style: const TextStyle(
              fontFamily: 'Inter', color: AppColors.placeholder)),
            const SizedBox(height: 20),
            Text(session.isCurrent
                ? 'This is the current device.'
                : 'Session actions require verified account authentication.',
              style: const TextStyle(
                fontFamily: 'Inter', color: AppColors.placeholder)),
            if (!session.isCurrent) ...[
              const SizedBox(height: 15),
              TextButton(
                key: const Key('security-revoke-session'),
                onPressed: () {
                  Navigator.of(sheet).pop();
                  _revokeSession(session, fromAll: fromAll);
                },
                child: const Text('Sign Out This Device',
                  style: TextStyle(color: Color(0xFFFF1B23))),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _viewAll() {
    final sessions = _snapshot?.sessions;
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => _SecuritySessionsScreen(
        sessions: sessions,
        demoOnly: _snapshot?.demoOnly ?? false,
        onSelect: (session) => _sessionDetails(session, fromAll: true),
      )),
    );
  }

  void _navigate(int index) {
    if (index == 4) {
      Navigator.of(context).maybePop();
      return;
    }
    if (widget.onNavigationSelected == null) {
      _message('Navigation is not connected yet.');
      return;
    }
    Navigator.of(context).maybePop();
    widget.onNavigationSelected!(index);
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    final isTwoFactorOn = snapshot?.twoFactorEnabled == true;
    return Scaffold(
      backgroundColor: AppColors.white,
      resizeToAvoidBottomInset: true,
      body: SafeArea(bottom: false, child: Column(children: [
        const Sign2DigitalHeader(title: 'Security'),
        Expanded(child: Center(child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            key: const Key('security-scroll'),
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            children: [
              if (_loading)
                const Padding(
                  padding: EdgeInsets.only(top: 30),
                  child: Center(child: CircularProgressIndicator()))
              else if (_error != null)
                TextButton(
                  key: const Key('security-retry'),
                  onPressed: _load,
                  child: Text('$_error Tap to retry.'))
              else if (snapshot != null) ...[
                Sign2DigitalInputField(
                  key: const Key('security-confirm-password'),
                  label: 'Confirm Password',
                  hintText: 'e.g, Marc@company.ch',
                  iconAsset: '',
                  leadingIcon: Icons.lock_outline_rounded,
                  leadingIconSize: 24,
                  controller: _password,
                  obscureText: !_showPassword,
                  keyboardType: TextInputType.visiblePassword,
                  autofillHints: const [AutofillHints.password],
                  trailing: IconButton(
                    key: const Key('security-password-visibility'),
                    tooltip: _showPassword ? 'Hide password' : 'Show password',
                    icon: Icon(
                      _showPassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 22,
                      color: AppColors.secondaryText,
                    ),
                    onPressed: () => setState(
                      () => _showPassword = !_showPassword),
                  ),
                ),
                const SizedBox(height: 20),
                ProfileNotificationRow(
                  key: const Key('security-two-factor-toggle'),
                  title: 'Two - Factor Authentication',
                  description: 'Add an extra layer of security',
                  enabled: isTwoFactorOn,
                  onChanged: _changeTwoFactor,
                ),
                const SizedBox(height: 10),
                Sign2DigitalInfoBanner(
                  key: const Key('security-two-factor-info'),
                  leadingIcon: Icons.history_rounded,
                  iconSize: 24,
                  iconGap: 10,
                  verticalPadding: 10,
                  title: snapshot.twoFactorEnabled == null
                      ? '2FA status unavailable'
                      : isTwoFactorOn
                          ? '2 FA is enabled'
                          : '2 FA is disabled',
                  titleColor: AppColors.primary,
                  textColor: AppColors.placeholder,
                  fontSize: 13,
                  message: snapshot.twoFactorEnabled == null
                      ? 'Connect your authentication service to check security.'
                      : isTwoFactorOn
                          ? 'Your account is protected with two factor authentication'
                          : 'Enable verified two factor authentication for extra security',
                ),
                if (snapshot.demoOnly) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Demo preview · 2FA and session statuses are not verified.',
                    key: Key('security-demo-notice'),
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      color: AppColors.placeholder,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Row(children: [
                  const Expanded(child: Text(
                    'Active Sessions', style: _heading)),
                  TextButton(
                    key: const Key('security-view-all'),
                    onPressed: _viewAll,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 36),
                    ),
                    child: const Text('View all',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.primary,
                      )),
                  ),
                ]),
                const SizedBox(height: 10),
                if (snapshot.sessions == null)
                  const Text('Active sessions are unavailable.',
                    style: TextStyle(color: AppColors.placeholder))
                else if (snapshot.sessions!.isEmpty)
                  const Text('No active sessions were provided.',
                    style: TextStyle(color: AppColors.placeholder))
                else
                  for (var i = 0; i < snapshot.sessions!.length; i++) ...[
                    SecuritySessionCard(
                      key: Key('security-session-${snapshot.sessions![i].id}'),
                      session: snapshot.sessions![i],
                      onTap: snapshot.sessions![i].isCurrent ? null :
                          () => _sessionDetails(snapshot.sessions![i]),
                    ),
                    if (i < snapshot.sessions!.length - 1)
                      const SizedBox(height: 20),
                  ],
              ],
            ],
          ),
        ))),
        if (!_loading && _error == null) ...[
          Center(child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Sign2DigitalOutlinedButton(
                key: const Key('security-logout-all'),
                label: 'Log Out From All Devices',
                destructive: true,
                enabled: !_busy,
                onPressed: _logoutAll,
              ),
            ),
          )),
        ],
      ])),
      bottomNavigationBar: Sign2DigitalBottomNavigationBar(
        selectedIndex: 4,
        onSelected: _navigate,
      ),
    );
  }
}

/// Shows every reported device using the exact same session-card widget.
class _SecuritySessionsScreen extends StatelessWidget {
  const _SecuritySessionsScreen({
    required this.sessions,
    required this.demoOnly,
    required this.onSelect,
  });
  final List<SecurityDeviceSession>? sessions;
  final bool demoOnly;
  final ValueChanged<SecurityDeviceSession> onSelect;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.white,
    body: SafeArea(bottom: false, child: Column(children: [
      const Sign2DigitalHeader(title: 'Active Sessions'),
      Expanded(child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          key: const Key('security-all-sessions'),
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          children: [
            if (demoOnly) ...[
              const Text('Demo preview · Session data is not verified.',
                style: TextStyle(color: AppColors.placeholder)),
              const SizedBox(height: 10),
            ],
            if (sessions == null)
              const Text('Active sessions are unavailable.',
                style: TextStyle(color: AppColors.placeholder))
            else if (sessions!.isEmpty)
              const Text('No sessions provided.',
                style: TextStyle(color: AppColors.placeholder))
            else
              for (var i = 0; i < sessions!.length; i++) ...[
                SecuritySessionCard(
                  key: Key('security-all-session-${sessions![i].id}'),
                  session: sessions![i],
                  onTap: sessions![i].isCurrent ? null :
                      () => onSelect(sessions![i]),
                ),
                if (i != sessions!.length - 1)
                  const SizedBox(height: 20),
              ],
          ],
        ),
      ))),
    ])),
    bottomNavigationBar: Sign2DigitalBottomNavigationBar(
      selectedIndex: 4,
      onSelected: (index) => Navigator.of(context).maybePop(),
    ),
  );
}
