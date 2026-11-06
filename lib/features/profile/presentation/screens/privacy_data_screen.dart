import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/services/sign_api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sign2digital_header.dart';
import '../../../auth/data/mobile_auth_repository.dart';
import '../../../auth/presentation/screens/mobile_auth_gateway.dart';

/// Personal-account privacy controls. Company jobs and issued documents are
/// never silently exported or deleted; they belong to separate records.
class PrivacyDataScreen extends StatefulWidget {
  const PrivacyDataScreen({super.key, this.api});
  final SignApiClient? api;

  @override
  State<PrivacyDataScreen> createState() => _PrivacyDataScreenState();
}

class _PrivacyDataScreenState extends State<PrivacyDataScreen> {
  late final SignApiClient _api;
  bool _busy = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? MobileAuthRepository.shared.api;
  }

  Future<void> _export() async {
    if (_busy) return;
    setState(() { _busy = true; _message = null; });
    try {
      final result = await _api.get('/api/v1/me/export');
      final data = result['data'];
      if (data is! Map<String, dynamic> ||
          data['scope'] != 'personal_account_only_company_documents_not_included') {
        throw const SignApiException('Unrecognized data-export scope.');
      }
      final json = const JsonEncoder.withIndent('  ').convert(data);
      if (!mounted) return;
      await Clipboard.setData(ClipboardData(text: json));
      if (mounted) {
        setState(() => _message =
          'Personal account data copied. Company documents are excluded.');
      }
    } catch (_) {
      if (mounted) {
        setState(() =>
          _message = 'Unable to export your personal account data.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deactivate() async {
    if (_busy) return;
    final password = TextEditingController();
    final approved = await showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Deactivate Account?'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Deactivation disables sign-in and revokes active sessions. '
            'It does not delete company records or signed documents. '
            'Active company owners must transfer or close ownership first.'),
          const SizedBox(height: 16),
          TextField(
            key: const Key('m22-privacy-password'),
            controller: password,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Confirm your password',
              border: OutlineInputBorder()),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(),
            child: const Text('Keep Account')),
          TextButton(
            key: const Key('m22-privacy-confirm'),
            onPressed: () => Navigator.of(dialog).pop(password.text),
            child: const Text('Deactivate')),
        ],
      ),
    );
    password.dispose();
    if (!mounted || approved == null || approved.isEmpty) return;
    setState(() { _busy = true; _message = null; });
    try {
      final response = await _api.post('/api/v1/me/deactivate',
        data: {'password': approved});
      final data = response['data'];
      if (data is! Map<String, dynamic> || data['deactivated'] != true) {
        throw const SignApiException('Deactivation was not confirmed.');
      }
      try { await MobileAuthRepository.shared.logout(); } catch (_) {}
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const MobileAuthGateway()),
        (_) => false,
      );
    } on SignApiException catch (error) {
      if (mounted) {
        setState(() => _message =
          error.statusCode == 422
            ? 'Check your password and transfer ownership of active companies first.'
            : 'Unable to deactivate your account.');
      }
    } catch (_) {
      if (mounted) {
        setState(() =>
          _message = 'Unable to deactivate your account.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteAccount() async {
    if (_busy) return;
    var confirmation = '';
    var password = '';
    final approved = await showDialog<String>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (context, refresh) => AlertDialog(
          title: const Text('Permanently Delete Account?'),
          content: SingleChildScrollView(child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Your personal profile and private support data will '
                'be erased and every session revoked. Issued company records '
                'and signed documents are retained for legal integrity. '
                'Transfer company ownership and administrator access first.'),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('m22-delete-type'),
                onChanged: (value) => refresh(() => confirmation = value),
                decoration: const InputDecoration(
                  labelText: 'Type DELETE', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('m22-delete-password'),
                obscureText: true,
                onChanged: (value) => refresh(() => password = value),
                decoration: const InputDecoration(
                  labelText: 'Confirm your password',
                  border: OutlineInputBorder()),
              ),
            ],
          )),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialog).pop(),
              child: const Text('Keep Account')),
            TextButton(
              key: const Key('m22-delete-confirm'),
              onPressed: confirmation == 'DELETE' && password.isNotEmpty
                ? () => Navigator.of(dialog).pop(password) : null,
              child: const Text('Delete Account')),
          ],
        ),
      ),
    );
    if (!mounted || approved == null) return;
    setState(() { _busy = true; _message = null; });
    try {
      final response = await _api.post('/api/v1/me/delete',
        data: {'password': approved});
      if (response['data'] is! Map<String, dynamic> ||
          response['data']['deleted'] != true ||
          response['data']['requires_login'] != true) {
        throw const SignApiException('Deletion was not confirmed.');
      }
      try { await MobileAuthRepository.shared.logout(); } catch (_) {}
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const MobileAuthGateway()),
        (_) => false);
    } on SignApiException catch (error) {
      if (mounted) {
        setState(() => _message = error.statusCode == 422
          ? 'Check your password and transfer all company ownership first.'
          : 'Unable to delete this account. No changes were confirmed.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _message =
          'Unable to delete this account. No changes were confirmed.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.white,
    body: SafeArea(child: Column(children: [
      const Sign2DigitalHeader(title: 'Privacy & Data'),
      Expanded(child: Center(child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth:
          MediaQuery.orientationOf(context) == Orientation.landscape
            ? double.infinity : 720),
        child: ListView(
          key: const Key('m22-privacy-scroll'),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          children: [
            if (_message != null) ...[
              const SizedBox(height: 16),
              Text(_message!, key: const Key('m22-privacy-message'),
                style: const TextStyle(color: AppColors.secondaryText)),
            ],
            const Text('Your Account Data',
              style: TextStyle(fontFamily: 'Inter', fontSize: 20,
                fontWeight: FontWeight.w600, color: AppColors.dark)),
            const SizedBox(height: 12),
            const Text('View a copy of your own profile, preferences and '
              'support-ticket conversations. Company records, invoices and '
              'signed documents are not included in this personal export.',
              style: TextStyle(fontFamily: 'Inter', fontSize: 14,
                color: AppColors.secondaryText)),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const Key('m22-privacy-export'),
              onPressed: _busy ? null : _export,
              icon: const Icon(Icons.copy_outlined),
              label: const Text('Copy My Account Data')),
            const SizedBox(height: 28),
            const Text('Account Deactivation',
              style: TextStyle(fontFamily: 'Inter', fontSize: 20,
                fontWeight: FontWeight.w600, color: AppColors.dark)),
            const SizedBox(height: 10),
            const Text('Disable access to this account after confirming your '
              'password. Existing company documents are preserved. '
              'This is not a permanent data-deletion request.',
              style: TextStyle(fontFamily: 'Inter', fontSize: 14,
                color: AppColors.secondaryText)),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              key: const Key('m22-privacy-deactivate'),
              onPressed: _busy ? null : _deactivate,
              icon: const Icon(Icons.person_off_outlined),
              label: const Text('Deactivate Account')),
            const SizedBox(height: 28),
            const Text('Delete Personal Account',
              style: TextStyle(fontFamily: 'Inter', fontSize: 20,
                fontWeight: FontWeight.w600, color: AppColors.dark)),
            const SizedBox(height: 10),
            const Text('Permanently erase personal profile and private support '
              'data, while retaining legally necessary company records. '
              'This cannot be undone.',
              style: TextStyle(fontFamily: 'Inter', fontSize: 14,
                color: AppColors.secondaryText)),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              key: const Key('m22-privacy-delete'),
              onPressed: _busy ? null : _deleteAccount,
              icon: const Icon(Icons.delete_forever_outlined),
              label: const Text('Delete Account')),
          ],
        ),
      ))),
    ])),
  );
}
