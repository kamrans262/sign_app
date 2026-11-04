import 'dart:io';

import '../../../core/services/active_company_session.dart';
import '../../../core/services/sign_api_client.dart';
import '../../auth/data/mobile_auth_repository.dart';
import 'labour_voice_extraction_service.dart';

/// M15 voice only suggests fields; Laravel owns all API credentials.
class RemoteLabourVoiceExtractionService implements LabourVoiceExtractionService {
  RemoteLabourVoiceExtractionService({SignApiClient? api})
      : _api=api??MobileAuthRepository.shared.api;

  final SignApiClient _api;

  @override
  Future<LabourVoiceSuggestion> extract(String audioPath,
      String unusedTemporaryKey) async {
    final company=ActiveCompanySession.companyId;
    if(company==null||company<1) {
      throw const SignApiException('Select a company before recording labour.');
    }
    final file=File(audioPath);
    if(!await file.exists()) {
      throw const SignApiException('Voice recording not found.');
    }
    final bytes=await file.readAsBytes();
    if(bytes.length<16||bytes.length>25*1024*1024) {
      throw const SignApiException('Invalid labour audio recording.');
    }
    final raw=await _api.postMultipart('/api/v1/labour/ai/voice',
      filename:file.uri.pathSegments.last,bytes:bytes,
      companyScoped:true,maxBytes:25*1024*1024);
    if(ActiveCompanySession.companyId!=company) {
      throw const SignApiException('Company changed while extracting labour.');
    }
    final outer=raw['data'];
    if(outer is! Map||outer['suggestion'] is! Map) {
      throw const SignApiException('Invalid labour voice suggestion.');
    }
    final suggestion=Map<String,dynamic>.from(outer['suggestion'] as Map);
    if(suggestion['saved']!=false||suggestion['approved']!=false) {
      throw const SignApiException('Untrusted labour AI status.');
    }
    return LabourVoiceSuggestion.fromJson(suggestion);
  }
}
