import 'package:flutter/material.dart';

import '../../../../core/services/sign_api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sign2digital_header.dart';
import '../../../quotes/presentation/widgets/sign2digital_quote_shadow_panel.dart';
import '../../data/remote_company_repository.dart';

/// Accepts the opaque invitation code delivered to the signed-in email.
/// The server checks that email and an active verified account before joining.
class CompanyInvitationsScreen extends StatefulWidget {
  const CompanyInvitationsScreen({super.key, this.repository});
  final RemoteCompanyRepository? repository;

  @override
  State<CompanyInvitationsScreen> createState() => _CompanyInvitationsScreenState();
}

class _CompanyInvitationsScreenState extends State<CompanyInvitationsScreen> {
  final _code = TextEditingController();
  late final RemoteCompanyRepository _repo =
      widget.repository ?? RemoteCompanyRepository.shared;
  bool _saving = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _accept() async {
    if (_saving) return;
    final code = _code.text.trim();
    if (code.length != 64) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the invitation code from your email.')));
      return;
    }
    setState(() => _saving = true);
    try {
      await _repo.acceptInvite(code);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Company invitation accepted.')));
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(error is SignApiException
            ? error.message : 'Unable to accept company invitation.'),
      ));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.white,
    body: SafeArea(child: Column(children: [
      const Sign2DigitalHeader(title: 'Company Invitations'),
      Expanded(child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 25),
          children: [
            Sign2DigitalQuoteShadowPanel(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Text('Accept Company Invitation', style: TextStyle(
                  fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w600,
                  color: AppColors.dark)),
                const SizedBox(height: 10),
                const Text('Enter the code sent to your registered email address.',
                  style: TextStyle(fontFamily: 'Inter', fontSize: 13,
                    color: AppColors.secondaryText)),
                const SizedBox(height: 15),
                TextField(
                  key: const Key('company-invitation-code'),
                  controller: _code,
                  autocorrect: false,
                  decoration: const InputDecoration(labelText: 'Invitation code'),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  key: const Key('accept-company-invitation'),
                  onPressed: _saving ? null : _accept,
                  child: Text(_saving ? 'Accepting...' : 'Accept Invitation'),
                ),
              ]),
            ),
          ],
        ),
      ))),
    ])),
  );
}
