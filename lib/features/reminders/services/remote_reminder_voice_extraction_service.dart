import 'dart:io';

import '../../../core/services/active_company_session.dart';
import '../../../core/services/sign_api_client.dart';
import '../../auth/data/mobile_auth_repository.dart';
import 'reminder_voice_extraction_service.dart';

/// M20 production AI: OpenAI key stays on Laravel, suggestions never schedule.
class RemoteReminderVoiceExtractionService
    implements ReminderVoiceExtractionService {
  RemoteReminderVoiceExtractionService({SignApiClient? api})
      : _api = api ?? MobileAuthRepository.shared.api;

  final SignApiClient _api;

  @override
  Future<ReminderVoiceSuggestion> extract(String audioPath) async {
    final company = ActiveCompanySession.companyId;
    if (company == null || company <= 0) {
      throw const SignApiException('Select a company before using Reminder AI.');
    }
    final file = File(audioPath);
    if (!await file.exists()) {
      throw const SignApiException('The reminder recording was not found.');
    }
    final bytes = await file.readAsBytes();
    if (bytes.length < 16 || bytes.length > 25 * 1024 * 1024) {
      throw const SignApiException('Invalid reminder recording length.');
    }
    final response = await _api.postMultipart(
      '/api/v1/reminders/ai/voice',
      filename: file.uri.pathSegments.last,
      bytes: bytes,
      companyScoped: true,
      maxBytes: 25 * 1024 * 1024,
    );
    if (ActiveCompanySession.companyId != company) {
      throw const SignApiException('Company changed during reminder dictation.');
    }
    final data = response['data'];
    if (data is! Map<String, dynamic> ||
        data['suggestion'] is! Map ||
        data['requires_user_review'] != true ||
        data['saved'] != false ||
        data['scheduled'] != false ||
        data['notified'] != false) {
      throw const SignApiException('Invalid or unsafe reminder AI response.');
    }
    final result = ReminderVoiceSuggestion.fromJson(
      Map<String, dynamic>.from(data['suggestion'] as Map),
    );
    if (!result.hasData) {
      throw const SignApiException('No clear reminder details were found.');
    }
    return result;
  }
}
