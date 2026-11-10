import 'dart:io';

import '../../../core/services/active_company_session.dart';
import '../../../core/services/sign_api_client.dart';
import '../../auth/data/mobile_auth_repository.dart';
import '../models/extracted_job_details.dart';
import 'voice_job_extraction_service.dart';

/// Production Create Job AI: authenticated Laravel proxy, never a mobile API key.
class RemoteVoiceJobExtractionService implements VoiceJobExtractionService {
  RemoteVoiceJobExtractionService({SignApiClient? api})
      : _api = api ?? MobileAuthRepository.shared.api;

  final SignApiClient _api;

  @override
  bool get isConfigured => true;

  @override
  Future<ExtractedJobDetails> extract(String audioPath) async {
    final company = ActiveCompanySession.companyId;
    if (company == null || company <= 0) {
      throw const SignApiException('Select your company before using AI Job Creation.');
    }
    final file = File(audioPath);
    if (!await file.exists()) {
      throw const SignApiException('The recording is missing. Please record again.');
    }
    final size = await file.length();
    if (size < 16 || size > 25 * 1024 * 1024) {
      throw const SignApiException('Recording must be between 16 bytes and 25 MB.');
    }
    final response = await _api.postMultipart(
      '/api/v1/ai/jobs/voice',
      filename: 'job-recording.m4a',
      bytes: await file.readAsBytes(),
      companyScoped: true,
      maxBytes: 25 * 1024 * 1024,
    );
    if (company != ActiveCompanySession.companyId) {
      throw const SignApiException('Company changed while processing the recording.');
    }
    final data = response['data'];
    if (data is! Map<String, dynamic> ||
        data['suggestions'] is! Map<String, dynamic>) {
      throw const SignApiException('AI returned an invalid job suggestion.');
    }
    final suggestions = Map<String, dynamic>.from(
      data['suggestions'] as Map<String, dynamic>,
    );
    suggestions['transcript'] = data['transcript'];
    final parsed = ExtractedJobDetails.fromJson(suggestions);
    if (!parsed.hasSuggestions) {
      throw const SignApiException('No clear job details were found in your recording.');
    }
    return parsed;
  }
}
