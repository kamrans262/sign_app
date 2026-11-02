import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/sign2digital_header.dart';
import '../../../../core/widgets/sign2digital_input_field.dart';
import '../../../../core/widgets/sign2digital_primary_button.dart';

/// Final screen used only after the user successfully verifies an email OTP.
/// Reuses the existing Sign2Digital field, header, and button components.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key, required this.onResetPassword});

  final Future<void> Function(String password) onResetPassword;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting || !(_formKey.currentState?.validate() ?? false)) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _submitting = true);
    try {
      await widget.onResetPassword(_password.text);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to reset password. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.white,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: CustomScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: [
                  SliverToBoxAdapter(
                    child: Sign2DigitalHeader(
                      logoAsset: 'assets/header_logo.png',
                      onBack: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.screenHorizontal,
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text('Reset Password', textAlign: TextAlign.center, style: AppTextStyles.heading),
                                const SizedBox(height: 10),
                                const Text('Enter a new password to secure your account.', textAlign: TextAlign.center, style: AppTextStyles.subtitle),
                                const SizedBox(height: 30),
                                Sign2DigitalInputField(
                                  label: 'New Password',
                                  hintText: 'Enter your new password',
                                  iconAsset: 'assets/icons/password.svg',
                                  controller: _password,
                                  obscureText: true,
                                  textInputAction: TextInputAction.next,
                                  validator: (value) {
                                    if (value == null || value.length < 8) return 'Use at least 8 characters';
                                    if (!RegExp(r'[a-z]').hasMatch(value) ||
                                        !RegExp(r'[A-Z]').hasMatch(value) ||
                                        !RegExp(r'[0-9]').hasMatch(value) ||
                                        !RegExp(r'[^a-zA-Z0-9]').hasMatch(value)) {
                                      return 'Use uppercase, lowercase, a number and a symbol';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 20),
                                Sign2DigitalInputField(
                                  label: 'Confirm Password',
                                  hintText: 'Confirm your new password',
                                  iconAsset: 'assets/icons/password.svg',
                                  controller: _confirmation,
                                  obscureText: true,
                                  textInputAction: TextInputAction.done,
                                  onFieldSubmitted: (_) => _submit(),
                                  validator: (value) => value != _password.text
                                      ? 'Passwords do not match'
                                      : null,
                                ),
                                const SizedBox(height: 28),
                                Sign2DigitalPrimaryButton(
                                  label: _submitting ? 'Saving...' : 'Update Password',
                                  onPressed: _submit,
                                  enabled: !_submitting,
                                ),
                              ],
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
      );
}
