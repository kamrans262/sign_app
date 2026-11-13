import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sign2digital_support_icon_button.dart';
import '../../../auth/data/mobile_auth_repository.dart';
import '../../data/support_ai_prompt_catalog.dart';
import '../support_assistant_launcher.dart';

/// Put this Home-style icon in Sign2DigitalHeader.trailing. Only its short
/// first-time bubble is temporary; it never moves the form controls.
class SupportAiPromptHint extends StatefulWidget {
  const SupportAiPromptHint({super.key, required this.module, this.onTap});

  final String module;
  final VoidCallback? onTap;

  @override
  State<SupportAiPromptHint> createState() => _SupportAiPromptHintState();
}

class _SupportAiPromptHintState extends State<SupportAiPromptHint>
    with SingleTickerProviderStateMixin {
  static const _storage = FlutterSecureStorage();
  static final Set<String> _introducedThisProcess = <String>{};

  final LayerLink _anchor = LayerLink();
  late final AnimationController _fade;
  OverlayEntry? _bubble;

  @override
  void initState() {
    super.initState();
    _fade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _introduceOnce();
    });
  }

  /// One bubble per signed-in account and AI module across app restarts.
  /// Local secure storage holds only the seen flag, no question or record.
  Future<void> _introduceOnce() async {
    if (SupportAiPromptCatalog.forModule(widget.module) == null ||
        !MobileAuthRepository.shared.isSignedIn) return;
    try {
      final response = await MobileAuthRepository.shared.api.get(
        '/api/v1/me', companyScoped: false);
      final data = response['data'];
      final user = data is Map ? data['user'] : null;
      final userId = user is Map ? user['id']?.toString() : null;
      if (userId == null ||
          !RegExp(r'^[1-9][0-9]*$').hasMatch(userId)) return;
      final key = 's2d_ai_support_intro_v2_${userId}_${widget.module}';
      if (_introducedThisProcess.contains(key) ||
          await _storage.read(key: key) == '1' || !mounted) return;
      if (!_introducedThisProcess.add(key)) return;
      try {
        await _storage.write(key: key, value: '1');
      } catch (_) {
        // Still show at most once in this app process if storage is missing.
      }
      if (mounted) _showBubble();
    } catch (_) {
      // The discovery hint must never block the underlying creation form.
    }
  }

  void _showBubble() {
    _removeBubble();
    _bubble = OverlayEntry(builder: (context) => Positioned(
      top: 0,
      left: 0,
      child: CompositedTransformFollower(
        link: _anchor,
        showWhenUnlinked: false,
        targetAnchor: Alignment.bottomRight,
        followerAnchor: Alignment.topRight,
        offset: const Offset(0, 8),
        child: IgnorePointer(
          child: FadeTransition(
            opacity: _fade,
            child: Material(
              color: AppColors.white,
              elevation: 3,
              shadowColor: const Color(0x18000000),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: AppColors.lightBorder),
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                child: Text(
                  'See a sample AI prompt',
                  maxLines: 1,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ));
    Overlay.of(context).insert(_bubble!);
    _fade.forward(from: 0);
    _hideAfterDelay();
  }

  Future<void> _hideAfterDelay() async {
    await Future<void>.delayed(const Duration(seconds: 4));
    if (!mounted || _bubble == null) return;
    await _fade.reverse();
    if (mounted) _removeBubble();
  }

  void _removeBubble() {
    final entry = _bubble;
    _bubble = null;
    entry?.remove();
    entry?.dispose();
  }

  @override
  void dispose() {
    _removeBubble();
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (SupportAiPromptCatalog.forModule(widget.module) == null) {
      return const SizedBox.shrink();
    }
    return CompositedTransformTarget(
      link: _anchor,
      child: Sign2DigitalSupportIconButton(
        buttonKey: Key('ai-support-sample-${widget.module}'),
        onPressed: () {
          _removeBubble();
          if (widget.onTap != null) {
            widget.onTap!();
          } else {
            SupportAssistantLauncher.show(
              context, screen: widget.module,
              sampleModule: widget.module);
          }
        },
      ),
    );
  }
}
