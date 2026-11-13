import '../../../../core/navigation/sign2digital_navigation.dart';
import 'package:flutter/material.dart';

import '../../../../core/services/active_company_session.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sign2digital_bottom_navigation_bar.dart';
import '../../../../core/widgets/sign2digital_dashboard_header.dart';
import '../../../../core/widgets/sign2digital_entry_list_card.dart';
import '../../../../core/widgets/sign2digital_search_field.dart';
import '../../../auth/data/mobile_auth_repository.dart';
import '../../../clients/presentation/widgets/sign2digital_details_tabs.dart';
import '../../data/demo_equipment_loan_repository.dart';
import '../../data/remote_equipment_loan_repository.dart';
import '../../domain/equipment_loan_record.dart';
import 'create_equipment_loan_screen.dart';
import 'equipment_loan_details_screen.dart';

/// Original scope Q60: Active / Returned / Overdue lending ledger.
class EquipmentLoansScreen extends StatefulWidget {
  const EquipmentLoansScreen({super.key,this.repository,
    this.onNavigationSelected,this.onNotificationTap,this.onProfileTap});
  final EquipmentLoanRepository? repository;
  final ValueChanged<int>? onNavigationSelected;
  final VoidCallback? onNotificationTap,onProfileTap;

  @override
  State<EquipmentLoansScreen> createState()=>_EquipmentLoansScreenState();
}

class _EquipmentLoansScreenState extends State<EquipmentLoansScreen> {
  late EquipmentLoanRepository _repository;
  final _search=TextEditingController();
  List<EquipmentLoanRecord> _rows=[];
  bool _loading=true;
  String? _error;
  int _tab=0;
  int _loadGeneration=0;

  @override
  void initState(){
    super.initState();
    _repository=widget.repository??(MobileAuthRepository.shared.isSignedIn
      ?RemoteEquipmentLoanRepository.shared
      :const DemoEquipmentLoanRepository());
    _load();
    ActiveCompanySession.selected.addListener(_companyChanged);
  }

  void _companyChanged(){
    if(mounted)_load();
  }

  @override
  void didUpdateWidget(covariant EquipmentLoansScreen old){
    super.didUpdateWidget(old);
    if(old.repository!=widget.repository&&widget.repository!=null){
      _repository=widget.repository!;
      _load();
    }
  }

