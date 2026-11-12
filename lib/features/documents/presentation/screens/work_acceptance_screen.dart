import '../../../../core/navigation/sign2digital_navigation.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sign2digital_subscription_gate.dart';
import '../../../../core/widgets/sign2digital_bottom_navigation_bar.dart';
import '../../../../core/widgets/sign2digital_header.dart';
import '../../../../core/widgets/sign2digital_outlined_button.dart';
import '../../../../core/widgets/sign2digital_primary_button.dart';
import '../../../../core/widgets/sign2digital_selection_sheet.dart';
import '../../../quotes/presentation/widgets/sign2digital_signature_draw_canvas.dart';
import '../../domain/document_record.dart';
import '../../domain/work_acceptance_data.dart';
import '../widgets/sign2digital_document_history.dart';
import 'document_details_screen.dart';

typedef WorkAcceptanceAction = Future<void> Function(DocumentRecord report);

/// Status and read-only signature display for an existing work acceptance.
/// Events, signature and PDF must originate from the selected record.
class WorkAcceptanceScreen extends StatefulWidget {
  const WorkAcceptanceScreen({
    super.key,
    required this.report,
    this.onShareReport,
    this.onViewReport,
    this.onApprove,this.onSend,this.onRevoke,
    this.onEditDraft,this.onRefresh,
    this.onNavigationSelected,
    this.selectedNavigationIndex = 2,
  });

  final DocumentRecord report;
  final WorkAcceptanceAction? onShareReport;
  final WorkAcceptanceAction? onViewReport;
  final WorkAcceptanceAction? onApprove;
  final WorkAcceptanceAction? onSend;
  final WorkAcceptanceAction? onRevoke;
  final WorkAcceptanceAction? onEditDraft;
  final Future<DocumentRecord> Function(DocumentRecord)? onRefresh;
  final ValueChanged<int>? onNavigationSelected;
  final int selectedNavigationIndex;

  @override
  State<WorkAcceptanceScreen> createState() => _WorkAcceptanceScreenState();
}

class _WorkAcceptanceScreenState extends State<WorkAcceptanceScreen> {
  bool _busy = false;
  late DocumentRecord _report;

  @override
  void initState() { super.initState(); _report=widget.report; }

  WorkAcceptanceEvidence? get _evidence => _report.workAcceptance;

  /// Local/demo PDFs and unverified signature drafts are never accepted.
  bool get _hasVerifiedPdf =>
      !_report.demoOnly &&
      (_evidence?.verifiedReportPdf?.isNotEmpty ?? false);

  bool get _hasVerifiedSignature =>
      !_report.demoOnly &&
      const ['accepted', 'accepted_with_reservations']
          .contains(_report.status.toLowerCase()) &&
      (_evidence?.verifiedSignaturePng?.isNotEmpty ?? false);

  WorkAcceptanceEvent? _event(WorkAcceptanceStage stage) {
    final matching = _evidence?.events.where((item) =>
      item.documentId == _report.id && item.stage == stage);
    if (matching == null || matching.isEmpty) return null;
    return matching.reduce((a, b) =>
        a.occurredAt.isAfter(b.occurredAt) ? a : b);
  }

  bool _recorded(WorkAcceptanceStage stage, WorkAcceptanceEvent? event) {
    if (event == null || event.actorName.trim().isEmpty) return false;
    if (_report.demoOnly) return true;
    if ((stage == WorkAcceptanceStage.clientSigned ||
         stage == WorkAcceptanceStage.completed) && !_hasVerifiedSignature) {
      return false;
    }
    if (stage == WorkAcceptanceStage.completed &&
        !['completed','accepted','accepted_with_reservations']
            .contains(_report.status.toLowerCase())) {
      return false;
    }
    return true;
  }

