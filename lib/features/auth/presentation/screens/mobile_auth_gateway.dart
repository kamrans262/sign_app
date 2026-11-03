import 'package:flutter/material.dart';

import '../../../../core/services/sign_api_client.dart';
import '../../../company/data/remote_company_repository.dart';
import 'company_entry_gate.dart';
import '../../data/mobile_auth_repository.dart';
import 'create_account_screen.dart';
import 'forgot_password_screen.dart';
import 'login_screen.dart';
import 'otp_verification_screen.dart';
import 'reset_password_screen.dart';

/// Coordinates the existing Sign2Digital authentication screens.
///
/// Reuses the approved Login, Create Account, Forgot Password and OTP layouts.
/// The mobile dashboard is never entered before the server verifies email OTP.
class MobileAuthGateway extends StatefulWidget {
  const MobileAuthGateway({super.key, this.repository});

  final MobileAuthRepository? repository;

  @override
  State<MobileAuthGateway> createState() => _MobileAuthGatewayState();
}

class _MobileAuthGatewayState extends State<MobileAuthGateway> {
  bool _busy = false;
  MobileAuthRepository get _auth => widget.repository ?? MobileAuthRepository.shared;

  void _error(Object error) {
    if (!mounted) return;
    final message = error is SignApiException ? error.message : 'Unable to complete the request.';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _execute(Future<void> Function() action) async {
    if (_busy) return;
    _busy = true;
    try {
      await action();
    } catch (error) {
      _error(error);
    } finally {
      _busy = false;
    }
  }

  void _openRegistration() {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => CreateAccountScreen(onCreateAccount: _register),
    ));
  }

  void _openForgotPassword() {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => ForgotPasswordScreen(onResetRequested: _forgot),
    ));
  }

  void _login(String email, String password, bool rememberMe) {
    _execute(() async {
      final challenge = await _auth.beginLogin(email, password);
      if (!mounted) return;
      _openOtp(challenge, email: email, rememberMe: rememberMe);
    });
  }

  void _register(CreateAccountDraft draft) {
    _execute(() async {
      final challenge = await _auth.beginRegistration(draft);
      if (!mounted) return;
      _openOtp(challenge, email: draft.email, rememberMe: true);
    });
  }

  void _forgot(String email) {
    _execute(() async {
      final challenge = await _auth.beginPasswordReset(email);
      if (!mounted) return;
      _openOtp(challenge, email: email, rememberMe: false);
    });
  }

  void _openOtp(
    EmailOtpChallenge initialChallenge, {
    required String email,
    required bool rememberMe,
  }) {
    var challenge = initialChallenge;
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (otpContext) => OtpVerificationScreen(
        onVerify: (code) {
          _execute(() async {
            final outcome = await _auth.verify(
              challenge,
              code,
              rememberMe: rememberMe,
            );
            if (!mounted || !otpContext.mounted) return;
            if (outcome.purpose == 'reset') {
              final proof = outcome.resetToken;
              if (proof == null) throw const SignApiException('Reset verification failed.');
              Navigator.of(otpContext).push(MaterialPageRoute<void>(
                builder: (_) => ResetPasswordScreen(
                  onResetPassword: (newPassword) => _completeReset(
                    email: email,
                    resetToken: proof,
                    newPassword: newPassword,
                  ),
                ),
              ));
              return;
            }
            // Both fresh registrations and later logins must pass the same
            // server-verified company gate before the Home dashboard.
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute<void>(
                builder: (_) => CompanyEntryGate(
                  repository: RemoteCompanyRepository(api: _auth.api),
                ),
              ),
              (_) => false,
            );
          });
        },
        onResend: () async {
          try {
            challenge = await _auth.resend(challenge);
            return true;
          } catch (error) {
            _error(error);
            return false;
          }
        },
      ),
    ));
  }

  Future<void> _completeReset({
    required String email,
    required String resetToken,
    required String newPassword,
  }) async {
    await _auth.resetPassword(
      email: email,
      resetToken: resetToken,
      newPassword: newPassword,
    );
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => MobileAuthGateway(repository: _auth),
      ),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LoginScreen(
      onSubmit: _login,
      onCreateAccount: _openRegistration,
      onForgotPassword: _openForgotPassword,
    );
  }
}
