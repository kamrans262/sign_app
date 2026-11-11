import 'package:flutter/material.dart';

import '../../../../core/services/sign_api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/sign2digital_header.dart';
import '../../../../core/widgets/sign2digital_input_field.dart';
import '../../../../core/widgets/sign2digital_primary_button.dart';
import '../../data/remote_security_access_repository.dart';
import 'two_factor_setup_screen.dart';

/// Reauthentication required for disabling TOTP or rotating recovery codes.
class TwoFactorProofScreen extends StatefulWidget {
  const TwoFactorProofScreen({
    super.key,
    required this.repository,
    required this.password,
    required this.regenerate,
  });
  final RemoteSecurityAccessRepository repository;
  final String password;
  final bool regenerate;

  @override
  State<TwoFactorProofScreen> createState() => _TwoFactorProofScreenState();
}

class _TwoFactorProofScreenState extends State<TwoFactorProofScreen> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || _code.text.trim().isEmpty) return;
    setState(() { _busy = true; _error = null; });
    try {
      if (widget.regenerate) {
        final codes = await widget.repository.regenerateRecoveryCodes(
          widget.password, _code.text.trim());
        if (!mounted) return;
        await Navigator.of(context).push<void>(MaterialPageRoute<void>(
          builder: (_) => TwoFactorRecoveryCodesScreen(codes: codes)));
      } else {
        final disabled = await widget.repository.disableTwoFactor(
          widget.password, _code.text.trim());
        if (!disabled) throw const SignApiException(
          'Two-factor authentication was not disabled.');
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _error = error is SignApiException
          ? error.message : 'Unable to verify this security change.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.white,
    body: SafeArea(child: Column(children: [
      Sign2DigitalHeader(title: widget.regenerate
          ? 'Replace Recovery Codes' : 'Disable Two-Factor Authentication'),
      Expanded(child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: ListView(padding: const EdgeInsets.all(20), children: [
          Text(widget.regenerate ? 'Rotate Recovery Codes' : 'Confirm 2FA Removal',
            textAlign: TextAlign.center, style: AppTextStyles.heading),
          const SizedBox(height: 12),
          Text(widget.regenerate
              ? 'Your old recovery codes will stop working immediately. '
                'Enter an authenticator code or a current recovery code.'
              : 'Removing the authenticator reduces your account security. '
                'Enter a valid authenticator or recovery code to continue.',
            textAlign: TextAlign.center, style: AppTextStyles.subtitle),
          const SizedBox(height: 25),
          Sign2DigitalInputField(
            key: const Key('m24-manage-code'),
            label: 'Authenticator or Recovery Code',
            hintText: '6-digit or saved recovery code',
            iconAsset: '',
            leadingIcon: Icons.password_outlined,
            leadingIconSize: 24,
            controller: _code,
            textCapitalization: TextCapitalization.characters,
            maxLength: 19,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submit(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, key: const Key('m24-manage-error'),
                style: const TextStyle(color: Color(0xFFB42318))),
          ],
          const SizedBox(height: 20),
          Sign2DigitalPrimaryButton(
            key: const Key('m24-manage-confirm'),
            label: widget.regenerate ? 'Generate New Codes' : 'Disable 2FA',
            loading: _busy,
            onPressed: _submit,
          ),
        ]),
      ))),
    ])),
  );
}
