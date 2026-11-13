import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/support_assistant_repository.dart';
import 'getting_started_preview.dart';

class SupportAssistantSheet extends StatefulWidget {
  const SupportAssistantSheet({super.key, required this.screen,
    required this.repository, this.authenticated = true});
  final String screen;
  final SupportAssistantRepository repository;
  final bool authenticated;
  @override
  State<SupportAssistantSheet> createState() => _SupportAssistantSheetState();
}

class _SupportAssistantSheetState extends State<SupportAssistantSheet> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final _turns = <AssistantTurn>[];
  bool _sending = false, _preview = false;
  String? _error;
  static const _questions = [
    'How do I send a quotation?',
    'What is the difference between a deposit and an invoice?',
    'Where can I find signed documents?',
    'How do I invite my employee?',
  ];

  @override
  void dispose() { _controller.dispose(); _scroll.dispose(); super.dispose(); }
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
    final old = List<AssistantTurn>.of(_turns);
    _controller.clear();
    setState(() {
      _error = null; _sending = true;
      _turns.add(AssistantTurn(role: 'user', content: question));
    });
    _bottom();
    try {
      final result = await widget.repository.ask(
        message: question, screen: widget.screen, history: old);
      if (mounted) setState(() => _turns.add(AssistantTurn(
        role: 'assistant', content: result.answer, screen: result.screen)));
    } catch (error) {
      if (mounted) setState(() => _error =
          error.toString().contains('SignApiException')
          ? error.toString().split(': ').last
          : 'AI Support is temporarily unavailable. Please retry.');
    } finally {
      if (mounted) setState(() => _sending = false);
      _bottom();
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
        borderRadius: BorderRadius.circular(10)),
      child: Text(text, style: TextStyle(fontFamily: 'Inter',
        fontSize: 14, height: 1.45,
        color: mine ? AppColors.white : AppColors.dark)),
    ),
  );

  Widget _chat() => Column(children: [
    Expanded(child: ListView(
      key: const Key('support-chat'),
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
      children: [
        _bubble('Hi! I can explain how Sign2Digital works and take you '
          'to the right screen. What would you like help with?', false),
        if (_turns.isEmpty) ...[
          const Text('POPULAR QUESTIONS', style: TextStyle(fontFamily: 'Inter',
            fontSize: 12, color: AppColors.secondaryText,
            fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          for (var i = 0; i < _questions.length; i++)
            Padding(padding: const EdgeInsets.only(bottom: 8),
              child: OutlinedButton(
                key: Key('support-question-$i'),
                onPressed: widget.authenticated ? () => _ask(_questions[i]) : null,
                style: OutlinedButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  foregroundColor: AppColors.dark,
                  padding: const EdgeInsets.all(12),
                  side: const BorderSide(color: AppColors.lightBorder),
                  shape: RoundedRectangleBorder(borderRadius:
                    BorderRadius.circular(10))),
                child: Text(_questions[i], style: const TextStyle(
                  fontFamily: 'Inter', fontSize: 13)),
              )),
        ],
        for (final turn in _turns) ...[
          _bubble(turn.content, turn.role == 'user'),
          if (turn.role == 'assistant' && turn.screen != null)
            Align(alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                key: Key('support-open-' + turn.screen!),
                onPressed: () => _go(turn.screen!),
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: const Text('Open suggested screen'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary)),
              )),
        ],
        if (_sending) const Align(alignment: Alignment.centerLeft,
          child: SizedBox(height: 22, width: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2, color: AppColors.primary))),
        if (_error != null) Text(_error!,
          key: const Key('support-error'),
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
          style: TextButton.styleFrom(foregroundColor: AppColors.primary)),
        const Text('Do not share passwords, OTP codes or payment details. '
          'AI Support cannot change your records.',
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: 'Inter', fontSize: 11,
            color: AppColors.secondaryText)),
        const SizedBox(height: 12),
      ])),
    Padding(padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
      child: Row(children: [
        Expanded(child: TextField(
          key: const Key('support-input'),
          controller: _controller,
          enabled: widget.authenticated && !_sending,
          maxLines: 3, minLines: 1, maxLength: 1400,
          style: const TextStyle(fontFamily: 'Inter',
            fontSize: 14, color: AppColors.dark),
          decoration: InputDecoration(
            counterText: '',
            hintText: widget.authenticated
              ? 'Ask about Sign2Digital...' : 'Sign in to ask AI Support',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.primary))),
          onSubmitted: (_) => _ask(),
        )),
        const SizedBox(width: 10),
        IconButton.filled(
          key: const Key('support-send'),
          tooltip: 'Send question',
          onPressed: widget.authenticated && !_sending ? _ask : null,
          style: IconButton.styleFrom(backgroundColor: AppColors.primary,
            foregroundColor: AppColors.white),
          icon: const Icon(Icons.send_rounded, size: 21)),
      ])),
  ]);

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height -
        MediaQuery.viewInsetsOf(context).bottom;
    return SizedBox(height: height * .86,
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
            Expanded(child: Text(_preview ? 'Getting Started' : 'AI Support',
              style: const TextStyle(fontFamily: 'Inter', fontSize: 20,
                fontWeight: FontWeight.w700, color: AppColors.dark))),
            IconButton(key: const Key('support-close'), tooltip: 'Close',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close, color: AppColors.secondaryText)),
          ])),
        const Divider(height: 1, color: AppColors.lightBorder),
        Expanded(child: _preview
          ? GettingStartedPreview(repository: widget.repository,
              authenticated: widget.authenticated, onDestination: _go)
          : _chat()),
      ]),
    );
  }
}
