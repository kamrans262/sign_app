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
import '../../../auth/services/apple_sign_in_client.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/widgets/sign2digital_selection_field.dart';
import '../../../../core/widgets/sign2digital_selection_sheet.dart';
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
    setState(() { _busy = true; _message = null; });
    try {
      final options=(await _api.get('/api/v1/me/deletion/options'))['data'] as Map;
      if (!mounted) return;
      final companies=(options['companies'] as List).map((v)=>Map<String,dynamic>.from(v as Map)).toList();
      if (options['platform_admin']==true) {
        setState(()=>_message='Transfer platform administration before deleting this account.');
        return;
      }
      final apple=!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS && options['apple_linked']==true;
      final requires2fa=options['two_factor_required']==true;
      final transfers=<String,int>{};
      var closeSole=false;
      var confirmation='',second='',code='';
      final hasSole=companies.any((c)=>c['can_close']==true);
      final shared=companies.where((c)=>c['can_close']!=true).toList();
      if(shared.any((c)=>(c['successors'] as List).isEmpty)) {
        setState(()=>_message='An active company administrator must be available to take ownership. Use Help & Support to arrange transfer.');
        return;
      }
      final accepted=await showDialog<bool>(context:context,
        builder:(dialog)=>StatefulBuilder(builder:(context,refresh)=>Sign2DigitalApprovedConfirmation(
          title:const Text('Permanently Delete Account?'),
          content:Column(mainAxisSize:MainAxisSize.min,children:[
            const Text('Your personal profile and private support data will be erased and sessions revoked. Required business records may be retained. Cancel any subscriptions separately; you can delete now without waiting for a billing period to end.'),
            if(hasSole) CheckboxListTile(
              contentPadding:EdgeInsets.zero,value:closeSole,
              title:const Text('Close my sole-owner companies and retain required business records.'),
              onChanged:(v)=>refresh(()=>closeSole=v==true)),
            for(final c in shared) ...[
              const SizedBox(height:12),
              Sign2DigitalSelectionField(label:'Transfer ${c['name']}',hintText:'Choose new owner',iconAsset:'',
                leadingIcon:Icons.people_outline,
                value:transfers.containsKey('${c['id']}') ? (c['successors'] as List).cast<Map>().firstWhere((m)=>m['id']==transfers['${c['id']}'])['name'] as String : null,
                onTap:() async {
                  final choices=(c['successors'] as List).cast<Map>();
                  final selected=await Sign2DigitalSelectionSheet.show(context,title:'Transfer ${c['name']}',
                    options:choices.map((m)=>'${m['id']}').toList(),labelForOption:(id)=>'${choices.firstWhere((m)=>'${m['id']}'==id)['name']}');
                  if(selected!=null && context.mounted)refresh(()=>transfers['${c['id']}']=int.parse(selected));
                }),
            ],
            if(apple) const Text('You will confirm your identity with Apple.'),
          ]),
          actions:[
            TextButton(onPressed:()=>Navigator.of(dialog).pop(false),child:const Text('Keep Account')),
            TextButton(onPressed:(!hasSole||closeSole)&&shared.every((c)=>transfers.containsKey('${c['id']}'))
              ?()=>Navigator.of(dialog).pop(true):null,child:const Text('Continue')),
          ])));
      if(accepted!=true||!mounted)return;
      Map<String,dynamic> proof={};
      if(apple) {
        final challenge=await _api.post('/api/v1/auth/apple/challenge',authenticated:false);
        final nonce=(challenge['data'] as Map)['nonce'] as String;
        final credential=await AppleSignInClient.signIn(nonce);
        if(credential==null||!mounted)return;
        proof={'apple_id_token':credential['id_token'],'apple_nonce':nonce,
          if(credential['authorization_code']!=null)'apple_authorization_code':credential['authorization_code']};
      } else {
        await _api.post('/api/v1/me/deletion/challenge');
      }
      if(!mounted)return;
      final approved=await showDialog<Map<String,dynamic>>(context:context,
        builder:(dialog)=>StatefulBuilder(builder:(context,refresh)=>Sign2DigitalApprovedConfirmation(
          title:const Text('Confirm Account Deletion'),
          content:Column(mainAxisSize:MainAxisSize.min,children:[
            Text(apple?'Type DELETE to permanently erase your account.':'Enter the emailed code and type DELETE. This cannot be undone.'),
            if(!apple)...[
              const SizedBox(height:12),
              Sign2DigitalInputField(key:const Key('m25-delete-code'),label:'Verification Code',hintText:'Six-digit email code',iconAsset:'',
                leadingIcon:Icons.mail_outline,keyboardType:TextInputType.number,onChanged:(v)=>refresh(()=>code=v.trim())),
            ],
            const SizedBox(height:12),
            Sign2DigitalInputField(key:const Key('m22-delete-type'),label:'Confirmation',hintText:'Type DELETE',iconAsset:'',
              leadingIcon:Icons.warning_amber_outlined,onChanged:(v)=>refresh(()=>confirmation=v)),
            if(requires2fa)...[
              const SizedBox(height:12),
              Sign2DigitalInputField(label:'Authenticator or Recovery Code',hintText:'Enter code',iconAsset:'',
                leadingIcon:Icons.lock_outline,onChanged:(v)=>refresh(()=>second=v.trim())),
            ],
          ]),
          actions:[
            TextButton(onPressed:()=>Navigator.of(dialog).pop(),child:const Text('Keep Account')),
            TextButton(key:const Key('m22-delete-confirm'),
              onPressed:confirmation=='DELETE'&&(apple||RegExp(r'^[0-9]{6}$').hasMatch(code))&&(!requires2fa||second.isNotEmpty)
                ?()=>Navigator.of(dialog).pop(<String,dynamic>{
                  ...proof,if(!apple)'code':code,'confirmation':'DELETE',
                  if(requires2fa)'two_factor_code':second,'close_sole_owned':closeSole,'ownership_transfers':transfers,
                }):null,child:const Text('Delete Account')),
          ])));
      if(!mounted||approved==null)return;
      final response=await _api.post('/api/v1/me/deletion/complete',data:approved);
      if((response['data'] as Map?)?['deleted']!=true)throw const SignApiException('Deletion was not confirmed.');
      final manual=(response['data'] as Map?)?['manual_apple_revocation']==true;
      if(manual&&mounted){
        await showDialog<void>(context:context,builder:(dialog)=>Sign2DigitalApprovedConfirmation(
          title:const Text('Account Deleted'),
          content:const Text('To remove any remaining Apple authorization, open Settings, your Apple Account, Sign in with Apple, Sign2Digital, and choose Stop Using Apple ID.'),
          actions:[TextButton(onPressed:()=>Navigator.of(dialog).pop(),child:const Text('Done'))]));
      }
      try{await MobileAuthRepository.shared.logout();}catch(_){}
      if(!mounted)return;
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute<void>(builder:(_)=>const MobileAuthGateway()),(_)=>false);
    } on SignApiException catch(error){
      if(mounted)setState(()=>_message=error.message);
    } catch(_){
      if(mounted)setState(()=>_message='Unable to delete this account. No changes were confirmed.');
    } finally{if(mounted)setState(()=>_busy=false);}
  }
  Future<void> _withdrawAi() async {
    if(_busy)return;
    setState(() { _busy=true; _message=null; });
    try {
      final state=(await _api.get('/api/v1/me/ai-consent'))['data'] as Map;
      await _api.put('/api/v1/me/ai-consent',data:{'version':state['version'],'allowed':false,'user_id':state['user_id']});
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
