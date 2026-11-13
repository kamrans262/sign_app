import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/support_ai_prompt_catalog.dart';
import '../support_assistant_launcher.dart';

/// Small, nonblocking AI Voice discovery hint next to EXISTING creation
/// controls. The support icon pulses briefly only once per module per app run.
class SupportAiPromptHint extends StatefulWidget {
  const SupportAiPromptHint({super.key, required this.module, this.onTap});

  final String module;
  final VoidCallback? onTap;

  @override
  State<SupportAiPromptHint> createState() => _SupportAiPromptHintState();
}

class _SupportAiPromptHintState extends State<SupportAiPromptHint>
    with SingleTickerProviderStateMixin {
  static final Set<String> _animatedModules = <String>{};
  late final AnimationController _animation;

  @override
  void initState() {
    super.initState();
    _animation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
      value: 1,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _animatedModules.add(widget.module) &&
          !MediaQuery.disableAnimationsOf(context)) {
        _pulse();
      }
    });
  }

  Future<void> _pulse() async {
    try {
      for (var i = 0; i < 3 && mounted; i++) {
        await _animation.animateTo(0.4);
        if (!mounted) return;
        await _animation.animateTo(1);
      }
    } on TickerCanceled {
      // The screen can be closed while the hint is pulsing.
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (SupportAiPromptCatalog.forModule(widget.module) == null) {
      return const SizedBox.shrink();
    }
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        key: Key('ai-support-sample-${widget.module}'),
        onPressed: widget.onTap ?? () =>
            SupportAssistantLauncher.show(
              context, screen: widget.module,
              sampleModule: widget.module),
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
          minimumSize: const Size(0, 32)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          FadeTransition(
            opacity: _animation,
            child: const Icon(Icons.support_agent_outlined, size: 19,
              color: AppColors.primary)),
          const SizedBox(width: 6),
          const Flexible(child: Text('See a sample AI prompt',
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontFamily: 'Inter', fontSize: 12,
              fontWeight: FontWeight.w600, color: AppColors.primary))),
          const SizedBox(width: 2),
          const Icon(Icons.chevron_right_rounded, size: 18,
            color: AppColors.primary),
        ]),
      ),
    );
  }
}
