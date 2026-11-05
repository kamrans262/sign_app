import 'dart:io';

import '../../../core/services/active_company_session.dart';
import '../../../core/services/sign_api_client.dart';
import '../../auth/data/mobile_auth_repository.dart';
import 'deposit_voice_extraction_service.dart';

/// Signed-in deposits use Laravel for AI transcription and suggestions.
/// Flutter never receives OpenAI credentials or authorizes a payment.
class RemoteDepositVoiceExtractionService implements DepositVoiceExtractionService {
  RemoteDepositVoiceExtractionService({SignApiClient? api})
      : _api=api??MobileAuthRepository.shared.api;
  final SignApiClient _api;

  @override
  Future<DepositVoiceSuggestion> extract(
      String audioPath,String unusedTemporaryKey) async {
    final company=ActiveCompanySession.companyId;
    if(company==null||company<1){
      throw const SignApiException('Select a company before recording deposits.');
    }
    final audio=File(audioPath);
    if(!await audio.exists()){
      throw const SignApiException('Deposit recording not found.');
    }
    final bytes=await audio.readAsBytes();
    if(bytes.length<16||bytes.length>25*1024*1024){
      throw const SignApiException('Invalid deposit audio recording.');
    }
    final response=await _api.postMultipart(
      '/api/v1/deposits/ai/voice',
      filename:audio.uri.pathSegments.last,bytes:bytes,
      companyScoped:true,maxBytes:25*1024*1024,
    );
    if(ActiveCompanySession.companyId!=company){
      throw const SignApiException('Company changed during deposit transcription.');
    }
    final data=response['data'];
    if(data is! Map||data['suggestion'] is! Map){
      throw const SignApiException('Invalid deposit voice suggestion.');
    }
    final suggestion=Map<String,dynamic>.from(data['suggestion'] as Map);
    if(suggestion['saved']!=false||
        suggestion['received']!=false||suggestion['refunded']!=false){
      throw const SignApiException('Untrusted AI payment status.');
    }
    return DepositVoiceSuggestion.fromJson(suggestion);
  }
}
