// Sign2Digital Login UI Package — UI-only Figma login composition.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/sign2digital_checkbox.dart';
import '../../../../core/widgets/sign2digital_header.dart';
import '../../../../core/widgets/sign2digital_input_field.dart';
import '../../../../core/widgets/sign2digital_outlined_button.dart';
import '../../../../core/widgets/sign2digital_primary_button.dart';
import 'create_account_screen.dart';
import 'otp_verification_screen.dart';
import 'forgot_password_screen.dart';

/// The login presentation is deliberately backend-independent.
/// Optional callbacks allow future navigation/auth integration without changes
/// to the design or its shared widgets.
class LoginScreen extends StatefulWidget {
  const LoginScreen({
    this.onForgotPassword,
    this.onCreateAccount,
    this.onSubmit,
    this.onGoogle,
    this.onApple,
    super.key,
  });

  final VoidCallback? onForgotPassword;
  final VoidCallback? onCreateAccount;
  final void Function(String email, String password, bool rememberMe)? onSubmit;
  final VoidCallback? onGoogle;
  final VoidCallback? onApple;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const double _headerHeight = 109;
  static const double _heroHeight = 174;
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _keepSignedIn = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showUnavailable(String feature) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature will be available in a future phase.')),
    );
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (widget.onSubmit != null) {
      widget.onSubmit!(
        _emailController.text.trim(),
        _passwordController.text,
        _keepSignedIn,
      );
    } else {
      _showUnavailable('Sign in');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        top: true,
        bottom: true,
        child: LayoutBuilder(
          builder: (context, viewport) {
            final minPanelHeight = math.max(
              0.0,
              viewport.maxHeight - _headerHeight - _heroHeight,
            );
            return SingleChildScrollView(
              key: const Key('login-scroll'),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Sign2DigitalHeader(
                    logoAsset: 'assets/header_logo.png',
                    height: _headerHeight,
                  ),
                  Stack(
                    key: const Key('login-hero-stack'),
                    children: [
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: _heroHeight + 52,
                        child: Image.asset(
                          'assets/login_banner.png',
                          fit: BoxFit.cover,
                          alignment: Alignment.center,
                          semanticLabel:
                              'Outdoor scene with mountain landscape',
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: _heroHeight),
                        child: _LoginPanel(
                          minHeight: minPanelHeight,
                          formKey: _formKey,
                          emailController: _emailController,
                          passwordController: _passwordController,
                          keepSignedIn: _keepSignedIn,
                          onKeepSignedInChanged: (value) {
                            setState(() => _keepSignedIn = value);
                          },
                          onForgotPassword:
                              widget.onForgotPassword ??
                              () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (forgotContext) =>
                                        ForgotPasswordScreen(
                                          onResetRequested: (email) {
                                            Navigator.of(forgotContext).push(
                                              MaterialPageRoute<void>(
                                                builder: (_) =>
                                                    const OtpVerificationScreen(),
                                              ),
                                            );
                                            ScaffoldMessenger.of(forgotContext)
                                                .showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'UI preview only â€” no verification code was sent.',
                                                    ),
                                                  ),
                                                );
                                          },
                                        ),
                                  ),
                                );
                              },
                          onCreateAccount:
                              widget.onCreateAccount ??
                              () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => const CreateAccountScreen(),
                                  ),
                                );
                              },
                          onGoogle:
                              widget.onGoogle ??
                              () => _showUnavailable('Google sign in'),
                          onApple:
                              widget.onApple ??
                              () => _showUnavailable('Apple sign in'),
                          onSubmit: _submit,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _LoginPanel extends StatelessWidget {
  const _LoginPanel({
    required this.minHeight,
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.keepSignedIn,
    required this.onKeepSignedInChanged,
    required this.onForgotPassword,
    required this.onCreateAccount,
    required this.onGoogle,
    required this.onApple,
    required this.onSubmit,
  });

  final double minHeight;
  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool keepSignedIn;
  final ValueChanged<bool> onKeepSignedInChanged;
  final VoidCallback onForgotPassword;
  final VoidCallback onCreateAccount;
  final VoidCallback onGoogle;
  final VoidCallback onApple;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minHeight: minHeight),
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.panel),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x40122536),
            blurRadius: 18,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenHorizontal,
              25,
              AppSpacing.screenHorizontal,
              20,
            ),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Welcome Back', style: AppTextStyles.heading),
                  const SizedBox(height: 10),
                  const Text(
                    'Sign in to your account',
                    style: AppTextStyles.subtitle,
                  ),
                  const SizedBox(height: 20),
                  Sign2DigitalInputField(
                    label: 'E-mail',
                    hintText: 'e.g, Marc@company.ch',
                    iconAsset: 'assets/icons/email.svg',
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    validator: (value) {
                      final email = value?.trim() ?? '';
                      if (email.isEmpty) return 'Enter your email address';
                      if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                          .hasMatch(email)) {
                        return 'Enter a valid email address';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  Sign2DigitalInputField(
                    label: 'Password',
                    hintText: 'e.g, Marc@company.ch',
                    iconAsset: 'assets/icons/password.svg',
                    controller: passwordController,
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.password],
                    onFieldSubmitted: (_) => onSubmit(),
                    validator: (value) => (value == null || value.isEmpty)
                        ? 'Enter your password'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  _KeepSignedInRow(
                    checked: keepSignedIn,
                    onChanged: onKeepSignedInChanged,
                    onForgot: onForgotPassword,
                  ),
                  const SizedBox(height: 20),
                  const _OrDivider(),
                  const SizedBox(height: 20),
                  Sign2DigitalOutlinedButton(
                    label: 'Continue with Google',
                    iconAsset: 'assets/icons/google.svg',
                    onPressed: onGoogle,
                  ),
                  const SizedBox(height: 15),
                  Sign2DigitalOutlinedButton(
                    label: 'Continue with Apple',
                    iconAsset: 'assets/icons/apple.svg',
                    onPressed: onApple,
                  ),
                  const SizedBox(height: 20),
                  Sign2DigitalPrimaryButton(
                    label: 'Log In',
                    onPressed: onSubmit,
                  ),
                  const SizedBox(height: 12),
                  _CreateAccountFooter(onCreateAccount: onCreateAccount),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _KeepSignedInRow extends StatelessWidget {
  const _KeepSignedInRow({
    required this.checked,
    required this.onChanged,
    required this.onForgot,
  });

  final bool checked;
  final ValueChanged<bool> onChanged;
  final VoidCallback onForgot;

  @override
  Widget build(BuildContext context) {
    // Wrap lets each control keep its natural tap width at larger text scales.
    // At the reference width both controls remain on the same line, aligned
    // to opposite edges; on narrow devices the forgot link takes a new line.
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 8,
      children: [
        Sign2DigitalCheckbox(value: checked, onChanged: onChanged),
        TextButton(
          onPressed: onForgot,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
            padding: EdgeInsets.zero,
            minimumSize: const Size(0, 25),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text('Forgot Password?', style: AppTextStyles.smallLink),
        ),
      ],
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppColors.divider, height: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Or',
            style: AppTextStyles.subtitle.copyWith(
              color: AppColors.placeholder,
            ),
          ),
        ),
        const Expanded(child: Divider(color: AppColors.divider, height: 1)),
      ],
    );
  }
}

class _CreateAccountFooter extends StatelessWidget {
  const _CreateAccountFooter({required this.onCreateAccount});

  final VoidCallback onCreateAccount;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      children: [
        const Text('Don’t have an account?', style: AppTextStyles.footer),
        TextButton(
          onPressed: onCreateAccount,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
            padding: EdgeInsets.zero,
            minimumSize: const Size(0, 24),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text(
            'Create an account',
            style: AppTextStyles.footerLink,
          ),
        ),
      ],
    );
  }
}
