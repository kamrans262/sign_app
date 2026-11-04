import 'dart:io';

import '../../../core/services/active_company_session.dart';
import '../../../core/services/sign_api_client.dart';
import '../../auth/data/mobile_auth_repository.dart';
import '../../jobs/data/local_job_photo_source.dart';
import 'expense_voice_extraction_service.dart';

/// M14 expense AI is server-side: no API key is sent to the Flutter app.
/// All returned values are suggestions and require a manual Save Expense action.
class RemoteExpenseVoiceExtractionService implements ExpenseVoiceExtractionService {
  RemoteExpenseVoiceExtractionService({SignApiClient? api})
      : _api = api ?? MobileAuthRepository.shared.api;

  final SignApiClient _api;

  int _company() {
    final id = ActiveCompanySession.companyId;
    if (id == null || id < 1) {
      throw const SignApiException('Select a company before expense dictation.');
    }
    return id;
  }

  @override
  Future<ExpenseVoiceSuggestion> extract(String audioPath,
      String unusedTemporaryApiKey) async {
    final company = _company();
    final file = File(audioPath);
    if (!await file.exists()) {
      throw const SignApiException('Expense recording not found.');
    }
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty || bytes.length > 25 * 1024 * 1024) {
      throw const SignApiException('Invalid expense recording size.');
    }
    final response = await _api.postMultipart('/api/v1/expenses/ai/voice',
      companyScoped: true, filename: file.uri.pathSegments.last,
      bytes: bytes, maxBytes: 25 * 1024 * 1024);
    if (ActiveCompanySession.companyId != company) {
      throw const SignApiException('Company changed during transcription.');
    }
    final data = response['data'];
    if (data is! Map || data['suggestion'] is! Map) {
      throw const SignApiException('Invalid expense AI response.');
    }
    final suggestion = Map<String, dynamic>.from(data['suggestion'] as Map);
    if (suggestion['saved'] != false || suggestion['approved'] != false) {
      throw const SignApiException('Untrusted expense AI suggestion status.');
    }
    return ExpenseVoiceSuggestion.fromJson(suggestion);
  }

  Future<ExpenseVoiceSuggestion> extractReceipt(
      LocalJobPhotoSelection image) async {
    final company = _company();
    if (!RegExp(r'\.(png|jpg|jpeg)$',caseSensitive: false)
        .hasMatch(image.name)) {
      throw const SignApiException(
        'Receipt AI only supports PNG and JPEG images.');
    }
    final response = await _api.postMultipart(
      '/api/v1/expenses/ai/receipt',
      companyScoped: true,
      filename: image.name,
      bytes: image.bytes,
      maxBytes: 5 * 1024 * 1024);
    if (ActiveCompanySession.companyId != company) {
      throw const SignApiException('Company changed during receipt extraction.');
    }
    final data = response['data'];
    if (data is! Map || data['suggestion'] is! Map) {
      throw const SignApiException('Invalid receipt AI response.');
    }
    final suggestion = Map<String,dynamic>.from(data['suggestion'] as Map);
    if (suggestion['approved'] != false || suggestion['saved'] != false) {
      throw const SignApiException('Untrusted receipt AI response.');
    }
    return ExpenseVoiceSuggestion.fromJson(suggestion);
  }
}
