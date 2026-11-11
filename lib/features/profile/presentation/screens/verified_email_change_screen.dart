import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sign2digital_header.dart';
import '../../../../core/widgets/sign2digital_input_field.dart';
import '../../../../core/widgets/sign2digital_primary_button.dart';
import '../../../auth/data/mobile_auth_repository.dart';
import '../../../auth/data/remote_account_repository.dart';
import '../../../auth/presentation/screens/mobile_auth_gateway.dart';

/// New email is never accepted without both password and emailed OTP.
class VerifiedEmailChangeScreen extends StatefulWidget {
  const VerifiedEmailChangeScreen({super.key, required this.newEmail,
      required this.repository});
  final String newEmail;
  final RemoteAccountRepository repository;
  @override
  State<VerifiedEmailChangeScreen> createState() => _EmailChangeState();
}

class _EmailChangeState extends State<VerifiedEmailChangeScreen> {
  final password = TextEditingController(), code = TextEditingController();
  String? challenge, error;
  bool saving = false;
  @override
  void dispose() { password.dispose(); code.dispose(); super.dispose(); }
  Future<void> next() async {
    if(saving) return;
    setState(() { saving=true; error=null; });
    try {
      if(challenge==null) {
        if(password.text.isEmpty) throw const FormatException();
        final id=await widget.repository.startEmailChange(
          email:widget.newEmail,password:password.text);
        if(!mounted) return;
        password.clear();
        setState(() => challenge=id);
      } else {
        if(!RegExp(r'^[0-9]{6}$').hasMatch(code.text)) throw const FormatException();
        final ok=await widget.repository.verifyEmailChange(
          challengeId:challenge!,code:code.text);
        if(!ok) throw const FormatException();
        try { await MobileAuthRepository.shared.logout(); } catch (_) {}
        if(!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute<void>(builder: (_) => const MobileAuthGateway()),
          (_) => false);
      }
    } catch (_) {
      if(mounted) {
        setState(() => error=challenge==null
          ? 'Unable to start verification. Check your password.'
          : 'Verification code invalid or expired.');
      }
    } finally {
      if(mounted) setState(() => saving=false);
    }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor:AppColors.white,
    body:SafeArea(child:Column(children:[
      const Sign2DigitalHeader(title:'Verify New Email'),
      Expanded(child:Center(child:ConstrainedBox(
        constraints:BoxConstraints(maxWidth:
          MediaQuery.orientationOf(context)==Orientation.landscape
              ? double.infinity : 720),
        child:ListView(padding:const EdgeInsets.all(20),children:[
          Text('New email: ${widget.newEmail}',
            style:const TextStyle(fontFamily:'Inter',color:AppColors.dark)),
          const SizedBox(height:14),
          Text(challenge==null
            ? 'Confirm your account password to send a code to your new email.'
            : 'Enter the emailed 6-digit code. You must sign in again once verified.',
            style:const TextStyle(color:AppColors.placeholder)),
          const SizedBox(height:20),
          if(challenge==null)
            Sign2DigitalInputField(
              key:const Key('m22-email-password'),
              controller:password,
              label:'Current Password',
              hintText:'Enter current password',
              iconAsset:'',
              leadingIcon:Icons.lock_outline_rounded,
              leadingIconSize:24,
              obscureText:true,
              keyboardType:TextInputType.visiblePassword,
            )
          else
            Sign2DigitalInputField(
              key:const Key('m22-email-code'),
              controller:code,
              label:'Verification Code',
              hintText:'Enter 6-digit code',
              iconAsset:'',
              leadingIcon:Icons.verified_outlined,
              leadingIconSize:24,
              keyboardType:TextInputType.number,
              inputFormatters:[FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6)],
              maxLength:6,
            ),
          if(error!=null)...[const SizedBox(height:12),
            Text(error!,style:const TextStyle(color:Colors.red))],
          const SizedBox(height:18),
          Sign2DigitalPrimaryButton(
            key:const Key('m22-email-next'),
            label:challenge==null?'Send verification code':'Verify email',
            loading:saving,
            onPressed:next,
          ),
        ]),
      ))),
    ])),
  );
}
