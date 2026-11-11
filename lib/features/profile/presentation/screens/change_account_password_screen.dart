import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sign2digital_header.dart';
import '../../../../core/widgets/sign2digital_input_field.dart';
import '../../../../core/widgets/sign2digital_primary_button.dart';
import '../../../auth/data/mobile_auth_repository.dart';
import '../../../auth/presentation/screens/mobile_auth_gateway.dart';
import '../../data/remote_security_access_repository.dart';

class ChangeAccountPasswordScreen extends StatefulWidget {
  const ChangeAccountPasswordScreen({super.key,this.repository});
  final RemoteSecurityAccessRepository? repository;
  @override
  State<ChangeAccountPasswordScreen> createState()=>_PasswordChangeState();
}
class _PasswordChangeState extends State<ChangeAccountPasswordScreen> {
  final current=TextEditingController(), next=TextEditingController(),
    confirm=TextEditingController();
  bool saving=false;
  String? error;
  @override
  void dispose(){current.dispose();next.dispose();confirm.dispose();super.dispose();}
  Future<void> save()async {
    if(saving)return;
    if(next.text!=confirm.text || next.text.length<8){
      setState(()=>error='Passwords must match and contain at least 8 characters.');
      return;
    }
    setState(() {saving=true;error=null;});
    try {
      final repo=widget.repository??RemoteSecurityAccessRepository();
      final ok=await repo.changePassword(current:current.text,next:next.text);
      if(!ok)throw const FormatException();
      try{await MobileAuthRepository.shared.logout();}catch(_){}
      if(!mounted)return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder:(_)=>const MobileAuthGateway()),(_)=>false);
    } catch(_){
      if(mounted)setState(()=>error='Password update failed. Check your current password and password strength.');
    } finally {
      current.clear();next.clear();confirm.clear();
      if(mounted)setState(()=>saving=false);
    }
  }
  @override
  Widget build(BuildContext context)=>Scaffold(
    backgroundColor:AppColors.white,
    body:SafeArea(child:Column(children:[
      const Sign2DigitalHeader(title:'Change Password'),
      Expanded(child:Center(child:ConstrainedBox(
        constraints:BoxConstraints(maxWidth:
          MediaQuery.orientationOf(context)==Orientation.landscape
              ? double.infinity : 720),
        child:ListView(padding:const EdgeInsets.all(20),children:[
          const Text('Use upper and lower case letters, a number and a symbol.',
            style:TextStyle(color:AppColors.placeholder)),
          const SizedBox(height:20),
          for(final entry in [
            ('Current password',current,'m22-pass-current'),
            ('New password',next,'m22-pass-new'),
            ('Confirm password',confirm,'m22-pass-confirm'),
          ]) ...[
            Sign2DigitalInputField(
              key:Key(entry.$3),
              controller:entry.$2,
              label:entry.$1,
              hintText:'Enter ${entry.$1.toLowerCase()}',
              iconAsset:'',
              leadingIcon:entry.$3=='m22-pass-current'
                  ? Icons.lock_outline_rounded
                  : entry.$3=='m22-pass-new'
                      ? Icons.key_outlined : Icons.verified_user_outlined,
              leadingIconSize:24,
              obscureText:true,
              keyboardType:TextInputType.visiblePassword,
              textInputAction:entry.$3=='m22-pass-confirm'
                  ? TextInputAction.done : TextInputAction.next,
            ),
            const SizedBox(height:20),
          ],
          if(error!=null)Text(error!,style:const TextStyle(color:Colors.red)),
          Sign2DigitalPrimaryButton(
            key:const Key('m22-pass-save'),
            label:'Change Password',
            loading:saving,
            onPressed:save,
          ),
        ]),
      ))),
    ])),
  );
}