  String _date(DateTime date) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final local = date.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    return '${days[local.weekday - 1]}, ${local.day} '
        '${months[local.month - 1]} ${local.year}, '
        '$hour:${local.minute.toString().padLeft(2, '0')} '
        '${local.hour >= 12 ? 'PM' : 'AM'}';
  }

  void _notice(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.removeCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _confirm(String heading,String message) async {
    final answer=await Sign2DigitalSelectionSheet.showCustom<bool>(
      context:context,title:heading,subtitle:message,
      icon:Icons.fact_check_outlined,
      builder:(sheet)=>Padding(padding:const EdgeInsets.fromLTRB(20,0,20,20),
        child:Row(children:[
          Expanded(child:Sign2DigitalOutlinedButton(
            label:'Cancel',
            onPressed:()=>Navigator.of(sheet).pop(false))),
          const SizedBox(width:12),
          Expanded(child:Sign2DigitalPrimaryButton(
            label:'Confirm',
            onPressed:()=>Navigator.of(sheet).pop(true))),
        ])),
    );
    return answer==true;
  }

  Future<void> _run(WorkAcceptanceAction action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action(_report);
      if(widget.onRefresh!=null) {
        final fresh=await widget.onRefresh!(_report);
        if(mounted)setState(()=>_report=fresh);
      }
    } catch (error) {
      if (mounted && !await Sign2DigitalSubscriptionGate.handle(
          context, error)) {
        _notice('The report action could not be completed.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share() async {
    if (!_hasVerifiedPdf) {
      _notice('A verified work acceptance report is not available to share.');
      return;
    }
    await _run(widget.onShareReport ?? (report) async {
      final pdf = report.workAcceptance!.verifiedReportPdf!;
      await Printing.sharePdf(
        bytes: pdf,
        filename: 'Work_Acceptance_${report.number.replaceAll(
          RegExp(r'[^A-Za-z0-9_-]'), '_')}.pdf',
      );
    });
  }

  Future<void> _view() async {
    if (!_hasVerifiedPdf) {
      _notice('A verified work acceptance report is not available to view.');
      return;
    }
    await _run(widget.onViewReport ?? (report) async {
      await Sign2DigitalNavigation.push<void>(context,MaterialPageRoute<void>(
        builder: (_) => DocumentDetailsScreen(
          documentId: report.id,
          document: report,
          initialTab: 1,
        ),
      ));
    });
  }

  Widget _tracking() => Column(
    key: const Key('work-acceptance-tracking'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var i = 0; i < WorkAcceptanceStage.values.length; i++) ...[
        Builder(builder: (_) {
          final stage = WorkAcceptanceStage.values[i];
          final event = _event(stage);
          final done = _recorded(stage, event);
          return KeyedSubtree(
            key: Key('work-acceptance-stage-${stage.name}'),
            child: Sign2DigitalTrackingRow(
              title: stage.label,
              completed: done,
              dateText: done ? _date(event!.occurredAt) : null,
              actorText: done ? 'Marked by ${event!.actorName}' : null,
            ),
          );
        }),
        if (i != WorkAcceptanceStage.values.length - 1)
          const SizedBox(height: 20),
      ],
    ],
  );

  void _navigation(int index) {
    if (index == widget.selectedNavigationIndex) {
      Navigator.of(context).maybePop();
      return;
    }
    Navigator.of(context).pop();
    widget.onNavigationSelected?.call(index);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.white,
    body: SafeArea(
      bottom: false,
      child: Column(children: [
        Sign2DigitalHeader(
          title: 'Work Acceptance',
          onBack: () => Navigator.of(context).maybePop(),
        ),
        Expanded(child: SingleChildScrollView(
            key: const Key('work-acceptance-scroll'),
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_report.demoOnly) ...[
                  const Text(
                    'DEMO — lifecycle events are sample data, not verified.',
                    key: Key('work-acceptance-demo-label'),
                    style: TextStyle(
                      fontFamily: 'Inter', fontSize: 12,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                _tracking(),
                const SizedBox(height: 40),
                if (const ['accepted', 'accepted_with_reservations']
                    .contains(_report.status.toLowerCase()) &&
                    _hasVerifiedSignature) ...[
                  const Text('Client Signature', style: TextStyle(
                    fontFamily: 'Inter', fontSize: 18,
                    fontWeight: FontWeight.w600, color: AppColors.dark,
                  )),
                  const SizedBox(height: 10),
                  Sign2DigitalSignatureDisplay(
                    signaturePng: _evidence!.verifiedSignaturePng,
                  ),
                  const SizedBox(height: 25),
                ],
                if(!_report.demoOnly &&
                    _evidence?.acceptanceResult!=null) ...[
                  Text(_evidence!.acceptanceResult=='accepted_with_reservations'
                      ?'Accepted with Reservations':'Accepted',
                    style:const TextStyle(fontFamily:'Inter',fontSize:16,
                      fontWeight:FontWeight.w600,color:AppColors.dark)),
                  if(_evidence!.reservation.trim().isNotEmpty)
                    Padding(padding:const EdgeInsets.only(top:8),
                      child:Text('Reservations: ${_evidence!.reservation}')),
                  if(_evidence!.outstandingIssues.trim().isNotEmpty)
                    Padding(padding:const EdgeInsets.only(top:8),
                      child:Text('Outstanding Issues: ${_evidence!.outstandingIssues}')),
                  if(_evidence!.signedAt!=null)
                    Padding(padding:const EdgeInsets.only(top:8),
                      child:Text('Signed: ${_date(_evidence!.signedAt!)}')),
                  if(_evidence!.customerRating!=null)
                    Padding(padding:const EdgeInsets.only(top:8),
                      child:Text('Customer Rating: ${_evidence!.customerRating}/5')),
                  if(_evidence!.customerComment.trim().isNotEmpty)
                    Padding(padding:const EdgeInsets.only(top:8),
                      child:Text('Customer Comment: ${_evidence!.customerComment}')),
                  const SizedBox(height:20),
                ],
                Row(children: [
                  Expanded(child: Sign2DigitalOutlinedButton(
                    key: const Key('work-acceptance-share'),
                    label: 'Share',
                    primaryOutline: true,
                    enabled: !_busy,
                    onPressed: _share,
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: Sign2DigitalPrimaryButton(
                    key: const Key('work-acceptance-view-report'),
                    label: 'View Full Report',
                    enabled: !_busy,
                    onPressed: _view,
                  )),
                ]),
                if(_report.status=='draft'&&widget.onEditDraft!=null) ...[
                  const SizedBox(height:12),
                  Sign2DigitalOutlinedButton(label:'Edit Acceptance Draft',
                    enabled:!_busy,onPressed:()=>_run(widget.onEditDraft!)),
                ],
                if(_report.status=='draft'&&widget.onApprove!=null) ...[
                  const SizedBox(height:12),
                  Sign2DigitalPrimaryButton(label:'Approve Acceptance PDF',
                    enabled:!_busy,onPressed:() async {
                      if(await _confirm('Approve Acceptance',
                        'Freeze this exact report version for customer signing?')) {
                        await _run(widget.onApprove!);
                      }
                    }),
                ],
                if(_report.status=='approved'&&widget.onSend!=null) ...[
                  const SizedBox(height:12),
                  Sign2DigitalPrimaryButton(label:'Send to Customer',
                    enabled:!_busy,onPressed:() async {
                      if(await _confirm('Email Customer',
                        'Send a private, expiring signing link to the linked customer?')) {
                        await _run(widget.onSend!);
                      }
                    }),
                ],
                if(['sent','viewed'].contains(_report.status)&&
                    widget.onRevoke!=null) ...[
                  const SizedBox(height:12),
                  Sign2DigitalOutlinedButton(label:'Revoke Signing Link',
                    enabled:!_busy,onPressed:() async {
                      if(await _confirm('Revoke Signing Link',
                        'Invalidate the current customer acceptance link?')) {
                        await _run(widget.onRevoke!);
                      }
                    }),
                ],
              ],
            ),
          ),
        ),
      ]),
    ),
    bottomNavigationBar: Sign2DigitalBottomNavigationBar(
      selectedIndex: widget.selectedNavigationIndex,
      onSelected: _navigation,
    ),
  );
}
