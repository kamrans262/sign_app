import '../../../core/services/active_company_session.dart';

/// In-memory only. A fresh app process begins with no chat history.
/// Company changes and explicit logout revoke this scope so one company's
/// conversation cannot be displayed to another company or account.
class SupportChatMessage {
  const SupportChatMessage({
    required this.role,
    required this.content,
    this.screen,
    this.samplePrompt,
  });
  final String role;
  final String content;
  final String? screen;
  final String? samplePrompt;
}

abstract final class SupportChatSession {
  static final List<SupportChatMessage> _messages = [];
  static int? _companyId;
  static bool _scoped = false;
  static int _revision = 0;

  static void _checkCompany() {
    final id = ActiveCompanySession.companyId;
    if (!_scoped || id != _companyId) {
      _messages.clear();
      _companyId = id;
      _scoped = true;
      _revision++;
    }
  }

  static int get revision {
    _checkCompany();
    return _revision;
  }

  static List<SupportChatMessage> snapshot() {
    _checkCompany();
    return List<SupportChatMessage>.unmodifiable(_messages);
  }

  static bool append(SupportChatMessage turn, {required int revision}) {
    _checkCompany();
    if (_revision != revision) return false;
    _messages.add(turn);
    // Keep memory usage bounded; server chat history remains max six turns.
    if (_messages.length > 60) _messages.removeRange(0, _messages.length - 60);
    return true;
  }

  static void clear() {
    _messages.clear();
    _companyId = ActiveCompanySession.companyId;
    _scoped = true;
    _revision++;
  }
}
