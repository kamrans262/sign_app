import 'dart:convert';

import 'package:flutter/material.dart';
import '../../../../core/widgets/sign2digital_approved_confirmation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/services/sign_api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sign2digital_header.dart';
import '../../../../core/widgets/sign2digital_input_field.dart';
import '../../../../core/widgets/sign2digital_primary_button.dart';
import '../../../../core/widgets/sign2digital_outlined_button.dart';
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
      builder: (dialog) => Sign2DigitalApprovedConfirmation(
        title: const Text('Deactivate Account?'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Deactivation disables sign-in and revokes active sessions. '
            'It does not delete company records or signed documents. '
            'Active company owners must transfer or close ownership first.'),
          const SizedBox(height: 16),
          Sign2DigitalInputField(
            key: const Key('m22-privacy-password'),
            controller: password,
            label: 'Confirm Password',
            hintText: 'Enter account password',
            iconAsset: '',
            leadingIcon: Icons.lock_outline_rounded,
            leadingIconSize: 24,
            obscureText: true,
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
    final start = await showDialog<bool>(context: context, builder: (dialog) =>
      Sign2DigitalApprovedConfirmation(
        title: const Text('Permanently Delete Account?'),
        content: const Text('Your personal profile and private support data will be erased. '
          'Business records may be retained. Review active subscriptions separately. '
          'We will send a verification code to your registered email. '
          'If your company has other members, ownership must be resolved first.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialog).pop(false), child: const Text('Keep Account')),
          TextButton(onPressed: () => Navigator.of(dialog).pop(true), child: const Text('Send Code')),
        ],
      ));
    if (start != true || !mounted) return;
    setState(() { _busy = true; _message = null; });
    try {
      final challenge = await _api.post('/api/v1/me/deletion/challenge');
      if (!mounted) return;
      final requires2fa = (challenge['data'] as Map?)?['two_factor_required'] == true;
      var code = '', confirmation = '', second = '';
      final approved = await showDialog<Map<String, dynamic>>(context: context,
        builder: (dialog) => StatefulBuilder(builder: (context, refresh) =>
          Sign2DigitalApprovedConfirmation(
            title: const Text('Confirm Account Deletion'),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('Enter the emailed code and type DELETE. This cannot be undone.'),
              const SizedBox(height: 12),
              Sign2DigitalInputField(key: const Key('m25-delete-code'), label: 'Verification Code',
                hintText: 'Six-digit email code', iconAsset: '', onChanged: (v) => refresh(() => code=v.trim())),
              const SizedBox(height: 12),
              Sign2DigitalInputField(key: const Key('m22-delete-type'), label: 'Confirmation',
                hintText: 'Type DELETE', iconAsset: '', onChanged: (v) => refresh(() => confirmation=v)),
              if (requires2fa) ...[
                const SizedBox(height: 12),
                Sign2DigitalInputField(label: 'Authenticator or Recovery Code', hintText: 'Enter code',
                  iconAsset: '', onChanged: (v) => refresh(() => second=v.trim())),
              ],
            ]),
            actions: [
              TextButton(onPressed: () => Navigator.of(dialog).pop(), child: const Text('Keep Account')),
              TextButton(key: const Key('m22-delete-confirm'),
                onPressed: confirmation == 'DELETE' && RegExp(r'^[0-9]{6}$').hasMatch(code) && (!requires2fa || second.isNotEmpty)
                  ? () => Navigator.of(dialog).pop({'code': code,'confirmation': confirmation,if(requires2fa)'two_factor_code':second}) : null,
                child: const Text('Delete Account')),
            ],
          )));
      if (!mounted || approved == null) return;
      final response = await _api.post('/api/v1/me/deletion/complete', data: approved);
      if ((response['data'] as Map?)?['deleted'] != true) throw const SignApiException('Deletion was not confirmed.');
      try { await MobileAuthRepository.shared.logout(); } catch (_) {}
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute<void>(builder: (_) => const MobileAuthGateway()), (_) => false);
    } on SignApiException catch (error) {
      if(mounted) setState(() => _message=error.message);
    } catch (_) {
      if(mounted) setState(() => _message='Unable to delete this account. No changes were confirmed.');
    } finally {
      if(mounted) setState(() => _busy=false);
    }
  }
  Future<void> _withdrawAi() async {
    if(_busy)return;
    setState(() { _busy=true; _message=null; });
    try {
      final state=(await _api.get('/api/v1/me/ai-consent'))['data'] as Map;
      await _api.put('/api/v1/me/ai-consent',data:{'version':state['version'],'allowed':false});
      if(mounted)setState(()=>_message='AI permission withdrawn. Manual features remain available.');
    } catch (_) {
      if(mounted)setState(()=>_message='Unable to update AI permission.');
    } finally {if(mounted)setState(()=>_busy=false);}
  }
  Future<void> _openLegal(String path) async {
    final uri=SignApiConfig.baseUrl.replace(path:path,query:null,fragment:null);
    if(!await launchUrl(uri,mode:LaunchMode.externalApplication)&&mounted) {
      setState(()=>_message='Unable to open legal information.');
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
            Sign2DigitalPrimaryButton(
              key: const Key('m22-privacy-export'),
              label: 'Copy My Account Data',
              enabled: !_busy,
              loading: _busy,
              leading: const Icon(Icons.copy_outlined,
                size: 20, color: AppColors.white),
              onPressed: _export,
            ),
            const SizedBox(height: 28),
            const Text('AI Privacy', style: TextStyle(fontFamily:'Inter',fontSize:20,fontWeight:FontWeight.w600,color:AppColors.dark)),
            const SizedBox(height:10),
            const Text('AI features share selected content with OpenAI only with your permission. You can withdraw that permission at any time.'),
            const SizedBox(height:12),
            Sign2DigitalOutlinedButton(label:'Withdraw AI Permission',enabled:!_busy,primaryOutline:true,onPressed:_withdrawAi),
            const SizedBox(height:12),
            Sign2DigitalOutlinedButton(label:'Privacy Policy',primaryOutline:true,onPressed:()=>_openLegal('/privacy-policy')),
            const SizedBox(height:10),
            Sign2DigitalOutlinedButton(label:'Terms and Conditions',primaryOutline:true,onPressed:()=>_openLegal('/terms-and-conditions')),
            const SizedBox(height:28),
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
            Sign2DigitalOutlinedButton(
              key: const Key('m22-privacy-deactivate'),
              label: 'Deactivate Account',
              enabled: !_busy,
              primaryOutline: true,
              leading: const Icon(Icons.person_off_outlined,
                size: 20, color: AppColors.primary),
              onPressed: _deactivate,
            ),
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
            Sign2DigitalOutlinedButton(
              key: const Key('m22-privacy-delete'),
              label: 'Delete Account',
              enabled: !_busy,
              destructive: true,
              leading: const Icon(Icons.delete_forever_outlined,
                size: 20, color: Color(0xFFFF1B23)),
              onPressed: _deleteAccount,
            ),
          ],
        ),
      ))),
    ])),
  );
}
