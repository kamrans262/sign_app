import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/sign2digital_country_selector.dart';
import '../../../../core/widgets/sign2digital_header.dart';
import '../../../../core/widgets/sign2digital_input_field.dart';
import '../../../../core/widgets/sign2digital_multiline_field.dart';
import '../../../../core/widgets/sign2digital_primary_button.dart';
import '../../domain/client_draft.dart';
import '../../domain/client_profile.dart';

/// UI-first client creation form. No network call or backend success claim.
class AddClientScreen extends StatefulWidget {
  const AddClientScreen({super.key, this.onSaveClient, this.initialClient});

  /// Optional integration callback; otherwise returns a draft via Navigator.pop.
  final ValueChanged<ClientDraft>? onSaveClient;

  /// Used by Client Details to prefill the existing form in edit mode.
  final ClientProfile? initialClient;

  @override
  State<AddClientScreen> createState() => _AddClientScreenState();
}

class _AddClientScreenState extends State<AddClientScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _company = TextEditingController();
  final _address = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _notes = TextEditingController();
  Sign2DigitalCountry _country = Sign2DigitalCountries.switzerland;

  @override
  void initState() {
    super.initState();
    final existing = widget.initialClient;
    if (existing == null) {
      return;
    }
    _fullName.text = existing.fullName.isNotEmpty
        ? existing.fullName
        : existing.companyName;
    _company.text = existing.companyName;
    _address.text = existing.address;
    _email.text = existing.email;
    _notes.text = existing.notes;
    for (final country in Sign2DigitalCountries.all) {
      if (country.isoCode == existing.countryIsoCode) {
        _country = country;
        break;
      }
    }
    var number = existing.nationalPhoneNumber.isNotEmpty
        ? existing.nationalPhoneNumber
        : existing.phone;
    if (existing.dialingCode.isNotEmpty &&
        number.startsWith(existing.dialingCode)) {
      number = number.substring(existing.dialingCode.length).trim();
    }
    _phone.text = number;
  }

  @override
  void dispose() {
    _fullName.dispose();
    _company.dispose();
    _address.dispose();
    _phone.dispose();
    _email.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _save() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final draft = ClientDraft(
      fullName: _fullName.text.trim(),
      companyName: _company.text.trim(),
      address: _address.text.trim(),
      countryIsoCode: _country.isoCode,
      dialingCode: _country.dialCode,
      phoneNumber: _phone.text.trim(),
      email: _email.text.trim(),
      notes: _notes.text.trim(),
    );
    if (widget.onSaveClient != null) {
      widget.onSaveClient!(draft);
    } else {
      Navigator.of(context).pop(draft);
    }
  }

  String? _validatePhone(String? raw) {
    final value = (raw ?? '').trim();
    if (value.isEmpty) {
      return null; // Phone requirement not yet specified.
    }
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (!RegExp(r'^[\d\s()\-]+$').hasMatch(value) || digits.length < 6) {
      return 'Enter a valid phone number';
    }
    return null;
  }

  String? _validateEmail(String? raw) {
    final value = (raw ?? '').trim();
    if (value.isEmpty) {
      return null; // Optional until product rules are confirmed.
    }
    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value)
        ? null
        : 'Enter a valid email address';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            Sign2DigitalHeader(
              title: widget.initialClient == null
                  ? 'Add Client'
                  : 'Edit Client',
              onBack: () => Navigator.of(context).maybePop(),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, viewport) => SingleChildScrollView(
                  key: const Key('add-client-scroll'),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.screenHorizontal,
                          20,
                          AppSpacing.screenHorizontal,
                          24,
                        ),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: (viewport.maxHeight - 44)
                                .clamp(0.0, double.infinity)
                                .toDouble(),
                          ),
                          child: IntrinsicHeight(
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Sign2DigitalInputField(
                                    label: 'Full Name',
                                    hintText: 'e.g. Marc Dupont',
                                    iconAsset: 'assets/icons/user.svg',
                                    controller: _fullName,
                                    keyboardType: TextInputType.name,
                                    textCapitalization:
                                        TextCapitalization.words,
                                    textInputAction: TextInputAction.next,
                                    validator: (value) =>
                                        (value?.trim().isEmpty ?? true)
                                        ? 'Enter the client’s full name'
                                        : null,
                                  ),
                                  const SizedBox(height: 20),
                                  Sign2DigitalInputField(
                                    label: 'Company Name',
                                    hintText: 'e.g. Dupont Construction SA',
                                    iconAsset: 'assets/icons/company.svg',
                                    controller: _company,
                                    textCapitalization:
                                        TextCapitalization.words,
                                    textInputAction: TextInputAction.next,
                                  ),
                                  const SizedBox(height: 20),
                                  Sign2DigitalInputField(
                                    label: 'Address',
                                    hintText: 'e.g. Rue de Lausanne 12, Geneva',
                                    iconAsset: 'assets/icons/address.svg',
                                    controller: _address,
                                    keyboardType: TextInputType.streetAddress,
                                    textCapitalization:
                                        TextCapitalization.sentences,
                                    textInputAction: TextInputAction.next,
                                  ),
                                  const SizedBox(height: 20),
                                  Sign2DigitalInputField(
                                    label: 'Phone',
                                    hintText: 'e.g. 21 123 45 67',
                                    iconAsset: 'assets/icons/phone.svg',
                                    controller: _phone,
                                    keyboardType: TextInputType.phone,
                                    textInputAction: TextInputAction.next,
                                    inputPrefix: Sign2DigitalCountrySelector(
                                      selected: _country,
                                      onChanged: (value) =>
                                          setState(() => _country = value),
                                    ),
                                    validator: _validatePhone,
                                  ),
                                  const SizedBox(height: 20),
                                  Sign2DigitalInputField(
                                    label: 'E-mail',
                                    hintText: 'e.g. marc@company.ch',
                                    iconAsset: 'assets/icons/email.svg',
                                    controller: _email,
                                    keyboardType: TextInputType.emailAddress,
                                    textInputAction: TextInputAction.next,
                                    validator: _validateEmail,
                                  ),
                                  const SizedBox(height: 20),
                                  const Text(
                                    'Additional Information',
                                    style: AppTextStyles.fieldLabel,
                                  ),
                                  const SizedBox(height: 10),
                                  Sign2DigitalMultilineField(
                                    controller: _notes,
                                    iconAsset: 'assets/icons/doc_numbering.svg',
                                    hintText: "Add notes about this client's preferences or any other relevant information",
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.screenHorizontal,
                8,
                AppSpacing.screenHorizontal,
                24,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 520),
                  child: Sign2DigitalPrimaryButton(
                    key: Key('save-client-button'),
                    label: widget.initialClient == null
                        ? 'Save Client'
                        : 'Save Changes',
                    onPressed: _save,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
