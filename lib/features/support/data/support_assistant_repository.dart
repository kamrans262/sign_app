import '../../../core/services/active_company_session.dart';
import '../../../core/services/sign_api_client.dart';
import '../../auth/data/mobile_auth_repository.dart';

class AssistantTurn {
  const AssistantTurn({required this.role, required this.content, this.screen});
  final String role;
  final String content;
  final String? screen;
}

class AssistantAnswer {
  const AssistantAnswer({required this.answer, this.screen});
  final String answer;
  final String? screen;
}

class GettingStartedProgress {
  const GettingStartedProgress({
    required this.eligible,
    required this.completed,
    this.autoShow = false,
  });
  final bool eligible;
  final bool autoShow;
  final Map<String, bool> completed;
  bool done(String step) => completed[step] == true;
}

abstract class SupportAssistantRepository {
  Future<AssistantAnswer> ask({
    required String message,
    required String screen,
    required List<AssistantTurn> history,
  });
  Future<GettingStartedProgress> progress();
}

/// Uses the existing Sanctum-authenticated Sign2Digital API, not an OpenAI
/// key in Flutter. The backend never receives a document or tenant records.
class RemoteSupportAssistantRepository implements SupportAssistantRepository {
  RemoteSupportAssistantRepository({SignApiClient? api})
      : _api = api ?? MobileAuthRepository.shared.api;
  static final shared = RemoteSupportAssistantRepository();
  final SignApiClient _api;

  Map<String, dynamic> _data(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw const SignApiException('Invalid AI Support response.');
    }
    return data;
  }

  @override
  Future<AssistantAnswer> ask({
    required String message,
    required String screen,
    required List<AssistantTurn> history,
  }) async {
    final text = message.trim();
    if (text.length < 2 || text.length > 1400) {
      throw const SignApiException('Enter a question of up to 1400 characters.');
    }
    final company = ActiveCompanySession.companyId;
    final result = _data(await _api.post('/api/v1/support/assistant',
        companyScoped: company != null,
        data: {
          'message': text,
          'screen': screen,
          'history': [
            for (final turn in history.reversed.take(6).toList().reversed)
              {'role': turn.role, 'content':
                  turn.content.length > 700
                      ? turn.content.substring(0, 700)
                      : turn.content},
          ],
        }));
    if (company != ActiveCompanySession.companyId) {
      throw const SignApiException('Company changed. Please ask again.');
    }
    final answer = result['answer'];
    if (answer is! String || answer.trim().isEmpty ||
        result['read_only'] != true) {
      throw const SignApiException('Invalid AI Support answer.');
    }
    const links = {
      'companies', 'clients', 'jobs', 'quotes', 'documents',
      'invoices', 'expenses', 'deposits', 'labour', 'team',
      'settings', 'support',
    };
    final route = result['screen'];
    return AssistantAnswer(
      answer: answer.trim(),
      screen: route is String && links.contains(route) ? route : null,
    );
  }

  @override
  Future<GettingStartedProgress> progress() async {
    final company = ActiveCompanySession.companyId;
    final result = _data(await _api.get('/api/v1/support/getting-started',
        companyScoped: company != null));
    if (company != ActiveCompanySession.companyId) {
      throw const SignApiException('Company changed. Reload the guide.');
    }
    final raw = result['completed'];
    if (raw is! Map<String, dynamic>) {
      throw const SignApiException('Invalid Getting Started progress.');
    }
    return GettingStartedProgress(
      eligible: result['eligible'] == true,
      autoShow: false, // Preview only, regardless of server configuration.
      completed: {
        for (final key in ['company', 'client', 'job', 'quote'])
          key: raw[key] == true,
      },
    );
  }
}
