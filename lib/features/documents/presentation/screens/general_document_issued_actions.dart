import 'package:flutter/material.dart';
import '../../../../core/widgets/sign2digital_approved_confirmation.dart';
import '../../../../core/widgets/sign2digital_styled_bottom_sheet.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sign2digital_subscription_gate.dart';
import '../../../../core/widgets/sign2digital_outlined_button.dart';
import '../../../../core/widgets/sign2digital_primary_button.dart';
import '../../data/remote_general_document_repository.dart';

/// M18 Stage 2 actions. The original editor remains unchanged: every official
/// file comes from the authenticated, hash-verified Laravel issuance service.
class GeneralDocumentIssuedActions extends StatefulWidget {
  const GeneralDocumentIssuedActions({super.key,required this.documentId,
    required this.documentNumber,required this.repository,
    this.suggestedSignerName='',this.suggestedSignerEmail=''});
  final int documentId;
  final String documentNumber;
  final RemoteGeneralDocumentRepository repository;
  final String suggestedSignerName,suggestedSignerEmail;

  @override
  State<GeneralDocumentIssuedActions> createState()=>
    _GeneralDocumentIssuedActionsState();
}

class _GeneralDocumentIssuedActionsState
    extends State<GeneralDocumentIssuedActions> {
  Map<String,dynamic>? _metadata;
  bool _loading=true,_busy=false;
  String? _error;

  @override
  void initState(){
    super.initState();
    _refresh();
  }

  @override
  void didUpdateWidget(covariant GeneralDocumentIssuedActions previous){
    super.didUpdateWidget(previous);
    if(previous.documentId!=widget.documentId||
      previous.repository!=widget.repository){
      _refresh();
    }
  }

  void _notice(String message){
    if(!mounted)return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content:Text(message)));
  }

  Future<void> _refresh() async{
    setState(()=>_loading=true);
    try{
      final data=await widget.repository.issuedMetadata(widget.documentId);
      if(mounted)setState((){
        _metadata=data;_error=null;
      });
    }catch(_){
      if(mounted)setState((){
        _metadata=null;
        _error='Unable to load official document. Check company access or integrity.';
      });
    }finally{
      if(mounted)setState(()=>_loading=false);
    }
  }

  Future<void> _issue() async{
    if(_busy||_loading||_metadata!=null)return;
    final yes=await showDialog<bool>(
      context:context,builder:(dialog)=>Sign2DigitalApprovedConfirmation(
        title:const Text('Issue Official Document'),
        content:const Text('Freeze this exact approved revision into an '
          'immutable server-generated PDF? Issuance cannot be undone.'),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(dialog,false),
            child:const Text('Cancel')),
          TextButton(onPressed:()=>Navigator.pop(dialog,true),
            child:const Text('Issue PDF')),
        ]));
    if(yes!=true||!mounted)return;
    setState(()=>_busy=true);
    try{
      await widget.repository.issue(widget.documentId);
      await _refresh();
      _notice('Official PDF issued and verified.');
    }catch(error){
      if(mounted && !await Sign2DigitalSubscriptionGate.handle(
          context,error)){
        setState(()=>_error=
          'Document issuance failed. Verify approval and storage.');
      }
    }finally{
      if(mounted)setState(()=>_busy=false);
    }
  }

  String get _filename{
    final number=widget.documentNumber.replaceAll(
      RegExp(r'[^A-Za-z0-9_-]'),'_');
    return 'Sign2Digital_General_'+number+'.pdf';
  }

  Future<void> _pdf({bool share=false,int? signature}) async{
    if(_busy||_metadata==null)return;
    setState(()=>_busy=true);
    try{
      final bytes=signature==null
        ? await widget.repository.issuedPdf(widget.documentId)
        : await widget.repository.signedPdf(widget.documentId,signature);
      final name=signature==null?_filename:'Signed_'+_filename;
      if(share){
        await Printing.sharePdf(bytes:bytes,filename:name);
        _notice('Share sheet opened; recipient delivery is not confirmed.');
      }else{
        final opened=await Printing.layoutPdf(name:name,onLayout:(_) async=>bytes);
        if(!opened)throw StateError('Print/save cancelled');
        _notice('Verified PDF print/save workflow opened.');
      }
    }catch(_){
      if(mounted)setState(()=>_error='PDF verification or sharing failed.');
    }finally{
      if(mounted)setState(()=>_busy=false);
    }
  }

  Future<void> _link() async{
    if(_busy||_metadata==null)return;
    setState(()=>_busy=true);
    try{
      final link=await widget.repository.customerLink(widget.documentId);
      await Clipboard.setData(ClipboardData(text:link));
      await _refresh();
      _notice('Private 7-day customer link copied; not emailed.');
    }catch(_){
      if(mounted)setState(()=>_error='Unable to create private customer link.');
    }finally{
      if(mounted)setState(()=>_busy=false);
    }
  }

  Future<Map<String,String>?> _recipientDialog({
    required String title,bool signature=false,
  }) async{
    final name=TextEditingController(text:widget.suggestedSignerName);
    final email=TextEditingController(text:widget.suggestedSignerEmail);
    var mode='pdf';
    try{
      return await showSign2DigitalBottomSheet<Map<String,String>>(
        context:context,isScrollControlled:true,showDragHandle:true,
        builder:(sheet)=>StatefulBuilder(builder:(sheet,setSheet)=>SafeArea(
          child:Padding(padding:EdgeInsets.only(left:20,right:20,top:6,
            bottom:MediaQuery.viewInsetsOf(sheet).bottom+20),
            child:SingleChildScrollView(child:Column(
              mainAxisSize:MainAxisSize.min,
              crossAxisAlignment:CrossAxisAlignment.stretch,children:[
                Text(title,style:const TextStyle(
                  fontFamily:'Inter',fontSize:18,fontWeight:FontWeight.w600,
                  color:AppColors.dark)),
                const SizedBox(height:16),
                if(signature)...[
                  TextField(controller:name,decoration:const InputDecoration(
                    labelText:'Signer Name')),
                  const SizedBox(height:12),
                ],
                TextField(controller:email,
                  keyboardType:TextInputType.emailAddress,
                  decoration:const InputDecoration(labelText:'Recipient Email')),
                if(!signature)...[
                  const SizedBox(height:14),
                  RadioListTile<String>(
                    value:'pdf',groupValue:mode,
                    title:const Text('Send verified PDF attachment'),
                    onChanged:(value)=>setSheet(()=>mode=value??'pdf')),
                  RadioListTile<String>(
                    value:'link',groupValue:mode,
                    title:const Text('Send private document link'),
                    onChanged:(value)=>setSheet(()=>mode=value??'link')),
                ],
                const SizedBox(height:18),
                Sign2DigitalPrimaryButton(
                  label:signature?'Create Signature Request':'Submit Email',
                  onPressed:()=>Navigator.pop(sheet,{
                    'name':name.text.trim(),'email':email.text.trim(),
                    'mode':mode,
                  })),
                const SizedBox(height:8),
                Sign2DigitalOutlinedButton(label:'Cancel',
                  onPressed:()=>Navigator.pop(sheet)),
              ]),
            )),
          ),
        ),
      );
    }finally{
      // Dispose after the bottom sheet has completed its closing transition.
      // Do not use a controller after the route is disposed.
      name.dispose();email.dispose();
    }
  }

  Future<void> _send() async{
    if(_busy||_metadata==null)return;
    final entry=await _recipientDialog(title:'Send Official Document');
    if(entry==null||!mounted)return;
    setState(()=>_busy=true);
    try{
      await widget.repository.send(widget.documentId,
        recipientEmail:entry['email']??'',mode:entry['mode']??'pdf');
      await _refresh();
      _notice('Email submitted to configured transport. Inbox delivery '
        'is not confirmed.');
    }catch(_){
      if(mounted)setState(()=>_error='Email delivery could not be confirmed. '
        'Check delivery history before retrying.');
    }finally{
      if(mounted)setState(()=>_busy=false);
    }
  }

  Future<void> _signature() async{
    if(_busy||_metadata==null)return;
    final entry=await _recipientDialog(
      title:'Request Customer Signature',signature:true);
    if(entry==null||!mounted)return;
    setState(()=>_busy=true);
    try{
      final request=await widget.repository.requestSignature(
        widget.documentId,signerName:entry['name']??'',
        signerEmail:entry['email']??'');
      final link=request['signature_link'] as String;
      await Clipboard.setData(ClipboardData(text:link));
      await _refresh();
      if(!mounted)return;
      final email=await showDialog<bool>(context:context,
        builder:(dialog)=>Sign2DigitalApprovedConfirmation(
          title:const Text('Email Signing Invitation?'),
          content:Text('The private signing link was copied. '
            'Send a separate invitation email to '+(entry['email']??'')+'?'),
          actions:[
            TextButton(onPressed:()=>Navigator.pop(dialog,false),
              child:const Text('Copy Only')),
            TextButton(onPressed:()=>Navigator.pop(dialog,true),
              child:const Text('Send Email')),
          ]));
      if(email==true){
        await widget.repository.send(widget.documentId,
          recipientEmail:entry['email']??'',mode:'signature',
          signatureLink:link,
          signatureRequestId:(request['id'] as num).toInt());
        await _refresh();
        _notice('Signing invitation submitted to mail transport. '
          'Recipient delivery is not confirmed.');
      }else{
        _notice('Private signing link copied. No email was sent.');
      }
    }catch(_){
      if(mounted)setState(()=>_error=
        'Signature request failed. Verify signer details and permissions.');
    }finally{
      if(mounted)setState(()=>_busy=false);
    }
  }

  Future<void> _revoke(int id,{required bool signature}) async{
    if(_busy)return;
    final yes=await showDialog<bool>(context:context,
      builder:(dialog)=>Sign2DigitalApprovedConfirmation(
        title:Text(signature?'Revoke Signing Request?':'Revoke Customer Link?'),
        content:const Text('This permanently disables the selected private link.'),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(dialog,false),
            child:const Text('Cancel')),
          TextButton(onPressed:()=>Navigator.pop(dialog,true),
            child:const Text('Revoke')),
        ]));
    if(yes!=true||!mounted)return;
    setState(()=>_busy=true);
    try{
      if(signature){
        await widget.repository.revokeSignature(widget.documentId,id);
      }else{
        await widget.repository.revokeLink(widget.documentId,id);
      }
      await _refresh();
      _notice('Private access revoked.');
    }catch(_){
      if(mounted)setState(()=>_error='Unable to revoke this private link.');
    }finally{
      if(mounted)setState(()=>_busy=false);
    }
  }

  Widget _heading(String label)=>Padding(
    padding:const EdgeInsets.only(top:18,bottom:8),
    child:Text(label,style:const TextStyle(fontFamily:'Inter',
      fontSize:16,fontWeight:FontWeight.w600,color:AppColors.dark)));

  @override
  Widget build(BuildContext context){
    final meta=_metadata;
    return Column(
      key:const Key('general-document-issuance-actions'),
      crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      _heading('Official Document'),
      if(_loading)const LinearProgressIndicator(),
      if(_error!=null)Padding(
        padding:const EdgeInsets.symmetric(vertical:8),
        child:Text(_error!,key:const Key('general-document-issue-error'),
          style:const TextStyle(fontFamily:'Inter',
            fontSize:12,color:Color(0xFFB42318)))),
      if(!_loading&&meta==null)...[
        const Text('Approved revision is ready for official PDF issuance.',
          style:TextStyle(fontFamily:'Inter',fontSize:13,
            color:AppColors.placeholder)),
        const SizedBox(height:12),
        Sign2DigitalPrimaryButton(
          key:const Key('general-document-issue'),
          label:'Issue Official PDF',enabled:!_busy,onPressed:_issue),
      ],
      if(meta!=null)...[
        Text('Verified source: '+(meta['issue'] is Map
          ?(meta['issue']['sha256']??'').toString():''),
          style:const TextStyle(fontFamily:'Inter',fontSize:11,
            color:AppColors.secondaryText)),
        const SizedBox(height:12),
        Sign2DigitalPrimaryButton(
          key:const Key('general-document-download'),
          label:'Preview / Download PDF',
          enabled:!_busy,onPressed:()=>_pdf()),
        const SizedBox(height:10),
        Sign2DigitalOutlinedButton(
          key:const Key('general-document-share'),
          label:'Share Verified PDF',
          enabled:!_busy,onPressed:()=>_pdf(share:true)),
        const SizedBox(height:10),
        Sign2DigitalOutlinedButton(
          key:const Key('general-document-copy-link'),
          label:'Create & Copy Customer Link',
          enabled:!_busy,onPressed:_link),
        const SizedBox(height:10),
        Sign2DigitalOutlinedButton(
          key:const Key('general-document-send'),
          label:'Send Official Document',
          enabled:!_busy,onPressed:_send),
        const SizedBox(height:10),
        Sign2DigitalOutlinedButton(
          key:const Key('general-document-sign'),
          label:'Request Signature',
          enabled:!_busy,onPressed:_signature),
        _heading('Signature History'),
        for(final raw in (meta['signatures'] as List))
          if(raw is Map)ListTile(
            contentPadding:EdgeInsets.zero,
            title:Text((raw['signer_name']??'Signer').toString()),
            subtitle:Text((raw['status']??'Unknown').toString()),
            trailing:raw['status']=='signed'
              ?TextButton(onPressed:_busy?null:()=>_pdf(
                    signature:(raw['id'] as num).toInt()),
                  child:const Text('Signed PDF'))
              :const ['ready','viewed'].contains(raw['status'])
                ?TextButton(onPressed:_busy?null:()=>_revoke(
                    (raw['id'] as num).toInt(),signature:true),
                  child:const Text('Revoke'))
                :const SizedBox.shrink(),
          ),
        _heading('Email Delivery History'),
        for(final raw in (meta['deliveries'] as List))
          if(raw is Map)ListTile(
            contentPadding:EdgeInsets.zero,
            title:Text((raw['recipient_email']??'Recipient').toString()),
            subtitle:Text(
              (raw['mode']??'').toString()+' · '+
              (raw['status']??'').toString()),
          ),
        _heading('Customer Link History'),
        for(final raw in (meta['links'] as List))
          if(raw is Map)ListTile(
            contentPadding:EdgeInsets.zero,
            title:Text('Link #'+(raw['id']??'').toString()),
            subtitle:Text(raw['revoked_at']==null?'Active until '+
              (raw['expires_at']??'').toString():'Revoked'),
            trailing:raw['revoked_at']==null
              ?TextButton(
                  onPressed:_busy?null:()=>_revoke(
                    (raw['id'] as num).toInt(),signature:false),
                  child:const Text('Revoke'))
              :const SizedBox.shrink(),
          ),
      ],
      const SizedBox(height:16),
    ]);
  }
}
