import '../../../../core/widgets/sign2digital_form_dialog.dart';
import '../../../../core/navigation/sign2digital_navigation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:printing/printing.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sign2digital_header.dart';
import '../../../../core/widgets/sign2digital_input_field.dart';
import '../../../../core/widgets/sign2digital_selection_field.dart';
import '../../../../core/widgets/sign2digital_selection_sheet.dart';
import '../../../../core/widgets/sign2digital_primary_button.dart';
import '../../../../core/widgets/sign2digital_outlined_button.dart';
import '../../data/remote_support_repository.dart';
import '../../data/profile_preferences_repository.dart';

/// Original screen 74 — connected FAQ and ticket UI in Sign2Digital styling.
class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key, this.repository});
  final RemoteSupportRepository? repository;

  @override
  State<HelpSupportScreen> createState() => _HelpSupportState();
}

class _HelpSupportState extends State<HelpSupportScreen> {
  late final RemoteSupportRepository repo;
  List<SupportFaq> faqs = const [];
  List<SupportTicket> tickets = const [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    repo = widget.repository ?? RemoteSupportRepository.shared;
    refresh();
  }

  Future<void> refresh() async {
    if(!mounted)return;
    setState(() {loading=true;error=null;});
    try {
      final lang = ProfilePreferencesSession.current.value.language;
      final locale = switch(lang) {
        'French'=>'fr','German'=>'de','Italian'=>'it',_=>'en',
      };
      final results=await Future.wait<Object>([
        repo.faqs(locale:locale), repo.tickets(),
      ]);
      if(!mounted)return;
      setState(() {
        faqs=results[0] as List<SupportFaq>;
        tickets=results[1] as List<SupportTicket>;
        loading=false;
      });
    } catch (_) {
      if(mounted)setState(() {loading=false;error='Unable to load support information.';});
    }
  }

  Future<void> newTicket() async {
    final ticket=await Sign2DigitalNavigation.push<SupportTicket>(context,
      MaterialPageRoute<SupportTicket>(
        builder:(_)=>NewSupportTicketScreen(repository:repo)));
    if(!mounted)return;
    if(ticket!=null) {
      await refresh();
      if(mounted)openTicket(ticket);
    }
  }

  void openTicket(SupportTicket ticket) {
    Sign2DigitalNavigation.push<void>(context,
      MaterialPageRoute<void>(builder:(_)=>SupportTicketDetailsScreen(
        ticketId:ticket.id,repository:repo))).then((_) {
          if(mounted)refresh();
        });
  }

  @override
  Widget build(BuildContext context)=>Scaffold(
    backgroundColor:AppColors.white,
    body:SafeArea(child:Column(children:[
      const Sign2DigitalHeader(title:'Help & Support'),
      Expanded(child:Center(child:ConstrainedBox(
        constraints:BoxConstraints(maxWidth:
          MediaQuery.orientationOf(context)==Orientation.landscape
            ?double.infinity:720),
        child:RefreshIndicator(onRefresh:refresh,
          child:ListView(key:const Key('m22-help-scroll'),
            padding:const EdgeInsets.fromLTRB(20,12,20,24),
            children:[
              Sign2DigitalPrimaryButton(
                key:const Key('m22-contact-support'),
                label:'Contact Support / Report a Problem',
                onPressed:newTicket,
                leading:const Icon(Icons.support_agent_outlined,
                  color:AppColors.white,size:20),
              ),
              const SizedBox(height:20),
              const Text('Help Center',style:TextStyle(fontFamily:'Inter',
                fontSize:20,fontWeight:FontWeight.w600,color:AppColors.dark)),
              const SizedBox(height:10),
              if(loading)
                const Center(child:Padding(padding:EdgeInsets.all(28),
                  child:CircularProgressIndicator()))
              else if(error!=null)
                TextButton(key:const Key('m22-support-retry'),
                  onPressed:refresh,child:Text('${error!} Tap to retry.'))
              else ...[
                if(faqs.isEmpty)
                  const Padding(padding:EdgeInsets.all(12),
                    child:Text('No help articles are published yet.',
                      style:TextStyle(color:AppColors.placeholder))),
                for(final faq in faqs)
                  Card(margin:const EdgeInsets.only(bottom:12),
                    child:ExpansionTile(
                      key:Key('m22-faq-${faq.id}'),
                      title:Text(faq.question,style:const TextStyle(
                        fontFamily:'Inter',fontSize:14)),
                      children:[Padding(padding:const EdgeInsets.all(16),
                        child:Align(alignment:Alignment.centerLeft,
                          child:Text(faq.answer,style:const TextStyle(
                            fontFamily:'Inter',color:AppColors.secondaryText))))],
                    )),
                const SizedBox(height:22),
                Text('My Tickets (${tickets.length})',
                  style:const TextStyle(fontFamily:'Inter',
                    fontSize:20,fontWeight:FontWeight.w600,color:AppColors.dark)),
                const SizedBox(height:10),
                if(tickets.isEmpty)
                  const Text('No support tickets yet.',
                    style:TextStyle(color:AppColors.placeholder)),
                for(final ticket in tickets)
                  Card(margin:const EdgeInsets.only(bottom:12),child:ListTile(
                    key:Key('m22-ticket-${ticket.id}'),
                    title:Text(ticket.subject,maxLines:1,
                      overflow:TextOverflow.ellipsis),
                    subtitle:Text('${ticket.reference} · ${ticket.status}'),
                    trailing:const Icon(Icons.chevron_right),
                    onTap:()=>openTicket(ticket))),
              ],
            ],
          )),
      ))),
    ])),
  );
}

