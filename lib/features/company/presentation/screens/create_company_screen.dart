// Sign2Digital — Create Your Company UI (frontend only).
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/sign2digital_country_selector.dart';
import '../../../../core/widgets/sign2digital_ai_voice_button.dart';
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
import '../../../jobs/presentation/widgets/ai_voice_flow_dialog.dart';
import '../../../jobs/services/voice_job_extraction_service.dart';
import '../../../jobs/services/voice_recorder_service.dart';

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
    this.aiClient,
    this.voiceRecorderFactory,
  });

  /// Existing optional hooks remain available to tests and demo previews.
  final ValueChanged<CompanyDraft>? onSave;
  final ValueChanged<CompanyDraft>? onSkipOptionalFields;
  final VoidCallback? onBack;

  /// In UI-preview mode, the in-memory repository is still used by default.
  final CompanyRepository? companyRepository;
  final CompanyProfile? initialCompany;
  final VoidCallback? onCompleted;
  /// Override only for isolated integration tests.
  final SignApiClient? aiClient;
  final VoiceRecorderService Function()? voiceRecorderFactory;

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
  bool _hasSavedLogo = false;
  bool _hasSavedTerms = false;
  bool _voiceOpen = false;
  bool _countryTouched = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialCompany;
    if (initial != null) {
      _savedCompanyId = initial.id;
      _hasSavedLogo = initial.logoFileName?.isNotEmpty == true;
      _hasSavedTerms = initial.termsFileName?.isNotEmpty == true;
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
    // The onboarding gate injects a real backend repository; never treat its
    // verified company save as an isolated demo merely because auth is injected.
    final repository = widget.companyRepository ??
        (MobileAuthRepository.shared.isSignedIn
            ? RemoteCompanyRepository.shared
            : DemoCompanyRepository.shared);
    final real = repository is RemoteCompanyRepository;
    try {
      final company = await repository.save(_buildProfile(draft));
      if (real) {
        _savedCompanyId = company.id;
        final remote = repository;
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

  Future<void> _removeExistingFile(String kind) async {
    final id = _savedCompanyId;
    if (_saving || id == null || int.tryParse(id) == null ||
        !MobileAuthRepository.shared.isSignedIn) {
      return;
    }
    setState(() => _saving = true);
    try {
      await RemoteCompanyRepository.shared.deleteFile(id, kind);
      if (!mounted) return;
      setState(() {
        if (kind == 'logo') _hasSavedLogo = false;
        if (kind == 'terms') _hasSavedTerms = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(kind == 'logo' ? 'Saved logo removed.' : 'Saved terms removed.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error is SignApiException
            ? error.message : 'Unable to remove saved file.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }


  /// AI never saves the company; it only fills blank fields for manual review.
  void _applyAiCompany(Map<String, dynamic> suggestions) {
    var changed = 0;
    void fill(TextEditingController controller, String key) {
      final value = suggestions[key];
      if (controller.text.trim().isEmpty &&
          value is String && value.trim().isNotEmpty) {
        controller.text = value.trim();
        changed++;
      }
    }

    setState(() {
      fill(_company, 'companyName');
      fill(_address, 'address');
      fill(_phone, 'phone');
      fill(_email, 'email');
      fill(_swissId, 'swissCompanyId');
      fill(_vat, 'vatNumber');
      fill(_iban, 'iban');
      fill(_qrIban, 'qrIban');
      fill(_numbering, 'documentNumbering');
      final countryCode = suggestions['countryIsoCode'];
      if (!_countryTouched && widget.initialCompany == null &&
          countryCode is String) {
        for (final country in Sign2DigitalCountries.all) {
          if (country.isoCode == countryCode.toUpperCase()) {
            if (_country.isoCode != country.isoCode) {
              _country = country;
              changed++;
            }
            break;
          }
        }
      }
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(changed > 0
          ? 'AI filled $changed company fields. Review before saving.'
          : 'No empty company fields were changed. Review your details.'),
    ));
  }

  Future<void> _companyVoice() async {
    if (_voiceOpen || _saving) return;
    if (!MobileAuthRepository.shared.isSignedIn && widget.aiClient == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Sign in to use AI company creation.'),
      ));
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _voiceOpen = true);
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        barrierColor: const Color(0x80000000),
        builder: (_) => AiVoiceFlowDialog(
          recorder: widget.voiceRecorderFactory?.call() ??
              LocalVoiceRecorderService(),
          extraction: OpenAiVoiceJobExtractionService(),
          rawAudioMode: true,
          recordingTitle: 'Record Company Details',
          onAudioProcessed: (path) async {
            final recording = File(path);
            if (!await recording.exists()) {
              throw const SignApiException('The recording is no longer available.');
            }
            final response = await (widget.aiClient ??
                    MobileAuthRepository.shared.api)
                .postMultipart(
              '/api/v1/ai/companies/voice',
              filename: 'company-recording.m4a',
              bytes: await recording.readAsBytes(),
              maxBytes: 25 * 1024 * 1024,
            );
            final data = response['data'];
            if (data is! Map<String, dynamic> ||
                data['suggestions'] is! Map<String, dynamic>) {
              throw const SignApiException('Invalid company AI suggestions.');
            }
            if (!mounted) return;
            _applyAiCompany(data['suggestions'] as Map<String, dynamic>);
            if (await recording.exists()) await recording.delete();
          },
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(error is SignApiException
              ? error.message : 'Unable to process company voice recording.'),
        ));
      }
    } finally {
      if (mounted) setState(() => _voiceOpen = false);
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
    final requiresCompany = widget.companyRepository is RemoteCompanyRepository ||
        (MobileAuthRepository.shared.isSignedIn && widget.companyRepository == null);
    if (requiresCompany && draft.companyName.isEmpty) {
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
    required String hint,
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
              constraints: BoxConstraints(maxWidth:
            MediaQuery.orientationOf(context) == Orientation.landscape
                ? double.infinity : 900),
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
                        constraints: BoxConstraints(maxWidth:
            MediaQuery.orientationOf(context) == Orientation.landscape
                ? double.infinity : 520),
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
                                Sign2DigitalAiVoiceButton(
                                  key: const Key('create-company-ai-voice'),
                                  onPressed: _companyVoice,
                                ),
                                const SizedBox(height: 20),
                                _field(
                                  label: 'Company Name',
                                  icon: 'company.svg',
                                  controller: _company,
                                  hint: 'e.g. Alpine Construction AG',
                                  capitalization: TextCapitalization.words,
                                  validator: (value) => (value?.trim().isEmpty ?? true)
                                      ? 'Enter your company name' : null,
                                ),
                                const SizedBox(height: 16),
                                Sign2DigitalImageUpload(
                                  onChanged: (file) => _logo = file,
                                ),
                                if (_hasSavedLogo) ...[
                                  const SizedBox(height: 8),
                                  Text('Saved logo: ${widget.initialCompany?.logoFileName ?? 'Company logo'}',
                                    style: AppTextStyles.small),
                                  Align(alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: _saving ? null : () => _removeExistingFile('logo'),
                                      child: const Text('Remove saved logo'),
                                    )),
                                ],
                                const SizedBox(height: 16),
                                _field(
                                  label: 'Address',
                                  icon: 'address.svg',
                                  controller: _address,
                                  hint: 'e.g. Bahnhofstrasse 10, 8001 Zürich',
                                  capitalization: TextCapitalization.words,
                                  keyboardType: TextInputType.streetAddress,
                                ),
                                const SizedBox(height: 16),
                                _field(
                                  label: 'Phone',
                                  icon: 'phone.svg',
                                  controller: _phone,
                                  hint: 'e.g. 79 123 45 67',
                                  keyboardType: TextInputType.phone,
                                  inputPrefix: Sign2DigitalCountrySelector(
                                    selected: _country,
                                    onChanged: (value) => setState(() {
                                      _country = value;
                                      _countryTouched = true;
                                    }),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _field(
                                  label: 'E-mail',
                                  icon: 'email.svg',
                                  controller: _email,
                                  hint: 'e.g. info@alpine.ch',
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
                                  hint: 'e.g. CHE-123.456.789',
                                ),
                                const SizedBox(height: 16),
                                _field(
                                  label: 'VAT Number',
                                  icon: 'hashtag.svg',
                                  controller: _vat,
                                  hint: 'e.g. CHE-123.456.789 MWST',
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
                                  hint: 'e.g. your bank-issued Swiss QR-IBAN',
                                  capitalization: TextCapitalization.characters,
                                ),
                                const SizedBox(height: 16),
                                _field(
                                  label: 'Document Numbering',
                                  icon: 'doc_numbering.svg',
                                  controller: _numbering,
                                  hint: 'e.g. INV-2026-001',
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
                                if (_hasSavedTerms) ...[
                                  const SizedBox(height: 8),
                                  Text('Saved terms: ${widget.initialCompany?.termsFileName ?? 'Terms & Conditions'}',
                                    style: AppTextStyles.small),
                                  Align(alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: _saving ? null : () => _removeExistingFile('terms'),
                                      child: const Text('Remove saved PDF'),
                                    )),
                                ],
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