  @override
  void dispose(){
    ActiveCompanySession.selected.removeListener(_companyChanged);
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async{
    if(!mounted)return;
    final generation=++_loadGeneration;
    setState((){
      _loading=true;_error=null;_rows=[];
    });
    try{
      final result=await _repository.listLoans();
      if(mounted&&generation==_loadGeneration)setState((){
        _rows=result;_loading=false;
      });
    }catch(_){
      if(mounted&&generation==_loadGeneration)setState((){
        _loading=false;
        _error='Unable to load equipment loans';
      });
    }
  }

  List<EquipmentLoanRecord> get _visible{
    final status=switch(_tab){
      0=>EquipmentLoanStatus.active,
      1=>EquipmentLoanStatus.returned,
      _=>EquipmentLoanStatus.overdue,
    };
    final filtered=_rows.where((r)=>r.status==status&&
      r.matches(_search.text)).toList();
    filtered.sort((a,b)=>b.loanDate.compareTo(a.loanDate));
    return filtered;
  }

  void _notice(String value){
    if(!mounted)return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(value)));
  }

  Future<void> _create() async{
    final result=await Sign2DigitalNavigation.push<EquipmentLoanRecord>(context,
      MaterialPageRoute(builder:(_)=>CreateEquipmentLoanScreen(
        repository:_repository)));
    if(result==null||!mounted)return;
    setState(()=>_tab=switch(result.status){
      EquipmentLoanStatus.returned=>1,
      EquipmentLoanStatus.overdue=>2,
      EquipmentLoanStatus.active=>0,
    });
    await _load();
    _notice('Equipment loan saved.');
  }

  Future<void> _open(EquipmentLoanRecord loan) async{
    final id=loan.id;
    if(id==null)return;
    await Sign2DigitalNavigation.push<void>(context,
      MaterialPageRoute(builder:(_)=>EquipmentLoanDetailsScreen(
        loan:loan,repository:_repository)));
    if(mounted)await _load();
  }

  Widget _card(EquipmentLoanRecord record){
    return Sign2DigitalEntryListCard(
      key:Key('equipment-loan-card-'+record.id.toString()),
      leading:const CircleAvatar(radius:20,
        backgroundColor:Color(0xFFE3ECF0),
        child:Icon(Icons.handyman_outlined,
          size:20,color:AppColors.primary)),
      title:record.equipmentName,
      subtitle:record.borrowerName,
      dateText:'Due: '+_date(record.expectedReturnDate),
      trailingValue:'',
      showTrailingValue:false,
      status:record.status.label,shadow:true,
      onTap:()=>_open(record),
    );
  }

  static String _date(DateTime d)=>[
    d.day.toString().padLeft(2,'0'),
    d.month.toString().padLeft(2,'0'),
    d.year.toString(),
  ].join('/');

  @override
  Widget build(BuildContext context){
    final visible=_visible;
    return Scaffold(
      backgroundColor:AppColors.white,
      body:SafeArea(bottom:false,child:Column(children:[
        Sign2DigitalDashboardHeader(
          onNotificationTap:widget.onNotificationTap,
          onProfileTap:widget.onProfileTap),
        Expanded(child:Center(child:ConstrainedBox(
          constraints:const BoxConstraints(maxWidth:720),
          child:Stack(children:[
            CustomScrollView(
              key:const Key('equipment-loans-scroll'),
              slivers:[
                SliverPadding(
                  padding:const EdgeInsets.fromLTRB(20,0,20,12),
                  sliver:SliverToBoxAdapter(child:Column(
                    crossAxisAlignment:CrossAxisAlignment.stretch,children:[
                      const Text('Equipment Loans',
                        style: TextStyle(fontFamily:'Inter',fontSize:22,
                          fontWeight:FontWeight.w600,color:AppColors.dark)),
                      const SizedBox(height:18),
                      Sign2DigitalSearchField(
                        controller:_search,hintText:'Search Equipment Loans',
                        onChanged:(_)=>setState((){}),
                        onTrailingTap:()=>FocusManager.instance.primaryFocus?.unfocus()),
                      const SizedBox(height:18),
                      Sign2DigitalDetailsTabs(
                        labels:const ['Active','Returned','Overdue'],
                        selectedIndex:_tab,horizontalPadding:15,
                        onSelected:(next)=>setState(()=>_tab=next)),
                    ],
                  )),
                ),
                if(_loading)const SliverFillRemaining(
                  hasScrollBody:false,
                  child:Center(child:CircularProgressIndicator()))
                else if(_error!=null)SliverFillRemaining(
                  hasScrollBody:false,
                  child:Center(child:TextButton(
                    key:const Key('equipment-loans-retry'),
                    onPressed:_load,child:Text(_error!+' — Retry'))))
                else if(visible.isEmpty)const SliverFillRemaining(
                  hasScrollBody:false,child:Center(
                    child:Text('No matching equipment loans',
                      key:Key('equipment-loans-empty'),
                      style:TextStyle(color:AppColors.placeholder))))
                else SliverPadding(
                  padding:const EdgeInsets.fromLTRB(20,12,20,95),
                  sliver:SliverList.builder(
                    itemCount:visible.length,
                    itemBuilder:(context,i)=>Padding(
                      padding:const EdgeInsets.only(bottom:16),
                      child:_card(visible[i])))),
              ],
            ),
            Positioned(right:20,bottom:20,child:SizedBox(
              width:50,height:50,
              child:FloatingActionButton(
                key:const Key('equipment-loans-create'),
                heroTag:'equipment-loans-create',
                backgroundColor:AppColors.primary,
                foregroundColor:Colors.white,elevation:3,
                onPressed:_create,
                child:const Icon(Icons.add,size:30)))),
          ]),
        ))),
      ])),
      bottomNavigationBar:Sign2DigitalBottomNavigationBar(
        selectedIndex:4,
        onSelected:(i){
          if(i==4)return;
          Navigator.of(context).maybePop();
          widget.onNavigationSelected?.call(i);
        }),
    );
  }
}