class NewSupportTicketScreen extends StatefulWidget {
  const NewSupportTicketScreen({super.key,required this.repository});
  final RemoteSupportRepository repository;
  @override
  State<NewSupportTicketScreen> createState()=>_NewTicketState();
}

class _NewTicketState extends State<NewSupportTicketScreen> {
  final subject=TextEditingController(), description=TextEditingController();
  String category='technical';
  static const categoryLabels=<String,String>{
    'technical':'Technical help','bug':'Report a problem',
    'account':'Account','billing':'Billing question',
    'general':'General','feedback':'Feedback',
  };
  static IconData categoryIcon(String value) => switch(value){
    'technical'=>Icons.build_outlined,
    'bug'=>Icons.bug_report_outlined,
    'account'=>Icons.manage_accounts_outlined,
    'billing'=>Icons.receipt_long_outlined,
    'feedback'=>Icons.rate_review_outlined,
    _=>Icons.help_outline_rounded,
  };
  bool saving=false;
  String? error;
  XFile? screenshot;
  @override
  void dispose(){subject.dispose();description.dispose();super.dispose();}

  Future<void> pickScreenshot()async {
    try{
      final selected=await ImagePicker().pickImage(
        source:ImageSource.gallery,imageQuality:75,maxWidth:1600);
      if(mounted)setState(()=>screenshot=selected);
    }catch(_){
      if(mounted)setState(()=>error='Could not read the selected screenshot.');
    }
  }

