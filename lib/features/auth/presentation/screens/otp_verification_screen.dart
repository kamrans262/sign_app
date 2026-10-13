// Sign2Digital OTP Verification UI package — reusable, frontend-only.
import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/sign2digital_header.dart';
import '../../../../core/widgets/sign2digital_otp_input.dart';
import '../../../../core/widgets/sign2digital_primary_button.dart';

/// Returns true only if a future backend flow actually accepts the resend.
/// UI preview mode has no resend implementation and never claims to send mail.
typedef OtpResendRequest = Future<bool> Function();

/// Presentation-only account verification; no OTP delivery or API calls.
class OtpVerificationScreen extends StatefulWidget {
  const OtpVerificationScreen({
    super.key,
    this.onVerify,
    this.onResend,
    this.onCodeCompleted,
    this.onBack,
  });

  final ValueChanged<String>? onVerify;
  final OtpResendRequest? onResend;
  final ValueChanged<String>? onCodeCompleted;
  final VoidCallback? onBack;

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  Timer? _timer;
  int _secondsRemaining = 60;
  String _code = '';
  bool _resendBusy = false;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsRemaining <= 1) {
        timer.cancel();
        setState(() => _secondsRemaining = 0);
      } else {
        setState(() => _secondsRemaining--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _back() {
    if (widget.onBack != null) {
      widget.onBack!();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  void _verify() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the complete six-digit code.')),
      );
      return;
    }
    if (widget.onVerify != null) {
      widget.onVerify!(_code);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Verification is not connected yet.')),
    );
  }

  Future<void> _resend() async {
    if (_secondsRemaining != 0 || _resendBusy) return;
    if (widget.onResend == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Resending codes is not connected yet.')),
      );
      return;
    }
    setState(() => _resendBusy = true);
    bool accepted = false;
    try {
      accepted = await widget.onResend!();
    } catch (_) {
      // The data layer will eventually provide the translated failure state.
      accepted = false;
    }
    if (!mounted) return;
    setState(() {
      _resendBusy = false;
      if (accepted) _secondsRemaining = 60;
    });
    if (accepted) {
      _startCountdown();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to request a new code.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: CustomScrollView(
                key: const Key('otp-screen-scroll'),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: [
                  SliverToBoxAdapter(
                    child: Sign2DigitalHeader(
                      logoAsset: 'assets/header_logo.png',
                      onBack: _back,
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.screenHorizontal,
                            0,
                            AppSpacing.screenHorizontal,
                            0,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'Verify Your Account',
                                textAlign: TextAlign.center,
                                style: AppTextStyles.heading,
                              ),
                              const SizedBox(height: 10),
                              Center(
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(maxWidth: 288),
                                  child: Text(
                                    'Enter the 6- digit code sent to your email',
                                    style: AppTextStyles.subtitle,
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              Center(
                                child: SizedBox(
                                  width: 274,
                                  height: 161,
                                  child: Image.asset(
                                    'assets/otp_screen.png',
                                    fit: BoxFit.contain,
                                    semanticLabel:
                                        'Verification code illustration',
                                  ),
                                ),
                              ),
                              const SizedBox(height: 25),
                              Sign2DigitalOtpInput(
                                onChanged: (value) => _code = value,
                                onCodeCompleted: widget.onCodeCompleted,
                              ),
                              const SizedBox(height: 25),
                              const Text(
                                'Didn’t receive the code? Check your spam folder',
                                textAlign: TextAlign.center,
                                style: AppTextStyles.subtitle,
                              ),
                              const SizedBox(height: 25),
                              Center(
                                child: Semantics(
                                  button: true,
                                  enabled:
                                      _secondsRemaining == 0 && !_resendBusy,
                                  child: InkWell(
                                    key: const Key('otp-resend-action'),
                                    onTap:
                                        _secondsRemaining == 0 && !_resendBusy
                                        ? _resend
                                        : null,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 8,
                                      ),
                                      child: Text(
                                        _secondsRemaining > 0
                                            ? 'Resent OTP (${_secondsRemaining}s)'
                                            : _resendBusy
                                            ? 'Requesting...'
                                            : 'Resend OTP',
                                        style: AppTextStyles.footerLink
                                            .copyWith(
                                              decoration:
                                                  TextDecoration.underline,
                                              decorationColor:
                                                  AppColors.primary,
                                            ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Column(
                      children: [
                        const Spacer(),
                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 520),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.screenHorizontal,
                              ),
                              child: Sign2DigitalPrimaryButton(
                                key: const Key('otp-verify-button'),
                                label: 'Verify',
                                onPressed: _verify,
                              ),
                            ),
                          ),
                        ),
                        // Shared auth footer space: 12px gap, 24px footer,
                        // and 20px bottom margin, as on Forgot Password.
                        const SizedBox(height: 56),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
