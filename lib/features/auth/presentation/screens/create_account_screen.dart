// Sign2Digital Create Account — presentation-only, no backend authentication.
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/sign2digital_country_selector.dart';
import '../../../../core/widgets/sign2digital_divider.dart';
import '../../../../core/widgets/sign2digital_header.dart';
import '../../../../core/widgets/sign2digital_input_field.dart';
import '../../../../core/widgets/sign2digital_outlined_button.dart';
import '../../../../core/widgets/sign2digital_primary_button.dart';
import '../../../company/presentation/screens/create_company_screen.dart';
import '../../data/account_repository.dart';
import '../../data/demo_account_repository.dart';
import '../../domain/account_profile.dart';
import 'login_screen.dart';

/// A typed frontend draft; dialing code is separate from the phone number.
@immutable
class CreateAccountDraft {
  const CreateAccountDraft({
    required this.fullName,
    required this.email,
    required this.country,
    required this.phoneNumber,
    required this.password,
  });

  final String fullName;
  final String email;
  final Sign2DigitalCountry country;
  final String phoneNumber;
  final String password;
}

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({
    super.key,
    this.onCreateAccount,
    this.onGoogle,
    this.onApple,
    this.accountRepository,
  });

  /// Provided later by the backend integration. No fake success is shown.
  final ValueChanged<CreateAccountDraft>? onCreateAccount;
  final VoidCallback? onGoogle;
  final VoidCallback? onApple;

  /// Replace with a remote repository during API integration.
  final AccountRepository? accountRepository;

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  // +41 belongs to Switzerland, not to the Canadian flag in the mockup.
  Sign2DigitalCountry _country = Sign2DigitalCountries.switzerland;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  void _returnToLogin() {
    FocusManager.instance.primaryFocus?.unfocus();
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      navigator.pushReplacement<void, void>(
        MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      );
    }
  }

  void _showNotConnected(String action) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$action is not connected yet.')));
  }

  bool _submitting = false;

  Future<void> _createAccount() async {
    if (_submitting) return;
    FocusManager.instance.primaryFocus?.unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final draft = CreateAccountDraft(
      fullName: _name.text.trim(),
      email: _email.text.trim(),
      country: _country,
      phoneNumber: _phone.text.trim(),
      password: _password.text,
    );
    if (widget.onCreateAccount != null) {
      widget.onCreateAccount!(draft);
      return;
    }
    // Save only non-secret demo profile fields. Never persist the password.
    setState(() => _submitting = true);
    try {
      final repository =
          widget.accountRepository ?? DemoAccountRepository.shared;
      await repository.saveDraft(
        AccountProfile(
          id: 'demo-current-account',
          fullName: draft.fullName,
          email: draft.email,
          countryIsoCode: draft.country.isoCode,
          dialingCode: draft.country.dialCode,
          phoneNumber: draft.phoneNumber,
        ),
      );
      if (!mounted) return;
      Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => CreateCompanyScreen()));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to prepare the local demo profile.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
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
                key: const Key('create-account-scroll'),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: [
                  SliverToBoxAdapter(
                    child: Sign2DigitalHeader(
                      logoAsset: 'assets/header_logo.png',
                      onBack: _returnToLogin,
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
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text(
                                  'Create Your Account',
                                  style: AppTextStyles.heading,
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  'Get started with Sign2Digital',
                                  style: AppTextStyles.subtitle,
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 25),
                                Sign2DigitalInputField(
                                  label: 'Full Name',
                                  hintText: 'e.g, Marc@company.ch',
                                  iconAsset: 'assets/icons/user.svg',
                                  controller: _name,
                                  keyboardType: TextInputType.name,
                                  textCapitalization: TextCapitalization.words,
                                  textInputAction: TextInputAction.next,
                                  autofillHints: const [AutofillHints.name],
                                  validator: (value) =>
                                      (value?.trim().isEmpty ?? true)
                                      ? 'Enter your full name'
                                      : null,
                                ),
                                const SizedBox(height: 20),
                                Sign2DigitalInputField(
                                  label: 'E-mail',
                                  hintText: 'e.g, Marc@company.ch',
                                  iconAsset: 'assets/icons/email.svg',
                                  controller: _email,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  autofillHints: const [AutofillHints.email],
                                  validator: (value) {
                                    final email = value?.trim() ?? '';
                                    if (email.isEmpty) {
                                      return 'Enter your email';
                                    }
                                    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                        .hasMatch(email)) {
                                      return 'Enter a valid email address';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 20),
                                Sign2DigitalInputField(
                                  label: 'Phone',
                                  hintText: 'e.g, Marc@company.ch',
                                  iconAsset: 'assets/icons/phone.svg',
                                  controller: _phone,
                                  keyboardType: TextInputType.phone,
                                  textInputAction: TextInputAction.next,
                                  inputPrefix: Sign2DigitalCountrySelector(
                                    selected: _country,
                                    onChanged: (selected) =>
                                        setState(() => _country = selected),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Enter your phone number';
                                    }
                                    if (!RegExp(r'^\+?[\d\s()\-]{6,}$')
                                        .hasMatch(value.trim())) {
                                      return 'Enter a valid phone number';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 20),
                                Sign2DigitalInputField(
                                  label: 'Password',
                                  hintText: 'e.g, Marc@company.ch',
                                  iconAsset: 'assets/icons/password.svg',
                                  controller: _password,
                                  obscureText: true,
                                  textInputAction: TextInputAction.next,
                                  autofillHints: const [
                                    AutofillHints.newPassword,
                                  ],
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Enter your password';
                                    }
                                    if (value.length < 8) {
                                      return 'Use at least 8 characters';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 20),
                                Sign2DigitalInputField(
                                  label: 'Confirm Password',
                                  hintText: 'e.g, Marc@company.ch',
                                  iconAsset: 'assets/icons/password.svg',
                                  controller: _confirmPassword,
                                  obscureText: true,
                                  textInputAction: TextInputAction.done,
                                  autofillHints: const [
                                    AutofillHints.newPassword,
                                  ],
                                  onFieldSubmitted: (_) => _createAccount(),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Confirm your password';
                                    }
                                    if (value != _password.text) {
                                      return 'Passwords do not match';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 20),
                                const Sign2DigitalDivider(),
                                const SizedBox(height: 20),
                                Sign2DigitalOutlinedButton(
                                  label: 'Continue with Google',
                                  iconAsset: 'assets/icons/google.svg',
                                  onPressed:
                                      widget.onGoogle ??
                                      () => _showNotConnected('Google sign in'),
                                ),
                                const SizedBox(height: 15),
                                Sign2DigitalOutlinedButton(
                                  label: 'Continue with Apple',
                                  iconAsset: 'assets/icons/apple.svg',
                                  onPressed:
                                      widget.onApple ??
                                      () => _showNotConnected('Apple sign in'),
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
                              padding: const EdgeInsets.fromLTRB(
                                AppSpacing.screenHorizontal,
                                20,
                                AppSpacing.screenHorizontal,
                                0,
                              ),
                              child: Sign2DigitalPrimaryButton(
                                key: const Key('create-account-button'),
                                label: 'Create Account',
                                onPressed: _createAccount,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Semantics(
                          label: 'Already have an account? Sign In',
                          child: Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 6,
                            children: [
                              const Text(
                                'Already have an account?',
                                style: AppTextStyles.footer,
                              ),
                              TextButton(
                                onPressed: _returnToLogin,
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  minimumSize: const Size(60, 40),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text(
                                  'Sign In',
                                  style: AppTextStyles.footerLink,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
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