  Future<void> submit()async {
    if(saving)return;
    if(subject.text.trim().length<3||description.text.trim().length<10){
      setState(()=>error='Enter a subject and at least 10 description characters.');
      return;
    }
    setState(() {saving=true;error=null;});
    try {
      final ticket=await widget.repository.create(
        category:category,subject:subject.text,description:description.text);
      if(screenshot!=null){
        try {
          await widget.repository.uploadScreenshot(ticket.id,
            await screenshot!.readAsBytes());
        } catch (_) {
          // The ticket remains committed. Do not retry creation or lose details.
          if(mounted){
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content:Text('Ticket created, but the attachment was not uploaded.')));
          }
        }
      }
      if(mounted)Navigator.of(context).pop(ticket);
    }catch(_){
      if(mounted)setState(()=>error='Ticket could not be submitted. Please retry.');
    }finally{
      if(mounted)setState(()=>saving=false);
    }
  }

  Future<void> pickCategory() async {
    final value=await Sign2DigitalSelectionSheet.show(
      context,title:'Issue Category',
      icon:Icons.support_agent_outlined,
      options:categoryLabels.keys.toList(growable:false),
      selected:category,
      labelForOption:(value)=>categoryLabels[value]??value,
      iconForOption:categoryIcon,
      keyForOption:(value)=>Key('m22-support-category-$value'),
    );
    if(mounted&&value!=null)setState(()=>category=value);
  }

  @override
  Widget build(BuildContext context)=>Scaffold(
    backgroundColor:AppColors.white,
    body:SafeArea(child:Column(children:[
      const Sign2DigitalHeader(title:'Contact Support'),
      Expanded(child:Center(child:ConstrainedBox(
        constraints:BoxConstraints(maxWidth:
          MediaQuery.orientationOf(context)==Orientation.landscape
              ? double.infinity : 720),
        child:ListView(padding:const EdgeInsets.all(20),children:[
          Sign2DigitalSelectionField(
            key:const Key('m22-support-category'),
            label:'Issue Category',
            value:categoryLabels[category],
            hintText:'Select issue category',
            iconAsset:'',
            leadingIcon:Icons.support_agent_outlined,
            leadingIconSize:24,
            trailing:const Icon(Icons.keyboard_arrow_down_rounded,
              color:AppColors.secondaryText,size:24),
            onTap:pickCategory,
          ),
          const SizedBox(height:16),
          Sign2DigitalInputField(
            key:const Key('m22-support-subject'),
            label:'Subject',
            hintText:'Briefly describe your issue',
            iconAsset:'',
            leadingIcon:Icons.subject_outlined,
            leadingIconSize:24,
            controller:subject,maxLength:180,
            textInputAction:TextInputAction.next,
          ),
          const SizedBox(height:12),
          Sign2DigitalInputField(
            key:const Key('m22-support-description'),
            label:'What Happened?',
            hintText:'Describe the issue in detail',
            iconAsset:'',
            leadingIcon:Icons.description_outlined,
            leadingIconSize:24,
            controller:description,
            keyboardType:TextInputType.multiline,
            textInputAction:TextInputAction.newline,
            minLines:4,maxLines:6,maxLength:10000,
          ),
          const SizedBox(height:8),
          Sign2DigitalOutlinedButton(
            key:const Key('m22-support-screenshot'),
            label:screenshot==null?'Attach Screenshot (Optional)'
              :'Screenshot Selected',
            onPressed:pickScreenshot,
            primaryOutline:true,
            leading:const Icon(Icons.attach_file,
              color:AppColors.primary,size:20),
          ),
          if(error!=null)
            Text(error!,style:const TextStyle(color:Colors.red)),
          const SizedBox(height:18),
          Sign2DigitalPrimaryButton(
            key:const Key('m22-support-submit'),
            label:'Submit Support Ticket',
            loading:saving,onPressed:submit,
          ),
        ]),
      ))),
    ])),
  );
}

class SupportTicketDetailsScreen extends StatefulWidget {
  const SupportTicketDetailsScreen({super.key,required this.ticketId,
    required this.repository});
  final int ticketId;
  final RemoteSupportRepository repository;
  @override
  State<SupportTicketDetailsScreen> createState()=>_TicketDetailState();
}

