import '../../../../core/navigation/sign2digital_navigation.dart';
import 'otp_verification_screen.dart';

// Sign2Digital Forgot Password UI Package — refined screen (2026-10).
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/sign2digital_header.dart';
import '../../../../core/widgets/sign2digital_input_field.dart';
import '../../../../core/widgets/sign2digital_primary_button.dart';
import 'login_screen.dart';

/// Pure presentation. A future state controller may provide [onResetRequested]
/// without changing this UI or suggesting that a message has been sent.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.onResetRequested});

  final ValueChanged<String>? onResetRequested;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _returnToLogin() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      navigator.pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      );
    }
  }

  void _requestReset() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final email = _emailController.text.trim();
    if (widget.onResetRequested != null) {
      widget.onResetRequested!(email);
      return;
    }
    Sign2DigitalNavigation.push(context,
      MaterialPageRoute<void>(builder: (_) => const OtpVerificationScreen()),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('UI preview only - no reset code was sent.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: CustomScrollView(
              key: const Key('forgot-password-scroll'),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                SliverToBoxAdapter(
                  child: Sign2DigitalHeader(
                    logoAsset: 'assets/header_logo.png',
                    onBack: _returnToLogin,
                  ),
                ),
                SliverToBoxAdapter(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.screenHorizontal,
                          0,
                          AppSpacing.screenHorizontal,
                          0,
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'Forgot Password?',
                                textAlign: TextAlign.center,
                                style: AppTextStyles.heading,
                              ),
                              const SizedBox(height: 10),
                              Center(
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(maxWidth: 288),
                                  child: Text(
                                    'Enter your email address and we will send '
                                    'you a verification code or reset link',
                                    textAlign: TextAlign.center,
                                    style: AppTextStyles.subtitle,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              Center(
                                child: SizedBox(
                                  width: 274,
                                  height: 161,
                                  child: Image.asset(
                                    'assets/forgot_password.png',
                                    fit: BoxFit.cover,
                                    alignment: Alignment.center,
                                    semanticLabel:
                                        'Secure password recovery illustration',
                                  ),
                                ),
                              ),
                              const SizedBox(height: 25),
                              Sign2DigitalInputField(
                                label: 'E-mail',
                                hintText: 'e.g, Marc@company.ch',
                                iconAsset: 'assets/icons/email.svg',
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.done,
                                autofillHints: const [AutofillHints.email],
                                onFieldSubmitted: (_) => _requestReset(),
                                validator: (value) {
                                  final email = value?.trim() ?? '';
                                  if (email.isEmpty) {
                                    return 'Enter your email address';
                                  }
                                  if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                      .hasMatch(email)) {
                                    return 'Enter a valid email address';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
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
                              label: 'Send Reset Link',
                              onPressed: _requestReset,
                            ),
                          ),
                        ),
                      ),
                      // Same area as Login's 12px gap, 24px account-link row,
                      // and 20px bottom panel padding: action stays aligned.
                      const SizedBox(height: 56),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
