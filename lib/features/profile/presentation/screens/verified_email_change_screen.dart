import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sign2digital_header.dart';
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
        constraints:const BoxConstraints(maxWidth:720),
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
            TextField(key:const Key('m22-email-password'),controller:password,
              obscureText:true,decoration:const InputDecoration(
                labelText:'Current password',border:OutlineInputBorder()))
          else
            TextField(key:const Key('m22-email-code'),controller:code,
              keyboardType:TextInputType.number,
              inputFormatters:[FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6)],
              decoration:const InputDecoration(
                labelText:'Verification code',border:OutlineInputBorder())),
          if(error!=null)...[const SizedBox(height:12),
            Text(error!,style:const TextStyle(color:Colors.red))],
          const SizedBox(height:18),
          FilledButton(key:const Key('m22-email-next'),
            onPressed:saving?null:next,
            child:Text(saving?'Please wait…':challenge==null
              ?'Send verification code':'Verify email')),
        ]),
      ))),
    ])),
  );
}
