import 'dart:io';

import '../../../core/services/active_company_session.dart';
import '../../../core/services/sign_api_client.dart';
import '../../auth/data/mobile_auth_repository.dart';

abstract class SupportVoiceTranscription {
  /// Turn one saved M4A question into text; do not retain the recording.
  Future<String> transcribe(String audioPath);
}

class RemoteSupportVoiceTranscription implements SupportVoiceTranscription {
  RemoteSupportVoiceTranscription({SignApiClient? api})
      : _api = api ?? MobileAuthRepository.shared.api;

  final SignApiClient _api;

  @override
  Future<String> transcribe(String audioPath) async {
    final company = ActiveCompanySession.companyId;
    final file = File(audioPath);
    if (!await file.exists()) {
      throw const SignApiException('Recording not found. Try again.');
    }
    final length = await file.length();
    if (length < 16 || length > 6 * 1024 * 1024) {
      throw const SignApiException('Record a shorter question (maximum 6 MB).');
    }
    final raw = await _api.postMultipart(
      '/api/v1/support/assistant/transcribe',
      filename: 'support-question.m4a',
      bytes: await file.readAsBytes(),
      fieldName: 'file',
      maxBytes: 6 * 1024 * 1024,
      companyScoped: company != null,
    );
    if (company != ActiveCompanySession.companyId) {
      throw const SignApiException('Company changed. Please ask again.');
    }
    final data = raw['data'];
    final text = data is Map<String, dynamic> ? data['text'] : null;
    if (text is! String || text.trim().length < 2 ||
        text.trim().length > 1400) {
      throw const SignApiException(
        'No usable speech was detected. Please record a short question.');
    }
    return text.trim();
  }
}
