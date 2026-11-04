import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/active_company_session.dart';
import '../../../jobs/domain/job_model.dart';
import '../../data/remote_labour_repository.dart';

/// Active time is server-authoritative. The one-second ticker only animates
/// an estimated display and is resynchronized on foreground and every action.
class M15LiveTimerPanel extends StatefulWidget {
  const M15LiveTimerPanel({
    super.key,required this.repository,this.job,required this.onUpdated,
  });
  final RemoteLabourRepository repository;
  final JobModel? job;
  final VoidCallback onUpdated;

  @override
  State<M15LiveTimerPanel> createState()=>_M15LiveTimerPanelState();
}

class _M15LiveTimerPanelState extends State<M15LiveTimerPanel>
    with WidgetsBindingObserver {
  LabourTimerSnapshot? _timer;
  Timer? _ticker;
  bool _busy=false;
  String? _error;
  final _rate=TextEditingController();
  final _task=TextEditingController();
  int _displaySeconds=0;
  DateTime? _syncedAt;
  int _refreshSerial=0;

  void _onCompanyChanged() {
    if(!mounted)return;
    // Hide previous-company timer immediately; never flash its details during
    // an in-flight request or when the next company has no timer.
    _refreshSerial++;
    setState(() {
      _timer=null;
      _displaySeconds=0;
      _syncedAt=null;
      _error=null;
    });
    _refresh();
  }

  @override
  void initState(){
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ActiveCompanySession.selected.addListener(_onCompanyChanged);
    _ticker=Timer.periodic(const Duration(seconds:1),(_){
      final timer=_timer;
      if(!mounted||timer==null||timer.status!='running')return;
      setState(()=>_displaySeconds=timer.elapsedSeconds+
          DateTime.now().difference(_syncedAt??DateTime.now()).inSeconds.clamp(0,86400));
    });
    _refresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state){
    if(state==AppLifecycleState.resumed)_refresh();
  }

  @override
  void dispose(){
    WidgetsBinding.instance.removeObserver(this);
    ActiveCompanySession.selected.removeListener(_onCompanyChanged);
    _ticker?.cancel();
    _rate.dispose();
    _task.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    if(!mounted)return;
    final serial=++_refreshSerial;
    final company=ActiveCompanySession.companyId;
    if(company==null){
      setState((){
        _timer=null;
        _displaySeconds=0;
        _syncedAt=null;
        _error='Select a company before tracking work.';
      });
      return;
    }
    try{
      final timer=await widget.repository.timerCurrent();
      if(!mounted||serial!=_refreshSerial||
          ActiveCompanySession.companyId!=company){
        return;
      }
      setState((){
        _timer=timer;
        _displaySeconds=timer.elapsedSeconds;
        _syncedAt=DateTime.now();
        _error=null;
      });
    }catch(_){
      if(mounted&&serial==_refreshSerial){
        setState(()=>_error='Unable to verify current timer. Retry.');
      }
    }
  }

  Future<void> _action(String action) async {
    if(_busy)return;
    if(action=='start'&&widget.job==null){
      setState(()=>_error='Select a job before starting the timer.');
      return;
    }
    setState((){
      _busy=true;
      _error=null;
    });
    try{
      final result=await widget.repository.timerAction(
        action,jobId:widget.job?.id,
        rate:action=='start'&&_rate.text.trim().isNotEmpty?_rate.text.trim():null,
        task:action=='start'?_task.text.trim():null,
      );
      if(!mounted)return;
      setState((){
        _timer=result;
        _displaySeconds=result.elapsedSeconds;
        _syncedAt=DateTime.now();
      });
      widget.onUpdated();
    }catch(_){
      // When connectivity is lost after a successful server action, always
      // re-read actual state instead of replaying a different action blindly.
      await _refresh();
      if(mounted)setState(()=>_error='Timer action could not be confirmed. Check the status before retrying.');
    }finally{
      if(mounted)setState(()=>_busy=false);
    }
  }

  static String _duration(int seconds){
    final h=seconds~/3600;
    final m=(seconds%3600)~/60;
    final s=seconds%60;
    return '${h.toString().padLeft(2,'0')}:'
      '${m.toString().padLeft(2,'0')}:'
      '${s.toString().padLeft(2,'0')}';
  }

  Widget _actionButton(String label,String action,{bool primary=false}){
    return OutlinedButton(
      key:Key('m15-timer-$action'),
      style:OutlinedButton.styleFrom(
        foregroundColor:primary?AppColors.white:AppColors.primary,
        backgroundColor:primary?AppColors.primary:AppColors.white,
        side:const BorderSide(color:AppColors.primary),
        shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(10)),
        padding:const EdgeInsets.symmetric(horizontal:16,vertical:12),
      ),
      onPressed:_busy?null:()=>_action(action),
      child:Text(label,style:const TextStyle(
        fontFamily:'Inter',fontWeight:FontWeight.w600,fontSize:14)),
    );
  }

  @override
  Widget build(BuildContext context){
    final timer=_timer;
    return Container(
      key:const Key('m15-live-timer-panel'),
      padding:const EdgeInsets.all(16),
      decoration:BoxDecoration(
        color:AppColors.white,borderRadius:BorderRadius.circular(10),
        border:Border.all(color:AppColors.lightBorder),
      ),
      child:Column(
        crossAxisAlignment:CrossAxisAlignment.start,
        children:[
          const Text('Work Timer',style:TextStyle(fontFamily:'Inter',
            fontSize:16,fontWeight:FontWeight.w600,color:AppColors.dark)),
          const SizedBox(height:8),
          Text(timer==null?'Checking saved timer...'
            :'Status: ${timer.status.toUpperCase()}',
            style:const TextStyle(fontFamily:'Inter',fontSize:13,
              color:AppColors.secondaryText)),
          const SizedBox(height:9),
          Text(_duration(_displaySeconds),
            key:const Key('m15-timer-elapsed'),
            style:const TextStyle(fontFamily:'Inter',fontSize:24,
              fontWeight:FontWeight.w600,color:AppColors.primary)),
          if(timer?.status=='stopped')...[
            const SizedBox(height:12),
            Text('Job: ${widget.job?.title??'Select Job above'}',
              style:const TextStyle(fontFamily:'Inter',fontSize:13)),
            const SizedBox(height:8),
            TextField(key:const Key('m15-timer-task'),controller:_task,
              maxLength:500,decoration:const InputDecoration(
                labelText:'Task (optional)',isDense:true)),
            const SizedBox(height:6),
            TextField(key:const Key('m15-timer-rate'),controller:_rate,
              keyboardType:const TextInputType.numberWithOptions(decimal:true),
              decoration:const InputDecoration(
                labelText:'Hourly Rate CHF (optional)',isDense:true)),
          ],
          if(timer?.isActive==true)...[
            const SizedBox(height:8),
            Text('Job #${timer?.jobId} · Server-recorded time',
              style:const TextStyle(fontFamily:'Inter',fontSize:12,
                color:AppColors.secondaryText)),
          ],
          const SizedBox(height:10),
          Wrap(spacing:8,runSpacing:8,children:[
            if(timer?.status=='stopped')_actionButton('Start','start',primary:true),
            if(timer?.status=='running')_actionButton('Pause','pause'),
            if(timer?.status=='paused')_actionButton('Resume','resume',primary:true),
            if(timer?.isActive==true)_actionButton('Stop & Save','stop',primary:true),
            TextButton(key:const Key('m15-timer-refresh'),
              onPressed:_busy?null:_refresh,child:const Text('Refresh')),
          ]),
          if(_error!=null)...[
            const SizedBox(height:8),
            Text(_error!,key:const Key('m15-timer-error'),style:const TextStyle(
              fontFamily:'Inter',fontSize:12,color:Colors.red)),
          ],
          const SizedBox(height:4),
          const Text('Running time is estimated onscreen; the server confirms saved minutes.',
            style:TextStyle(fontFamily:'Inter',fontSize:11,color:AppColors.secondaryText)),
        ],
      ),
    );
  }
}
