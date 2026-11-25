import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../../core/services/active_company_session.dart';
import '../../../core/services/sign_api_client.dart';
import '../../auth/data/mobile_auth_repository.dart';

abstract final class M25StoreKit {
  static const _channel = MethodChannel('sign2digital/storekit');
  static bool get isIos => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  static bool _started=false;
  static bool _working=false;

  static Future<Map<String,dynamic>> catalog(SignApiClient api) async {
    final result=await api.get('/api/v1/billing/apple/catalog',companyScoped:true);
    return Map<String,dynamic>.from(result['data'] as Map);
  }
  static Future<List<Map<String,dynamic>>> products(List<String> ids) async {
    final rows=await _channel.invokeListMethod<dynamic>('products',{'ids':ids}) ?? [];
    return rows.map((x)=>Map<String,dynamic>.from(x as Map)).toList();
  }
  static Future<String> _verify(SignApiClient api,String id,int company) async {
    if(ActiveCompanySession.companyId!=company)throw const SignApiException('Company changed. Select the purchasing company and restore.');
    final response=await api.post('/api/v1/billing/apple/verify',companyScoped:true,data:{'transaction_id':id});
    if(ActiveCompanySession.companyId!=company)throw const SignApiException('Company changed. Restore with the purchasing company.');
    final data=response['data'] as Map;
    if(data['verified']!=true)throw const SignApiException('Apple purchase has not been verified.');
    await _channel.invokeMethod<void>('finish',{'id':id});
    return data['provider_conflict']==true ? 'provider_conflict' : (data['status'] as String? ?? 'pending');
  }
  static Future<String> purchase(SignApiClient api,String product) async {
    if(!isIos || _working)throw const SignApiException('Apple purchase is unavailable.');
    final company=ActiveCompanySession.companyId;
    if(company==null)throw const SignApiException('Select a company.');
    _working=true;
    try {
      final response=await api.post('/api/v1/billing/apple/begin',companyScoped:true);
      if(ActiveCompanySession.companyId!=company)throw const SignApiException('Company changed.');
      final token=(response['data'] as Map)['account_token'];
      if(token is! String)throw const SignApiException('Purchase authorization is unavailable.');
      final result=await _channel.invokeMapMethod<String,dynamic>('purchase',{'id':product,'token':token});
      final status=result?['status'];
      if(status!='purchased')return status as String? ?? 'pending';
      final id=result?['id'];
      if(id is! String)throw const SignApiException('Purchase verification is pending.');
      return await _verify(api,id,company);
    } finally {_working=false;}
  }
  static Future<int> restore(SignApiClient api,{bool userInitiated=true}) async {
    if(!isIos||_working)return 0;
    final company=ActiveCompanySession.companyId;
    if(company==null||!ActiveCompanySession.isOwner)return 0;
    _working=true;
    try {
      final state=await catalog(api);
      if(state['enabled']!=true)return 0;
      final rows=await _channel.invokeListMethod<dynamic>('transactions',{'restore':userInitiated})??[];
      var count=0;
      for(final raw in rows) {
        if(ActiveCompanySession.companyId!=company)break;
        final row=Map<String,dynamic>.from(raw as Map);
        final id=row['id'];
        if(id is! String)continue;
        try {await _verify(api,id,company);count++;}catch(_) { /* Never finish another company's purchase. */ }
      }
      return count;
    } finally {_working=false;}
  }
  static Future<void> manage()=>_channel.invokeMethod<void>('manage');
  static void start() {
    if(!isIos||_started)return;
    _started=true;
    _channel.setMethodCallHandler((call) async {
      if(call.method=='transactionUpdated') await _sync();
    });
    ActiveCompanySession.selected.addListener(()=>unawaited(_sync()));
  }
  static Future<void> _sync() async {
    if(!MobileAuthRepository.shared.isSignedIn)return;
    try {await restore(MobileAuthRepository.shared.api,userInitiated:false);}catch(_) {}
  }
}
