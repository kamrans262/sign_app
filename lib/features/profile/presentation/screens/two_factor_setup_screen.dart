import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/services/sign_api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/sign2digital_header.dart';
import '../../../../core/widgets/sign2digital_input_field.dart';
import '../../../../core/widgets/sign2digital_primary_button.dart';
import '../../../../core/widgets/sign2digital_outlined_button.dart';
import '../../data/remote_security_access_repository.dart';

/// Fresh enrollment secret and recovery codes are never persisted on device.
class TwoFactorSetupScreen extends StatefulWidget {
  const TwoFactorSetupScreen({
    super.key,
    required this.repository,
    required this.password,
  });
  final RemoteSecurityAccessRepository repository;
  final String password;

  @override
  State<TwoFactorSetupScreen> createState() => _TwoFactorSetupScreenState();
}

class _TwoFactorSetupScreenState extends State<TwoFactorSetupScreen> {
  final _code = TextEditingController();
  TwoFactorEnrollment? _enrollment;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _begin();
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _begin() async {
    setState(() { _loading = true; _error = null; });
    try {
      final value = await widget.repository.beginTwoFactorSetup(widget.password);
      if (mounted) { setState(() { _enrollment = value; _loading = false; }); }
    } catch (error) {
      if (mounted) setState(() {
        _loading = false;
        _error = error is SignApiException
            ? error.message : 'Unable to start authenticator setup.';
      });
    }
  }

  Future<void> _confirm() async {
    if (_busy || _enrollment == null) return;
    final code = _code.text.trim();
    if (!RegExp(r'^[0-9]{6}$').hasMatch(code)) {
      setState(() => _error = 'Enter the 6-digit code in your authenticator.');
      return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      final codes = await widget.repository.confirmTwoFactor(code);
      if (!mounted) { return; }
      await Navigator.of(context).push<void>(MaterialPageRoute<void>(
        builder: (_) => TwoFactorRecoveryCodesScreen(codes: codes),
      ));
      if (mounted) { Navigator.of(context).pop(true); }
    } catch (error) {
      if (mounted) setState(() => _error = error is SignApiException
          ? error.message : 'Unable to verify authenticator setup.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.white,
    body: SafeArea(child: Column(children: [
      const Sign2DigitalHeader(title: 'Set Up Authenticator'),
      Expanded(child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 15, 20, 25),
          children: [
            const Text('Add Extra Account Protection',
                textAlign: TextAlign.center, style: AppTextStyles.heading),
            const SizedBox(height: 10),
            const Text(
              'Scan this QR code with Google Authenticator, Microsoft '
              'Authenticator or any compatible authenticator app.',
              textAlign: TextAlign.center, style: AppTextStyles.subtitle),
            const SizedBox(height: 20),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_enrollment == null)
              Sign2DigitalOutlinedButton(
                label: 'Retry Setup', onPressed: _begin,
                primaryOutline: true)
            else ...[
              Center(child: Container(
                padding: const EdgeInsets.all(12),
                color: AppColors.white,
                child: QrImageView(
                  key: const Key('m24-setup-qr'),
                  data: _enrollment!.otpauthUri,
                  version: QrVersions.auto,
                  size: 205,
                  backgroundColor: AppColors.white,
                ),
              )),
              const SizedBox(height: 15),
              const Text('Alternatively, enter this setup key manually:',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.subtitle),
              const SizedBox(height: 8),
              SelectableText(_enrollment!.secret,
                  key: const Key('m24-setup-secret'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 16,
                      color: AppColors.dark, fontWeight: FontWeight.w600)),
              TextButton.icon(
                onPressed: () => Clipboard.setData(
                  ClipboardData(text: _enrollment!.secret)),
                icon: const Icon(Icons.copy_outlined,
                  color: AppColors.primary),
                label: const Text('Copy Setup Key'),
              ),
              const SizedBox(height: 15),
              Sign2DigitalInputField(
                key: const Key('m24-setup-verification'),
                label: 'Authenticator Code',
                hintText: 'Enter 6-digit code',
                iconAsset: '',
                leadingIcon: Icons.verified_user_outlined,
                leadingIconSize: 24,
                controller: _code,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6)],
                maxLength: 6,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _confirm(),
              ),
              const SizedBox(height: 20),
              Sign2DigitalPrimaryButton(
                key: const Key('m24-setup-enable'),
                label: 'Verify & Enable 2FA',
                loading: _busy,
                onPressed: _confirm,
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, key: const Key('m24-setup-error'),
                  style: const TextStyle(color: Color(0xFFB42318))),
            ],
          ],
        ),
      ))),
    ])),
  );
}

/// The API returns these codes only once. No local persistence or telemetry.
class TwoFactorRecoveryCodesScreen extends StatelessWidget {
  const TwoFactorRecoveryCodesScreen({super.key, required this.codes});
  final List<String> codes;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.white,
    body: SafeArea(child: Column(children: [
      const Sign2DigitalHeader(title: 'Recovery Codes'),
      Expanded(child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: ListView(padding: const EdgeInsets.all(20), children: [
          const Icon(Icons.shield_outlined,
              color: AppColors.primary, size: 44),
          const SizedBox(height: 15),
          const Text('Save Your Recovery Codes',
              textAlign: TextAlign.center, style: AppTextStyles.heading),
          const SizedBox(height: 10),
          const Text(
            'These codes can restore access if you lose your authenticator '
            'device. Each code works only once. Store them somewhere safe. '
            'They will not be displayed again.',
            textAlign: TextAlign.center, style: AppTextStyles.subtitle),
          const SizedBox(height: 20),
          ...codes.map((code) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: SelectableText(code, textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'Inter', fontSize: 17,
                fontWeight: FontWeight.w600, color: AppColors.dark)),
          )),
          const SizedBox(height: 20),
          Sign2DigitalOutlinedButton(
            key: const Key('m24-recovery-copy'),
            label: 'Copy Recovery Codes',
            primaryOutline: true,
            leading: const Icon(Icons.copy_outlined,
              size: 20, color: AppColors.primary),
            onPressed: () => Clipboard.setData(
              ClipboardData(text: codes.join('\n'))),
          ),
          const SizedBox(height: 15),
          Sign2DigitalPrimaryButton(
            key: const Key('m24-recovery-done'),
            label: 'I Have Saved My Codes',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ]),
      ))),
    ])),
  );
}
