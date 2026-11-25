import 'package:flutter/material.dart';
import 'sign_api_client.dart';
import '../widgets/sign2digital_approved_confirmation.dart';

abstract final class M25AiConsent {
  static Future<void>? _decision;
  static Future<void> ensure(SignApiClient api, BuildContext? context) async {
    final existing = _decision;
    if (existing != null) {
      await existing;
      final state = await api.get('/api/v1/me/ai-consent');
      if ((state['data'] as Map?)?['allowed'] == true) return;
      throw const SignApiException('AI permission is required.');
    }
    final operation = _ensure(api, context);
    _decision = operation;
    try { await operation; } finally { if (identical(_decision, operation)) _decision = null; }
  }
  static Future<void> _ensure(SignApiClient api, BuildContext? context) async {
    final state = (await api.get('/api/v1/me/ai-consent'))['data'];
    if (state is! Map || state['version'] is! String || state['user_id'] is! int) {
      throw const SignApiException('AI privacy configuration is unavailable.');
    }
    if (state['allowed'] == true) return;
    if (context == null || !context.mounted) {
      throw const SignApiException('AI permission is required.');
    }
    final allowed = await showDialog<bool>(context: context,
      builder: (dialog) => Sign2DigitalApprovedConfirmation(
        title: const Text('AI Assistance'),
        icon: Icons.auto_awesome_outlined,
        content: const Text('Sign2Digital uses OpenAI to prepare documents, '
          'answer support questions, process images and transcribe voice. '
          'Text, recordings, selected attachments and relevant business information '
          'may be shared with OpenAI for these purposes. Do not include unnecessary '
          'personal or confidential information. Manual features remain available. '
          'You can withdraw permission in Privacy & Data.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialog).pop(false), child: const Text('Not Now')),
          TextButton(onPressed: () => Navigator.of(dialog).pop(true), child: const Text('Allow AI Assistance')),
        ],
      ));
    if (allowed != true) throw const SignApiException('AI assistance was not enabled.');
    final updated = await api.put('/api/v1/me/ai-consent', data: {'allowed': true, 'version': state['version'], 'user_id': state['user_id']});
    if ((updated['data'] as Map?)?['allowed'] != true) throw const SignApiException('AI permission was not saved.');
  }
}
