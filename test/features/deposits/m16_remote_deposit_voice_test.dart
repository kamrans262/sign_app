import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sign2digital/core/services/active_company_session.dart';
import 'package:sign2digital/core/services/sign_api_client.dart';
import 'package:sign2digital/features/deposits/services/remote_deposit_voice_extraction_service.dart';

void main(){
  late Directory directory;
  late File audio;
  setUp(() async {
    ActiveCompanySession.set(7);
    directory=await Directory.systemTemp.createTemp('s2d-m16-voice-test');
    audio=File(directory.path + '/deposit.m4a');
    await audio.writeAsBytes(List<int>.filled(64,42));
  });
  tearDown(() async {
    ActiveCompanySession.clear();
    await directory.delete(recursive:true);
  });
  SignApiClient client(Future<http.Response> Function(http.Request) cb)=>
      SignApiClient(baseUrl:Uri.parse('https://example.test'),
        tokenProvider:() async=>'m16-app-token',
        activeCompanyId:()=>ActiveCompanySession.companyId,
        httpClient:MockClient(cb));

  test('server-only voice suggests fields without client OpenAI key',
      () async {
    final api=client((request) async {
      expect(request.url.path,'/api/v1/deposits/ai/voice');
      expect(request.headers['Authorization'],'Bearer m16-app-token');
      expect(request.headers['X-Company-Id'],'7');
      expect(request.body.contains('sk-'),false);
      return http.Response(jsonEncode({'data':{'suggestion':{
        'clientName':'Jean Dupont','amount':58.25,
        'depositDate':'2026-11-05','paymentMethod':'bank_transfer',
        'saved':false,'received':false,'refunded':false,
      }}}),200);
    });
    final result=await RemoteDepositVoiceExtractionService(api:api)
        .extract(audio.path,'');
    expect(result.clientName,'Jean Dupont');
    expect(result.amount,58.25);
    expect(result.depositDate,DateTime(2026,11,5));
    api.dispose();
  });

  test('voice rejects forged payment or save status',() async {
    final api=client((request) async=>http.Response(jsonEncode({
      'data':{'suggestion':{
        'clientName':'Jean Dupont','amount':58,
        'saved':true,'received':true,'refunded':false,
      }},
    }),200));
    await expectLater(
      RemoteDepositVoiceExtractionService(api:api).extract(audio.path,''),
      throwsA(isA<SignApiException>()),
    );
    api.dispose();
  });

  test('company switch invalidates a delayed voice response',() async {
    final pending=Completer<http.Response>();
    final api=client((request)=>pending.future);
    final reading=RemoteDepositVoiceExtractionService(api:api)
        .extract(audio.path,'');
    await Future<void>.delayed(const Duration(milliseconds:30));
    ActiveCompanySession.set(8);
    pending.complete(http.Response(jsonEncode({'data':{'suggestion':{
      'amount':100,'saved':false,'received':false,'refunded':false,
    }}}),200));
    await expectLater(reading,throwsA(isA<SignApiException>()));
    api.dispose();
  });
}
