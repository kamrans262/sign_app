import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sign2digital_header.dart';
import '../../../company/data/demo_company_repository.dart';
import '../../../company/domain/company_profile.dart';
import '../../../company/presentation/screens/create_company_screen.dart';
import '../../../quotes/presentation/widgets/sign2digital_quote_shadow_panel.dart';

/// Displays the existing current company without overwriting it.
class ProfileBusinessInformationScreen extends StatelessWidget {
  const ProfileBusinessInformationScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.white,
    body: SafeArea(child: Column(children: [
      const Sign2DigitalHeader(title: 'Business Information'),
      Expanded(child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: FutureBuilder<CompanyProfile?>(
          future: DemoCompanyRepository.shared.byId('demo-current-company'),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
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
                        companyRepository: DemoCompanyRepository.shared))),
                  child: const Text('Set Up Business Information'),
                ),
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