class _TicketDetailState extends State<SupportTicketDetailsScreen> {
  final reply=TextEditingController();
  SupportTicketDetail? data;
  bool loading=true,saving=false;
  String? error;
  @override
  void initState(){super.initState();refresh();}
  @override
  void dispose(){reply.dispose();super.dispose();}
  Future<void> refresh()async{
    if(!mounted)return;
    setState(() {loading=true;error=null;});
    try{
      final result=await widget.repository.details(widget.ticketId);
      if(mounted)setState(() {data=result;loading=false;});
    }catch(_){if(mounted)setState((){loading=false;error='Unable to load ticket.';});}
  }
  Future<void> send()async{
    if(saving||reply.text.trim().isEmpty)return;
    setState(()=>saving=true);
    try{
      final result=await widget.repository.reply(widget.ticketId,reply.text);
      reply.clear();
      if(mounted)setState((){data=result;error=null;});
    }catch(_){if(mounted)setState(()=>error='Could not send your reply.');}
    finally{if(mounted)setState(()=>saving=false);}
  }
  Future<void> openAttachment(SupportAttachment attachment) async {
    if (saving) return;
    setState(() { saving = true; error = null; });
    try {
      final bytes = await widget.repository.downloadAttachment(
        widget.ticketId, attachment);
      if (!mounted) return;
      if (attachment.mimeType == 'application/pdf') {
        await Printing.sharePdf(bytes: bytes,
          filename: 'Sign2Digital_Support_${attachment.id}.pdf');
      } else {
        await showDialog<void>(context: context, builder: (dialog) =>
          Sign2DigitalFormDialog(
            content: Image.memory(bytes, fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) =>
                const Text('Could not display this attachment.')),
            actions: [TextButton(
              onPressed: () => Navigator.of(dialog).pop(),
              child: const Text('Close'))],
          ));
      }
    } catch (_) {
      if (mounted) {
        setState(() =>
          error = 'Unable to open the private support attachment.');
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context)=>Scaffold(
    backgroundColor:AppColors.white,
    body:SafeArea(child:Column(children:[
      const Sign2DigitalHeader(title:'Support Ticket'),
      Expanded(child:Center(child:ConstrainedBox(
        constraints:BoxConstraints(maxWidth:
          MediaQuery.orientationOf(context)==Orientation.landscape
              ? double.infinity : 720),
        child:ListView(key:const Key('m22-ticket-detail'),
          padding:const EdgeInsets.all(20),children:[
            if(loading)const Center(child:CircularProgressIndicator())
            else if(error!=null && data==null)
              TextButton(onPressed:refresh,child:Text('${error!} Retry'))
            else if(data!=null)...[
              Text('${data!.ticket.reference} · ${data!.ticket.status}',
                style:const TextStyle(color:AppColors.primary)),
              const SizedBox(height:12),
              Text(data!.ticket.subject,style:const TextStyle(
                fontFamily:'Inter',fontSize:19,fontWeight:FontWeight.w600,
                color:AppColors.dark)),
              const SizedBox(height:10),
              Text(data!.ticket.description),
              const Divider(height:32),
              const Text('Conversation',style:TextStyle(fontFamily:'Inter',
                fontWeight:FontWeight.w600)),
              for(final entry in data!.replies)
                Card(child:ListTile(
                  title:Text(entry.body),
                  subtitle:Text(entry.createdAt))),
              if(data!.attachments.isNotEmpty)...[
                const SizedBox(height:16),
                const Text('Attachments',style:TextStyle(
                  fontFamily:'Inter',fontWeight:FontWeight.w600)),
                const SizedBox(height:8),
                for(final attachment in data!.attachments)
                  Card(child:ListTile(
                    key:Key('m22-attachment-${attachment.id}'),
                    leading:Icon(attachment.mimeType=='application/pdf'
                      ? Icons.picture_as_pdf_outlined
                      : Icons.image_outlined),
                    title:Text(attachment.originalName,
                      maxLines:1,overflow:TextOverflow.ellipsis),
                    subtitle:Text(attachment.mimeType),
                    trailing:const Icon(Icons.open_in_new),
                    onTap:saving ? null : () => openAttachment(attachment),
                  )),
              ],
              if(data!.ticket.status!='closed')...[
                const SizedBox(height:14),
                Sign2DigitalInputField(
                  key:const Key('m22-ticket-reply'),
                  controller:reply,
                  label:'Your Reply',
                  hintText:'Write a reply to this ticket',
                  iconAsset:'',
                  leadingIcon:Icons.reply_outlined,
                  leadingIconSize:24,
                  keyboardType:TextInputType.multiline,
                  textInputAction:TextInputAction.newline,
                  minLines:3,maxLines:4,maxLength:10000,
                ),
                if(error!=null)
                  Text(error!,style:const TextStyle(color:Colors.red)),
                const SizedBox(height:16),
                Sign2DigitalPrimaryButton(
                  key:const Key('m22-ticket-send'),
                  label:'Send Reply',
                  loading:saving,onPressed:send,
                ),
              ],
            ],
          ]),
      ))),
    ])),
  );
}
