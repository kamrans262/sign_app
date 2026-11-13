import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../jobs/services/voice_recorder_service.dart';
import '../../data/support_ai_prompt_catalog.dart';
import '../../data/support_assistant_repository.dart';
import '../../data/support_chat_session.dart';
import '../../data/support_voice_transcription.dart';
import 'getting_started_preview.dart';

class SupportAssistantSheet extends StatefulWidget {
  const SupportAssistantSheet({
    super.key,
    required this.screen,
    required this.repository,
    this.authenticated = true,
    this.sampleModule,
    this.voiceRecorderFactory,
    this.transcription,
  });

  final String screen;
  final SupportAssistantRepository repository;
  final bool authenticated;
  /// Opens a relevant help card without automatically creating anything.
  final String? sampleModule;
  final VoiceRecorderService Function()? voiceRecorderFactory;
  final SupportVoiceTranscription? transcription;

  @override
  State<SupportAssistantSheet> createState() => _SupportAssistantSheetState();
}

class _SupportAssistantSheetState extends State<SupportAssistantSheet>
    with WidgetsBindingObserver {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  late final List<AssistantTurn> _turns;
  late final int _revision;
  VoiceRecorderService? _recorder;
  bool _sending = false;
  bool _preview = false;
  bool _recording = false;
  bool _microphoneBusy = false;
  bool _transcribing = false;
  String? _error;

  static const _questions = [
    'How do I create a quote for an existing job?',
    'Can I create an expense using AI Voice?',
    'Where can I find signed documents?',
    'How do I invite my employee?',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _revision = SupportChatSession.revision;
    _turns = SupportChatSession.snapshot().map((t) => AssistantTurn(
      role: t.role, content: t.content,
      screen: t.screen, samplePrompt: t.samplePrompt,
    )).toList();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && _recording) {
      unawaited(_stopVoice(submit: false));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final recorder = _recorder;
    _recorder = null;
    if (recorder != null) {
      unawaited(recorder.dispose());
    }
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _go(String screen) => Navigator.of(context).pop(screen);

  void _bottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted && _scroll.hasClients) {
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    }
  });

  Future<void> _ask([String? suggested]) async {
    final question = (suggested ?? _controller.text).trim();
    if (!widget.authenticated || _sending ||
        question.length < 2 || question.length > 1400) return;
    if (SupportChatSession.revision != _revision) {
      setState(() => _error =
        'Your company changed. Close Support and open it again.');
      return;
    }
    final old = List<AssistantTurn>.of(_turns);
    SupportChatSession.append(SupportChatMessage(
      role: 'user', content: question,
    ), revision: _revision);
    _controller.clear();
    setState(() {
      _error = null;
      _sending = true;
      _turns.add(AssistantTurn(role: 'user', content: question));
    });
    _bottom();
    try {
      final result = await widget.repository.ask(
        message: question, screen: widget.screen, history: old);
      final added = SupportChatSession.append(SupportChatMessage(
        role: 'assistant', content: result.answer,
        screen: result.screen, samplePrompt: result.samplePrompt,
      ), revision: _revision);
      if (mounted && added) {
        setState(() => _turns.add(AssistantTurn(
          role: 'assistant', content: result.answer,
          screen: result.screen, samplePrompt: result.samplePrompt,
        )));
      }
    } catch (error) {
      if (mounted && SupportChatSession.revision == _revision) {
        setState(() => _error = error.toString().contains('SignApiException')
          ? error.toString().split(': ').last
          : 'AI Support is temporarily unavailable. Please retry.');
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
        _bottom();
      }
    }
  }

  Future<void> _toggleVoice() async {
    if (!widget.authenticated || _microphoneBusy || _sending ||
        _transcribing) return;
    if (_recording) {
      await _stopVoice(submit: true);
      return;
    }
    final recorder = widget.voiceRecorderFactory?.call() ??
        LocalVoiceRecorderService();
    _recorder = recorder;
    setState(() {
      _microphoneBusy = true;
      _error = null;
    });
    try {
      await recorder.start();
      if (!mounted) {
        await recorder.cancel();
        return;
      }
      setState(() => _recording = true);
    } on VoiceRecordingPermissionException {
      if (mounted) {
        setState(() => _error =
          'Please allow microphone access in your device settings.');
      }
      await recorder.dispose();
      if (identical(_recorder, recorder)) _recorder = null;
    } catch (_) {
      if (mounted) {
        setState(() => _error =
          'Could not start voice recording. Check microphone permission.');
      }
      await recorder.dispose();
      if (identical(_recorder, recorder)) _recorder = null;
    } finally {
      if (mounted) setState(() => _microphoneBusy = false);
    }
  }

  Future<void> _stopVoice({required bool submit}) async {
    if (_microphoneBusy || !_recording) return;
    final recorder = _recorder;
    if (recorder == null) return;
    setState(() {
      _recording = false;
      _microphoneBusy = true;
      _transcribing = submit;
    });
    String? path;
    try {
      if (!submit) {
        await recorder.cancel();
        return;
      }
      path = await recorder.save();
      final question = await (widget.transcription ??
          RemoteSupportVoiceTranscription()).transcribe(path);
      if (!mounted) return;
      if (SupportChatSession.revision != _revision) {
        setState(() => _error = 'Company changed. Please ask again.');
        return;
      }
      _controller.text = question;
      await _ask();
    } catch (error) {
      if (mounted) {
        setState(() => _error = error is VoiceRecordingPermissionException
          ? 'Microphone permission is required.'
          : error.toString().contains('SignApiException')
              ? error.toString().split(': ').last
              : 'Unable to understand the recording. Try again.');
      }
    } finally {
      if (path != null) {
        try {
          final file = File(path);
          if (await file.exists()) await file.delete();
        } catch (_) {
          // No user recording is intentionally retained by AI Support.
        }
      }
      await recorder.dispose();
      if (identical(_recorder, recorder)) _recorder = null;
      if (mounted) {
        setState(() {
          _microphoneBusy = false;
          _transcribing = false;
        });
      }
    }
  }

  Future<void> _copyPrompt(String prompt) async {
    await Clipboard.setData(ClipboardData(text: prompt));
    if (mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Sample AI prompt copied.')),
      );
    }
  }

  Widget _bubble(String text, bool mine) => Align(
    alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
    child: Container(
      constraints: const BoxConstraints(maxWidth: 350),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: mine ? AppColors.primary : const Color(0xFFE3ECF0),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text, style: TextStyle(
        fontFamily: 'Inter', fontSize: 14, height: 1.45,
        color: mine ? AppColors.white : AppColors.dark,
      )),
    ),
  );

  Widget _promptCard(String prompt, {String? title}) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.white,
      border: Border.all(color: AppColors.lightBorder),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Icon(Icons.mic_none_outlined, color: AppColors.primary, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(title ?? 'Sample AI Voice prompt',
            style: const TextStyle(fontFamily: 'Inter', fontSize: 14,
              fontWeight: FontWeight.w600, color: AppColors.dark))),
        ]),
        const SizedBox(height: 10),
        Text(prompt, style: const TextStyle(fontFamily: 'Inter',
          fontSize: 13, height: 1.5, color: AppColors.dark)),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () => _copyPrompt(prompt),
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: const Text('Copy sample prompt'),
          style: TextButton.styleFrom(foregroundColor: AppColors.primary),
        ),
        const Text('Open the creation screen and speak this example using its '
          'AI Voice button. Review all suggestions before saving.',
          style: TextStyle(fontFamily: 'Inter', fontSize: 12,
            color: AppColors.secondaryText)),
      ],
    ),
  );

  static String _destinationLabel(String route) => switch (route) {
    'jobs' => 'Open Jobs',
    'clients' => 'Open Clients',
    'quotes' => 'Open Quotes',
    'documents' => 'Open Documents',
    'invoices' => 'Open Invoices',
    'expenses' => 'Open Expenses',
    'deposits' => 'Open Deposits',
    'labour' => 'Open Time & Labour',
    'equipment' => 'Open Equipment',
    'ai_documents' => 'Open AI Documents',
    'reports' => 'Open Reports',
    'reminders' => 'Open Reminders',
    'companies' => 'Open Company Setup',
    'team' => 'Open Team',
    'settings' => 'Open Profile & Settings',
    _ => 'Open suggested screen',
  };

  Widget _chat() {
    final sample = SupportAiPromptCatalog.forModule(
        widget.sampleModule ?? '');
    return Column(children: [
      Expanded(child: ListView(
        key: const Key('support-chat'),
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
        children: [
          _bubble('Hi! I can explain how Sign2Digital works and take you '
              'to the right screen. Ask by typing or tapping the microphone.',
              false),
          if (sample != null) _promptCard(sample.prompt,
              title: 'AI Voice example: ${sample.title}'),
          if (_turns.isEmpty) ...[
            const Text('POPULAR QUESTIONS', style: TextStyle(
              fontFamily: 'Inter', fontSize: 12,
              color: AppColors.secondaryText,
              fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            for (var i = 0; i < _questions.length; i++)
              Padding(padding: const EdgeInsets.only(bottom: 8),
                child: OutlinedButton(
                  key: Key('support-question-$i'),
                  onPressed: widget.authenticated
                    ? () => _ask(_questions[i]) : null,
                  style: OutlinedButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    foregroundColor: AppColors.dark,
                    padding: const EdgeInsets.all(12),
                    side: const BorderSide(color: AppColors.lightBorder),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
                  child: Text(_questions[i], style: const TextStyle(
                    fontFamily: 'Inter', fontSize: 13)),
                ),
              ),
          ],
          for (final turn in _turns) ...[
            _bubble(turn.content, turn.role == 'user'),
            if (turn.role == 'assistant' && turn.samplePrompt != null)
              _promptCard(turn.samplePrompt!),
            if (turn.role == 'assistant' && turn.screen != null)
              Align(alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  key: Key('support-open-${turn.screen!}'),
                  onPressed: () => _go(turn.screen!),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: Text(_destinationLabel(turn.screen!)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary)),
                ),
              ),
          ],
          if (_sending || _transcribing) Align(
            alignment: Alignment.centerLeft,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(height: 22, width: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.primary)),
              const SizedBox(width: 10),
              Text(_transcribing && !_sending
                  ? 'Transcribing your question...'
                  : 'Preparing guidance...',
                style: const TextStyle(fontFamily: 'Inter',
                  color: AppColors.secondaryText, fontSize: 12)),
            ]),
          ),
          if (_error != null)
            Text(_error!, key: const Key('support-error'),
              style: const TextStyle(fontFamily: 'Inter',
                fontSize: 13, color: Color(0xFFB42318))),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            key: const Key('support-preview-guide'),
            onPressed: () => setState(() => _preview = true),
            icon: const Icon(Icons.checklist_rounded, size: 20),
            label: const Text('Preview Getting Started'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary))),
          TextButton.icon(
            key: const Key('support-help-center'),
            onPressed: () => _go('support'),
            icon: const Icon(Icons.help_outline_rounded, size: 18),
            label: const Text('Help Center & Support Tickets'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary)),
          const Text('Never share passwords, OTPs, or payment details. '
            'AI Support cannot change your records.',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Inter', fontSize: 11,
              color: AppColors.secondaryText)),
          const SizedBox(height: 12),
        ],
      )),
      Padding(padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
        child: Column(children: [
          if (_recording) const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Text('Recording... tap the microphone to send your question',
              style: TextStyle(fontFamily: 'Inter',
                fontSize: 12, color: AppColors.primary))),
          Row(children: [
            Expanded(child: TextField(
              key: const Key('support-input'),
              controller: _controller,
              enabled: widget.authenticated && !_sending &&
                !_recording && !_transcribing,
              maxLines: 3, minLines: 1, maxLength: 1400,
              style: const TextStyle(fontFamily: 'Inter',
                fontSize: 14, color: AppColors.dark),
              decoration: InputDecoration(
                counterText: '',
                hintText: widget.authenticated
                  ? 'Ask about Sign2Digital...'
                  : 'Sign in to ask AI Support',
                prefixIcon: const Icon(Icons.help_outline_rounded,
                  color: AppColors.primary),
                filled: true, fillColor: AppColors.white,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.lightBorder)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.primary))),
              onSubmitted: (_) => _ask(),
            )),
            const SizedBox(width: 8),
            IconButton(
              key: const Key('support-voice'),
              tooltip: _recording ? 'Stop and ask' : 'Ask with voice',
              onPressed: widget.authenticated && !_sending && !_transcribing
                  && !_microphoneBusy ? _toggleVoice : null,
              style: IconButton.styleFrom(
                backgroundColor: _recording
                  ? AppColors.primary : const Color(0xFFE3ECF0),
                foregroundColor: _recording
                  ? AppColors.white : AppColors.primary),
              icon: Icon(_recording
                  ? Icons.stop_rounded : Icons.mic_none_outlined, size: 22),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              key: const Key('support-send'),
              tooltip: 'Send question',
              onPressed: widget.authenticated && !_sending &&
                  !_transcribing && !_recording ? _ask : null,
              style: IconButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white),
              icon: const Icon(Icons.send_rounded, size: 21)),
          ]),
        ])),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height -
        MediaQuery.viewInsetsOf(context).bottom;
    return Theme(
      data: Theme.of(context).copyWith(
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
          surface: AppColors.white),
      ),
      child: SizedBox(height: height * .86,
        child: Column(children: [
          Padding(padding: const EdgeInsets.fromLTRB(20, 5, 16, 10),
            child: Row(children: [
              if (_preview) IconButton(
                key: const Key('support-guide-back'),
                onPressed: () => setState(() => _preview = false),
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  size: 19, color: AppColors.primary))
              else const Icon(Icons.support_agent_outlined,
                size: 24, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(child: Text(
                _preview ? 'Getting Started' : 'AI Support',
                style: const TextStyle(fontFamily: 'Inter', fontSize: 20,
                  fontWeight: FontWeight.w700, color: AppColors.dark))),
              IconButton(
                key: const Key('support-close'),
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close,
                  color: AppColors.secondaryText)),
            ])),
          const Divider(height: 1, color: AppColors.lightBorder),
          Expanded(child: _preview
            ? GettingStartedPreview(repository: widget.repository,
                authenticated: widget.authenticated,
                onDestination: _go)
            : _chat()),
        ]),
      ),
    );
  }
}
