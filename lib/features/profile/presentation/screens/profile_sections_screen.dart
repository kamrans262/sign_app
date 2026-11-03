import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sign2digital_header.dart';
import '../../../company/data/demo_company_repository.dart';
import '../../../company/data/remote_company_repository.dart';
import '../../../company/presentation/screens/company_team_screen.dart';
import '../../../company/presentation/screens/company_invitations_screen.dart';
import '../../../auth/data/mobile_auth_repository.dart';
import '../../../../core/services/active_company_session.dart';
import '../../../company/domain/company_profile.dart';
import '../../../company/presentation/screens/create_company_screen.dart';
import '../../../quotes/presentation/widgets/sign2digital_quote_shadow_panel.dart';

/// Displays the existing current company without overwriting it.
class ProfileBusinessInformationScreen extends StatelessWidget {
  const ProfileBusinessInformationScreen({super.key});

  String _roleFor(CompanyProfile company) => company.role;

  Future<CompanyProfile?> _realCompany() async {
    final companies = await RemoteCompanyRepository.shared.list();
    final selected = ActiveCompanySession.companyId?.toString();
    for (final company in companies) {
      if (company.id == selected) return company;
    }
    return companies.isNotEmpty ? companies.first : null;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.white,
    body: SafeArea(child: Column(children: [
      const Sign2DigitalHeader(title: 'Business Information'),
      Expanded(child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: FutureBuilder<CompanyProfile?>(
          future: MobileAuthRepository.shared.isSignedIn
              ? _realCompany() : DemoCompanyRepository.shared.byId('demo-current-company'),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              // An offline response is not evidence that the company was
              // deleted. Keep the business details untouched and offer retry.
              return ListView(padding: const EdgeInsets.all(20), children: [
                const Text('Unable to load company information. Check your connection and retry.',
                  key: Key('company-load-error'),
                  style: TextStyle(fontFamily: 'Inter',
                    fontSize: 14, color: AppColors.placeholder)),
                const SizedBox(height: 20),
                FilledButton(
                  key: const Key('retry-company-load'),
                  onPressed: () => Navigator.of(context).pushReplacement<void, void>(
                    MaterialPageRoute<void>(builder: (_) =>
                      const ProfileBusinessInformationScreen()),
                  ),
                  child: const Text('Retry'),
                ),
              ]);
            }
            final company = snapshot.data;
            if (company == null) {
              return ListView(padding: const EdgeInsets.all(20), children: [
                const Text('No company has been created for this session.',
                  style: TextStyle(fontFamily: 'Inter',
                    fontSize: 14, color: AppColors.placeholder)),
                const SizedBox(height: 20),
                FilledButton(
                  key: const Key('profile-company-setup'),
                  onPressed: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(builder: (_) =>
                      CreateCompanyScreen(
                        companyRepository: MobileAuthRepository.shared.isSignedIn
                            ? null : DemoCompanyRepository.shared))),
                  child: const Text('Set Up Business Information'),
                ),
                if (MobileAuthRepository.shared.isSignedIn) ...[
                  const SizedBox(height: 12),
                  OutlinedButton(
                    key: const Key('company-invitations-no-company'),
                    onPressed: () => Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => const CompanyInvitationsScreen()),
                    ),
                    child: const Text('Accept Company Invitation'),
                  ),
                ],
              ]);
            }
            return ListView(padding: const EdgeInsets.all(20), children: [
              Sign2DigitalQuoteShadowPanel(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _line('Company', company.companyName),
                    _line('Address', company.address),
                    _line('Email', company.email),
                    _line('Phone', '${company.dialingCode} ${company.phoneNumber}'),
                    _line('Swiss Company ID', company.swissCompanyId),
                    _line('VAT Number', company.vatNumber),
                    _line('IBAN', company.iban),
                    _line('QR IBAN', company.qrIban),
                  ],
                ),
              ),
              const SizedBox(height: 15),
              if (MobileAuthRepository.shared.isSignedIn) ...[
                if (company.role == 'owner' || company.role == 'admin')
                FilledButton(
                  key: const Key('edit-company-details'),
                  onPressed: () async {
                    final changed = await Navigator.of(context).push<bool>(
                      MaterialPageRoute<bool>(builder: (_) =>
                          CreateCompanyScreen(initialCompany: company)),
                    );
                    if (!context.mounted || changed != true) return;
                    Navigator.of(context).pushReplacement<void, void>(
                      MaterialPageRoute<void>(
                        builder: (_) => const ProfileBusinessInformationScreen(),
                      ),
                    );
                  },
                  child: const Text('Edit Business Information'),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  key: const Key('manage-company-team'),
                  onPressed: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(builder: (_) => CompanyTeamScreen(
                      companyId: company.id,
                      companyName: company.companyName,
                      role: _roleFor(company),
                    )),
                  ),
                  child: const Text('Team Members & Permissions'),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  key: const Key('accept-company-invitation'),
                  onPressed: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => const CompanyInvitationsScreen()),
                  ),
                  child: const Text('Company Invitations'),
                ),
              ] else
                const Text(
                  'Business details are read-only here. Existing data is '
                  'preserved; an editing integration is not connected yet.',
                  style: TextStyle(fontFamily: 'Inter', fontSize: 12,
                    color: AppColors.placeholder)),
            ]);
          },
        ),
      ))),
    ])),
  );

  static Widget _line(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 15),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(
        fontFamily: 'Inter', fontSize: 12, color: AppColors.placeholder)),
      const SizedBox(height: 5),
      Text(value.isEmpty ? 'Not provided' : value, style: const TextStyle(
        fontFamily: 'Inter', fontSize: 14,
        fontWeight: FontWeight.w500, color: AppColors.dark)),
    ]),
  );
}

/// Nonexistent settings endpoints are shown transparently, not simulated.
class ProfileSectionUnavailableScreen extends StatelessWidget {
  const ProfileSectionUnavailableScreen({
    super.key, required this.title, required this.details,
  });

  final String title;
  final String details;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.white,
    body: SafeArea(child: Column(children: [
      Sign2DigitalHeader(title: title),
      Expanded(child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Sign2DigitalQuoteShadowPanel(
              padding: const EdgeInsets.all(20),
              child: Text(details, style: const TextStyle(
                fontFamily: 'Inter', fontSize: 14,
                color: AppColors.placeholder)),
            ),
          ],
        ),
      ))),
    ])),
  );
}
