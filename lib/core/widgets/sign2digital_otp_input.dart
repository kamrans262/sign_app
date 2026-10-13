// Sign2Digital OTP Verification UI package — reusable, frontend-only.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';

/// A six-digit code field with one real keyboard input and six visual boxes.
///
/// Using one editable field allows normal Backspace, cursor behavior, and
/// full-code paste without maintaining six separate focus nodes.
class Sign2DigitalOtpInput extends StatefulWidget {
  const Sign2DigitalOtpInput({
    super.key,
    this.onChanged,
    this.onCodeCompleted,
    this.maskDigits = false,
    this.autofocus = false,
  });

  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onCodeCompleted;
  final bool maskDigits;
  final bool autofocus;

  @override
  State<Sign2DigitalOtpInput> createState() => _Sign2DigitalOtpInputState();
}

class _Sign2DigitalOtpInputState extends State<Sign2DigitalOtpInput> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode(debugLabel: 'Sign2Digital OTP');
  String _code = '';

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocusChanged);
  }

  void _handleFocusChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleChanged(String nextCode) {
    setState(() => _code = nextCode);
    widget.onChanged?.call(nextCode);
    if (nextCode.length == 6) widget.onCodeCompleted?.call(nextCode);
  }

  void _focusInput() {
    _focusNode.requestFocus();
    _controller.selection = TextSelection.collapsed(
      offset: _controller.text.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 390.0;
        final gap = math.min(10.0, math.max(4.0, width / 45));
        final boxSize = math.max(0.0, math.min(48.0, (width - gap * 5) / 6));
        final activeIndex = math.min(_code.length, 5);

        return Semantics(
          container: true,
          textField: true,
          label: 'Six-digit verification code',
          value: '${_code.length} of 6 digits entered',
          onTap: _focusInput,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _focusInput,
            child: SizedBox(
              height: math.max(48.0, boxSize),
              width: double.infinity,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // This remains a genuine TextField, able to accept pasted
                  // codes, IME input and Backspace. The six boxes own the UI.
                  Positioned.fill(
                    child: IgnorePointer(
                      child: ExcludeSemantics(
                        child: Opacity(
                          opacity: 0,
                          child: TextField(
                            key: const Key('otp-code-field'),
                            controller: _controller,
                            focusNode: _focusNode,
                            autofocus: widget.autofocus,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.done,
                            textCapitalization: TextCapitalization.none,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(6),
                            ],
                            autofillHints: const [AutofillHints.oneTimeCode],
                            onChanged: _handleChanged,
                            onTapOutside: (_) =>
                                FocusManager.instance.primaryFocus?.unfocus(),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              isCollapsed: true,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < 6; i++) ...[
                        if (i != 0) SizedBox(width: gap),
                        Container(
                          key: Key('otp-box-$i'),
                          width: boxSize,
                          height: boxSize,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF3F6),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              width: 1,
                              color: _focusNode.hasFocus && i == activeIndex
                                  ? AppColors.primary
                                  : AppColors.primary.withAlpha(160),
                            ),
                          ),
                          child: i < _code.length
                              ? Text(
                                  widget.maskDigits ? '•' : _code[i],
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.dark,
                                  ),
                                )
                              : const Icon(
                                  Icons.circle,
                                  size: 6,
                                  color: Color(0xFFC1CBD3),
                                ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
