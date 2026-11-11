import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/services/sign_api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/sign2digital_header.dart';
import '../../../../core/widgets/sign2digital_input_field.dart';
import '../../../../core/widgets/sign2digital_primary_button.dart';

/// Authenticator verification follows password and email OTP. No session is
/// considered valid until the backend returns a verified Sanctum bearer.
class TwoFactorLoginScreen extends StatefulWidget {
  const TwoFactorLoginScreen({super.key, required this.onVerify});
  final Future<void> Function(String code) onVerify;

  @override
  State<TwoFactorLoginScreen> createState() => _TwoFactorLoginScreenState();
}

class _TwoFactorLoginScreenState extends State<TwoFactorLoginScreen> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_busy) return;
    final value = _code.text.trim();
    if (!RegExp(r'^(?:[0-9]{6}|[a-fA-F0-9]{4}(?:-?[a-fA-F0-9]{4}){3})$')
        .hasMatch(value)) {
      setState(() => _error = 'Enter a 6-digit authenticator code or a recovery code.');
      return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      await widget.onVerify(value);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error is SignApiException
          ? error.message : 'Authenticator verification failed.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.white,
    body: SafeArea(child: Column(children: [
      const Sign2DigitalHeader(title: 'Two-Factor Authentication'),
      Expanded(child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 25),
          children: [
            const Icon(Icons.verified_user_outlined,
                color: AppColors.primary, size: 42),
            const SizedBox(height: 20),
            const Text('Verify Your Sign-In',
                textAlign: TextAlign.center, style: AppTextStyles.heading),
            const SizedBox(height: 10),
            const Text(
              'Enter the current 6-digit code from your authenticator app. '
              'If your phone is unavailable, enter one of your saved recovery codes.',
              textAlign: TextAlign.center, style: AppTextStyles.subtitle),
            const SizedBox(height: 25),
            Sign2DigitalInputField(
              key: const Key('m24-login-code'),
              label: 'Authenticator or Recovery Code',
              hintText: '000000 or XXXX-XXXX-XXXX-XXXX',
              iconAsset: '',
              leadingIcon: Icons.password_outlined,
              leadingIconSize: 24,
              controller: _code,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.done,
              maxLength: 19,
              onFieldSubmitted: (_) => _verify(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, key: const Key('m24-login-error'),
                  style: const TextStyle(color: Color(0xFFB42318))),
            ],
            const SizedBox(height: 25),
            Sign2DigitalPrimaryButton(
              key: const Key('m24-login-verify'),
              label: 'Verify & Sign In',
              loading: _busy,
              onPressed: _verify,
            ),
          ],
        ),
      ))),
    ])),
  );
}
