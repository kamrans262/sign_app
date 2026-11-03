// Sign2Digital — Create Your Company UI (frontend only).
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/sign2digital_country_selector.dart';
import '../../../../core/widgets/sign2digital_document_upload.dart';
import '../../../../core/widgets/sign2digital_header.dart';
import '../../../../core/widgets/sign2digital_image_upload.dart';
import '../../../../core/widgets/sign2digital_input_field.dart';
import '../../../../core/widgets/sign2digital_primary_button.dart';
import '../../data/company_repository.dart';
import '../../data/demo_company_repository.dart';
import '../../data/remote_company_repository.dart';
import '../../../auth/data/mobile_auth_repository.dart';
import '../../../clients/presentation/screens/clients_screen.dart';
import '../../../../core/services/sign_api_client.dart';
import '../../domain/company_profile.dart';

@immutable
class CompanyDraft {
  const CompanyDraft({
    required this.companyName,
    required this.address,
    required this.country,
    required this.phone,
    required this.email,
    required this.swissCompanyId,
    required this.vatNumber,
    required this.iban,
    required this.qrIban,
    required this.documentNumbering,
    required this.logo,
    required this.terms,
  });

  final String companyName;
  final String address;
  final Sign2DigitalCountry country;
  final String phone;
  final String email;
  final String swissCompanyId;
  final String vatNumber;
  final String iban;
  final String qrIban;
  final String documentNumbering;
  final PlatformFile? logo;
  final PlatformFile? terms;
}

class CreateCompanyScreen extends StatefulWidget {
  const CreateCompanyScreen({
    super.key,
    this.onSave,
    this.onSkipOptionalFields,
    this.onBack,
    this.companyRepository,
    this.initialCompany,
    this.onCompleted,
  });

  /// Existing optional hooks remain available to tests and demo previews.
  final ValueChanged<CompanyDraft>? onSave;
  final ValueChanged<CompanyDraft>? onSkipOptionalFields;
  final VoidCallback? onBack;

  /// In UI-preview mode, the in-memory repository is still used by default.
  final CompanyRepository? companyRepository;
  final CompanyProfile? initialCompany;
  final VoidCallback? onCompleted;

  @override
  State<CreateCompanyScreen> createState() => _CreateCompanyScreenState();
}

