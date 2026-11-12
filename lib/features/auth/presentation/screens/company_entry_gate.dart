import 'package:flutter/material.dart';

import '../../../../core/services/active_company_session.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/sign2digital_primary_button.dart';
import '../../../clients/presentation/screens/clients_screen.dart';
import '../../../subscription/services/m23_billing_deep_links.dart';
import '../../../company/data/remote_company_repository.dart';
import '../../../company/presentation/screens/create_company_screen.dart';

/// Server-verified onboarding boundary shared by OTP login, registration and
/// remembered sessions. A valid bearer token alone does not grant Home access.
class CompanyEntryGate extends StatefulWidget {
  const CompanyEntryGate({super.key, this.repository});

  /// An injected remote repository supports testable, authenticated gateways.
  final RemoteCompanyRepository? repository;

  @override
  State<CompanyEntryGate> createState() => _CompanyEntryGateState();
}

class _CompanyEntryGateState extends State<CompanyEntryGate> {
  late final RemoteCompanyRepository _repository =
      widget.repository ?? RemoteCompanyRepository.shared;

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkCompanies();
  }

  Future<void> _checkCompanies() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // The authenticated backend, not local demo data or remembered flags,
      // determines whether this account has access to a company.
      final companies = await _repository.list();
      if (companies.isNotEmpty && ActiveCompanySession.companyId == null) {
        // An active membership exists but the previous selection was cleared
        // (e.g. another company was revoked). Select only through the API.
        await _repository.switchTo(companies.first.id);
      }
      if (!mounted) return;
      if (companies.isNotEmpty && ActiveCompanySession.companyId != null) {
        Navigator.of(context).pushAndRemoveUntil<void>(
          MaterialPageRoute<void>(
            builder: (_) => const ClientsScreen(initialTab: 0),
          ),
          (_) => false,
        );
        // A cold-start Checkout return waits until server-verified company
        // selection. Never infer company ownership from the browser URL.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          M23BillingDeepLinks.presentIfReady();
        });
        return;
      }
      setState(() => _loading = false);
    } catch (_) {
      if (!mounted) return;
      // Network errors must not be treated as 'no company' or bypassed.
      setState(() {
        _loading = false;
        _error = 'Unable to verify your company. Check your connection and try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loading && _error == null) {
      return CreateCompanyScreen(
        key: const Key('required-company-setup'),
        companyRepository: _repository,
        onCompleted: _checkCompanies,
      );
    }
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: _loading
                  ? const CircularProgressIndicator(
                      color: AppColors.primary,
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(_error!,
                            textAlign: TextAlign.center,
                            style: AppTextStyles.subtitle),
                        const SizedBox(height: 20),
                        Sign2DigitalPrimaryButton(
                          key: const Key('retry-company-verification'),
                          label: 'Try Again',
                          onPressed: _checkCompanies,
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