class _CreateCompanyScreenState extends State<CreateCompanyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _company = TextEditingController();
  final _address = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _swissId = TextEditingController();
  final _vat = TextEditingController();
  final _iban = TextEditingController();
  final _qrIban = TextEditingController();
  final _numbering = TextEditingController();
  Sign2DigitalCountry _country = Sign2DigitalCountries.switzerland;
  PlatformFile? _logo;
  PlatformFile? _terms;
  String? _savedCompanyId;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialCompany;
    if (initial != null) {
      _savedCompanyId = initial.id;
      _company.text = initial.companyName;
      _address.text = initial.address;
      _phone.text = initial.phoneNumber;
      _email.text = initial.email;
      _swissId.text = initial.swissCompanyId;
      _vat.text = initial.vatNumber;
      _iban.text = initial.iban;
      _qrIban.text = initial.qrIban;
      _numbering.text = initial.documentNumbering;
      for (final c in Sign2DigitalCountries.all) {
        if (c.isoCode == initial.countryIsoCode) {
          _country = c;
          break;
        }
      }
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _company,
      _address,
      _phone,
      _email,
      _swissId,
      _vat,
      _iban,
      _qrIban,
      _numbering,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  CompanyDraft get _draft => CompanyDraft(
    companyName: _company.text.trim(),
    address: _address.text.trim(),
    country: _country,
    phone: _phone.text.trim(),
    email: _email.text.trim(),
    swissCompanyId: _swissId.text.trim(),
    vatNumber: _vat.text.trim(),
    iban: _iban.text.trim().toUpperCase(),
    qrIban: _qrIban.text.trim().toUpperCase(),
    documentNumbering: _numbering.text.trim(),
    logo: _logo,
    terms: _terms,
  );

  CompanyProfile _buildProfile(CompanyDraft draft) => CompanyProfile(
    id: _savedCompanyId ?? 'demo-current-company',
    companyName: draft.companyName,
    address: draft.address,
    countryIsoCode: draft.country.isoCode,
    dialingCode: draft.country.dialCode,
    phoneNumber: draft.phone,
    email: draft.email,
    swissCompanyId: draft.swissCompanyId,
    vatNumber: draft.vatNumber,
    iban: draft.iban,
    qrIban: draft.qrIban,
    documentNumbering: draft.documentNumbering,
    logoFileName: draft.logo?.name,
    termsFileName: draft.terms?.name,
  );

  bool _saving = false;

  Future<void> _storeCompany(CompanyDraft draft) async {
    if (_saving) return;
    setState(() => _saving = true);
    final real = MobileAuthRepository.shared.isSignedIn &&
        widget.companyRepository == null;
    try {
      final repository = widget.companyRepository ??
          (real ? RemoteCompanyRepository.shared : DemoCompanyRepository.shared);
      final company = await repository.save(_buildProfile(draft));
      if (real) {
        _savedCompanyId = company.id;
        final remote = repository as RemoteCompanyRepository;
        if (draft.logo != null) await remote.uploadFile(company.id, 'logo', draft.logo!);
        if (draft.terms != null) await remote.uploadFile(company.id, 'terms', draft.terms!);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(real ? 'Company information saved successfully.'
            : 'Saved in the temporary demo session only. No server request was made.'),
      ));
      if (real) {
        if (widget.onCompleted != null) {
          widget.onCompleted!();
        } else if (widget.initialCompany != null) {
          Navigator.of(context).pop(true);
        } else {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute<void>(builder: (_) => const ClientsScreen(initialTab: 0)),
            (_) => false,
          );
        }
      }
    } catch (error) {
      if (!mounted) return;
      final message = error is SignApiException
          ? error.message : 'Unable to save company information.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _save() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final draft = _draft;
    if (widget.onSave != null) {
      widget.onSave!(draft);
      return;
    }
    _storeCompany(draft);
  }

  void _skip() {
    FocusManager.instance.primaryFocus?.unfocus();
    final draft = _draft;
    if (widget.onSkipOptionalFields != null) {
      widget.onSkipOptionalFields!(draft);
      return;
    }
    // Skipping optional company fields never discards filled-in values.
    // A company still requires an actual name before persisting to Laravel.
    if (MobileAuthRepository.shared.isSignedIn &&
        widget.companyRepository == null && draft.companyName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Enter a company name to continue.'),
      ));
      return;
    }
    _storeCompany(draft);
  }

  Widget _field({
    required String label,
    required String icon,
    required TextEditingController controller,
    String hint = 'e.g, Marc@company.ch',
    TextInputType? keyboardType,
    TextCapitalization capitalization = TextCapitalization.none,
    String? Function(String?)? validator,
    Widget? inputPrefix,
  }) {
    return Sign2DigitalInputField(
      label: label,
      hintText: hint,
      iconAsset: 'assets/icons/$icon',
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: capitalization,
      textInputAction: TextInputAction.next,
      inputPrefix: inputPrefix,
      validator: validator,
    );
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
                key: const Key('create-company-scroll'),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: [
                  SliverToBoxAdapter(
                    child: Sign2DigitalHeader(
                      logoAsset: 'assets/header_logo.png',
                      onBack:
                          widget.onBack ??
                          () => Navigator.of(context).maybePop(),
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
                            24,
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text(
                                  'Create Your Company',
                                  style: AppTextStyles.heading,
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  'Set up your first company profile',
                                  style: AppTextStyles.subtitle,
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 25),
                                _field(
                                  label: 'Company Name',
                                  icon: 'company.svg',
                                  controller: _company,
                                  capitalization: TextCapitalization.words,
                                  validator: (value) => (value?.trim().isEmpty ?? true)
                                      ? 'Enter your company name' : null,
                                ),
                                const SizedBox(height: 16),
                                Sign2DigitalImageUpload(
                                  onChanged: (file) => _logo = file,
                                ),
                                const SizedBox(height: 16),
                                _field(
                                  label: 'Address',
                                  icon: 'address.svg',
                                  controller: _address,
                                  capitalization: TextCapitalization.words,
                                  keyboardType: TextInputType.streetAddress,
                                ),
                                const SizedBox(height: 16),
                                _field(
                                  label: 'Phone',
                                  icon: 'phone.svg',
                                  controller: _phone,
                                  keyboardType: TextInputType.phone,
                                  inputPrefix: Sign2DigitalCountrySelector(
                                    selected: _country,
                                    onChanged: (value) =>
                                        setState(() => _country = value),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _field(
                                  label: 'E-mail',
                                  icon: 'email.svg',
                                  controller: _email,
                                  keyboardType: TextInputType.emailAddress,
                                  validator: (value) {
                                    final email = value?.trim() ?? '';
                                    if (email.isNotEmpty &&
                                        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                            .hasMatch(email)) {
                                      return 'Enter a valid email address';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                _field(
                                  label: 'Swiss Company ID (IDE)',
                                  icon: 'swiss_company_id.svg',
                                  controller: _swissId,
                                ),
                                const SizedBox(height: 16),
                                _field(
                                  label: 'VAT Number',
                                  icon: 'hashtag.svg',
                                  controller: _vat,
                                ),
                                const SizedBox(height: 16),
                                _field(
                                  label: 'IBAN',
                                  icon: 'iban.svg',
                                  controller: _iban,
                                  hint: 'e.g. CH93 0076 2011 6238 5295 7',
                                  capitalization: TextCapitalization.characters,
                                ),
                                const SizedBox(height: 16),
                                _field(
                                  label: 'QR IBAN (optional)',
                                  icon: 'qr_iban.svg',
                                  controller: _qrIban,
                                  hint: 'e.g. CH93 0076 2011 6238 5295 7',
                                  capitalization: TextCapitalization.characters,
                                ),
                                const SizedBox(height: 16),
                                _field(
                                  label: 'Document Numbering',
                                  icon: 'doc_numbering.svg',
                                  controller: _numbering,
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  'Terms & Conditions',
                                  style: AppTextStyles.fieldLabel.copyWith(
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Sign2DigitalDocumentUpload(
                                  onChanged: (file) => _terms = file,
                                ),
                                const SizedBox(height: 25),
                                Sign2DigitalPrimaryButton(
                                  key: const Key('save-company-button'),
                                  label: 'Save & Continue',
                                  onPressed: _save,
                                  loading: _saving,
                                ),
                                const SizedBox(height: 10),
                                Center(
                                  child: TextButton(
                                    key: const Key('skip-company-optional'),
                                    onPressed: _skip,
                                    child: const Text(
                                      'Skip optional fields',
                                      style: AppTextStyles.footerLink,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
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
      ),
    );
  }
}
