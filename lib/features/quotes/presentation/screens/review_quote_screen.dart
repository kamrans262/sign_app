import '../../../../core/widgets/sign2digital_input_field.dart';
import '../../../../core/widgets/sign2digital_form_dialog.dart';
import '../../../../core/navigation/sign2digital_navigation.dart';
import '../../../../core/widgets/sign2digital_subscription_gate.dart';
import 'package:flutter/material.dart';
import '../../../documents/data/document_activity_session.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sign2digital_header.dart';
import '../../../../core/widgets/sign2digital_primary_button.dart';
import '../../domain/quote_review_models.dart';
import '../../data/remote_quote_repository.dart';
import '../../../auth/data/mobile_auth_repository.dart';
import '../widgets/sign2digital_quote_shadow_panel.dart';
import '../widgets/sign2digital_quote_work_item_card.dart';
import 'quote_preview_screen.dart';

/// UI-only quote review and pricing. No invented AI values or server approval.
class ReviewQuoteScreen extends StatefulWidget {
  const ReviewQuoteScreen({
    super.key, required this.initialDraft,
    this.onSaved, this.onApproved,
  });
  final QuoteReviewDraft initialDraft;
  final ValueChanged<QuoteReviewDraft>? onSaved;
  final ValueChanged<QuoteReviewDraft>? onApproved;

  @override
  State<ReviewQuoteScreen> createState() => _ReviewQuoteScreenState();
}

class _ReviewQuoteScreenState extends State<ReviewQuoteScreen> {
  late QuoteReviewDraft _draft;
  bool _termsExpanded = false;
  int _nextItemNumber = 0;
  bool _savingToServer = false;

  bool get _remoteMode => MobileAuthRepository.shared.isSignedIn && !_draft.isDemo;

  @override
  void initState() {
    super.initState();
    _draft = QuoteReviewSessionStore.load(widget.initialDraft.id) ??
        widget.initialDraft.copy();
    _nextItemNumber = _draft.items.length;
  }

  void _updated() {
    setState(() => _draft.approvedLocally = false);
    QuoteReviewSessionStore.save(_draft);
  }

  void _notice(String message) {
    if (!mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    messenger.removeCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  /// Dialog fields manage their own TextFormField controllers. Avoid disposing
  /// externally-owned controllers before the closing route animation finishes.
  Future<void> _editDetails() async {
    var client = _draft.clientName;
    var address = _draft.billingAddress;
    var email = _draft.clientEmail;
    var phone = _draft.clientPhone;
    var iban = _draft.payment?.iban ?? '';
    var accountHolder = _draft.payment?.accountHolder ?? '';
    var street = _draft.payment?.street ?? '';
    var buildingNumber = _draft.payment?.buildingNumber ?? '';
    var postalCode = _draft.payment?.postalCode ?? '';
    var city = _draft.payment?.city ?? '';
    var country = _draft.payment?.country ?? 'CH';
    var vat = quotePercentText(_draft.vatBasisPoints);
    var deposit = quotePercentText(_draft.depositBasisPoints);
    var chosenCurrency = _draft.currency;
    var chosenDate = _draft.date;
    DateTime? validUntil = _draft.validUntil;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, updateDialog) => Sign2DigitalFormDialog(
          title: const Text('Edit Quote Details'),
          content: SingleChildScrollView(child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Sign2DigitalInputField(
                  key: const Key('quote-edit-client'), label: 'Client',
                  hintText: 'Enter client',
                  iconAsset: '', leadingIcon: Icons.person_outline,
                  initialValue: client, onChanged: (value) => client = value,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Sign2DigitalInputField(
                  label: 'Billing Address',
                  hintText: 'Enter billing address',
                  iconAsset: '', leadingIcon: Icons.location_on_outlined,
                  initialValue: address, onChanged: (value) => address = value,
                  maxLines: 2,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Sign2DigitalInputField(
                  label: 'Client Email',
                  hintText: 'Enter client email',
                  iconAsset: '', leadingIcon: Icons.email_outlined,
                  initialValue: email, onChanged: (value) => email = value,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Sign2DigitalInputField(
                  label: 'Client Phone',
                  hintText: 'Enter client phone',
                  iconAsset: '', leadingIcon: Icons.phone_outlined,
                  initialValue: phone, onChanged: (value) => phone = value,
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: ['CHF', 'GBP', 'EUR', 'USD'].contains(chosenCurrency)
                    ? chosenCurrency : 'CHF',
                decoration: const InputDecoration(labelText: 'Currency',
                  prefixIcon: Icon(Icons.currency_exchange_outlined),
                ),
                items: ['CHF', 'GBP', 'EUR', 'USD'].map((value) =>
                    DropdownMenuItem(value: value, child: Text(value))).toList(),
                onChanged: (value) {
                  if (value != null) {
                    updateDialog(() => chosenCurrency = value);
                  }
                },
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Sign2DigitalInputField(
                  label: 'VAT %',
                  hintText: 'Enter vat %',
                  iconAsset: '', leadingIcon: Icons.percent_outlined,
                  initialValue: vat, onChanged: (value) => vat = value,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Sign2DigitalInputField(
                  label: 'Deposit %',
                  hintText: 'Enter deposit %',
                  iconAsset: '', leadingIcon: Icons.payments_outlined,
                  initialValue: deposit, onChanged: (value) => deposit = value,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                key: const Key('quote-edit-valid-until'),
                onPressed: () async {
                  final selected = await showDatePicker(
                    context: context, initialDate: validUntil ?? chosenDate,
                    firstDate: DateTime(2000), lastDate: DateTime(2100));
                  if (selected != null) {
                    updateDialog(() => validUntil = selected);
                  }
                },
                icon: const Icon(Icons.event_available_outlined),
                label: Text('Valid until: ${validUntil == null ? 'Not set' : _dateText(validUntil!)}'),
              ),
              const Divider(),
              const Text('Optional payment account (QR only when complete)'),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Sign2DigitalInputField(
                  label: 'Swiss IBAN',
                  hintText: 'Enter swiss iban',
                  iconAsset: '', leadingIcon: Icons.account_balance_outlined,
                  initialValue: iban, onChanged: (value) => iban = value,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Sign2DigitalInputField(
                  label: 'Account holder',
                  hintText: 'Enter account holder',
                  iconAsset: '', leadingIcon: Icons.person_outline,
                  initialValue: accountHolder, onChanged: (value) => accountHolder = value,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Sign2DigitalInputField(
                  label: 'Payee street',
                  hintText: 'Enter payee street',
                  iconAsset: '', leadingIcon: Icons.signpost_outlined,
                  initialValue: street, onChanged: (value) => street = value,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Sign2DigitalInputField(
                  label: 'Building number',
                  hintText: 'Enter building number',
                  iconAsset: '', leadingIcon: Icons.home_outlined,
                  initialValue: buildingNumber, onChanged: (value) => buildingNumber = value,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Sign2DigitalInputField(
                  label: 'Postal code',
                  hintText: 'Enter postal code',
                  iconAsset: '', leadingIcon: Icons.markunread_mailbox_outlined,
                  initialValue: postalCode, onChanged: (value) => postalCode = value,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Sign2DigitalInputField(
                  label: 'Payee city',
                  hintText: 'Enter payee city',
                  iconAsset: '', leadingIcon: Icons.location_city_outlined,
                  initialValue: city, onChanged: (value) => city = value,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Sign2DigitalInputField(
                  label: 'Country (CH/LI)',
                  hintText: 'Enter country (ch/li)',
                  iconAsset: '', leadingIcon: Icons.public_outlined,
                  initialValue: country, onChanged: (value) => country = value,
                ),
              ),
              TextButton.icon(
                key: const Key('quote-edit-date'),
                onPressed: () async {
                  final result = await showDatePicker(
                    context: context,
                    initialDate: chosenDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (result != null) {
                    updateDialog(() => chosenDate = result);
                  }
                },
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text(_dateText(chosenDate)),
              ),
            ],
          )),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel')),
            TextButton(key: const Key('quote-details-apply'),
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Apply')),
          ],
        ),
      ),
    );
    if (saved != true || !mounted) {
      return;
    }
    final vatBasisPoints = parseQuoteMinorUnits(vat);
    final depositBasisPoints = parseQuoteMinorUnits(deposit);
    if (vatBasisPoints == null || vatBasisPoints > 10000 ||
        depositBasisPoints == null || depositBasisPoints > 10000) {
      _notice('Enter VAT and deposit percentages between 0 and 100.');
      return;
    }
    _draft.vatBasisPoints = vatBasisPoints;
    _draft.depositBasisPoints = depositBasisPoints;
    _draft.currency = chosenCurrency;
    if (client.trim() != _draft.clientName.trim()) {
      // An edited customer cannot remain associated with another client's job.
      _draft.clientId = null;
      _draft.jobId = null;
    }
    _draft.clientName = client.trim();
    _draft.date = chosenDate;
    _draft.validUntil = validUntil;
    _draft.billingAddress = address.trim();
    _draft.clientEmail = email.trim();
    _draft.clientPhone = phone.trim();
    _draft.payment = iban.trim().isEmpty ? null : QuotePaymentDetails(
      iban: iban.trim(), accountHolder: accountHolder.trim(),
      street: street.trim(), buildingNumber: buildingNumber.trim(),
      postalCode: postalCode.trim(), city: city.trim(),
      country: country.trim(),
    );
    _updated();
  }

  void _addItem() {
    _nextItemNumber++;
    _draft.items.add(QuoteReviewWorkItem(
      id: 'manual-${DateTime.now().microsecondsSinceEpoch}-$_nextItemNumber',
      title: '', description: '', quantity: '1', unitPrice: '',
    ));
    _updated();
  }

  Future<void> _saveDraft() async {
    if (_savingToServer) return;
    if (_remoteMode) {
      setState(() => _savingToServer = true);
      try {
        final saved = await RemoteQuoteRepository.shared.saveDraft(_draft);
        if (!mounted) return;
        setState(() => _draft = saved);
        QuoteReviewSessionStore.save(_draft);
        DocumentActivitySession.saved(_draft);
        widget.onSaved?.call(_draft.copy());
        _notice('Quote draft saved to your company account.');
      } catch (error) {
        if (mounted) _notice('Could not save quote: $error');
      } finally {
        if (mounted) setState(() => _savingToServer = false);
      }
      return;
    }
    QuoteReviewSessionStore.save(_draft);
    DocumentActivitySession.saved(_draft);
    widget.onSaved?.call(_draft.copy());
    _notice(_draft.isDemo
        ? 'Demo draft kept in this app session (not saved to a server).'
        : 'Draft saved in this app session only (not uploaded).');
  }

  Future<void> _approve() async {
    if (_savingToServer) return;
    // A live quote obtains its number from the server on first save.
    final issues = _draft.approvalIssues.where(
      (issue) => !_remoteMode || issue != 'Quote Number is required.',
    ).toList();
    if (issues.isNotEmpty) {
      _notice('Cannot approve: ${issues.first}');
      return;
    }
    if (_draft.terms.trim().isEmpty) {
      _notice('Enter the applicable Terms & Conditions before approval.');
      return;
    }
    if (_remoteMode) {
      setState(() => _savingToServer = true);
      try {
        final approved = await RemoteQuoteRepository.shared.approve(_draft);
        if (!mounted) return;
        setState(() => _draft = approved);
      } catch (error) {
        if (mounted && !await Sign2DigitalSubscriptionGate.handle(
            context, error)) {
          _notice('Server approval failed: $error');
        }
        return;
      } finally {
        if (mounted) setState(() => _savingToServer = false);
      }
    } else {
      _draft.approvedLocally = true;
    }
    QuoteReviewSessionStore.save(_draft);
    DocumentActivitySession.approved(_draft);
    final approvedSnapshot = _draft.copy();
    widget.onApproved?.call(approvedSnapshot);
    if (!mounted) return;
    Sign2DigitalNavigation.push<void>(context,MaterialPageRoute<void>(
      builder: (_) => QuotePreviewScreen(quote: approvedSnapshot),
    ));
  }

  static String _dateText(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  Widget _outlineAction({required String label, required VoidCallback onTap,
      required Key key, IconData? icon}) {
    return OutlinedButton.icon(
      key: key,
      onPressed: onTap,
      icon: Icon(icon ?? Icons.edit_outlined, size: 18),
      label: Text(label, maxLines: 1, style: const TextStyle(fontFamily: 'Inter',
          fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.primary)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        minimumSize: const Size(0, 40),
        side: const BorderSide(color: AppColors.primary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _panelHeader(String heading, Widget action) => Row(children: [
    Expanded(child: Text(heading, style: const TextStyle(fontFamily: 'Inter',
      fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.dark))),
    const SizedBox(width: 8),
    action,
  ]);

  Widget _detailRow(String label, String value, {bool divider = true}) => Column(children: [
    Padding(padding: const EdgeInsets.symmetric(vertical: 15), child: Row(children: [
      Expanded(flex: 4, child: Text(label, style: const TextStyle(fontFamily: 'Inter',
          fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.placeholder))),
      const SizedBox(width: 10),
      Expanded(flex: 6, child: Text(value.isEmpty ? 'Not Specified' : value,
          softWrap: true, style: TextStyle(fontFamily: 'Inter', fontSize: 14,
          fontWeight: FontWeight.w500,
          color: value.isEmpty ? const Color(0xFFE6A23C) : AppColors.dark))),
    ])),
    if (divider) const Divider(height: 1, thickness: 1, color: AppColors.lightBorder),
  ]);

  Widget _pricingRow(String label, String amount) => Padding(
    padding: const EdgeInsets.fromLTRB(10, 0, 10, 20),
    child: Row(children: [
      Expanded(child: Text(label, style: const TextStyle(fontFamily: 'Inter',
          fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.placeholder))),
      const SizedBox(width: 16),
      Expanded(child: Text(amount, textAlign: TextAlign.right,
        style: const TextStyle(fontFamily: 'Inter', fontSize: 14,
        fontWeight: FontWeight.w500, color: AppColors.dark))),
    ]),
  );

  Widget _body() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (_draft.isDemo) ...[
            Container(key: const Key('quote-review-demo-banner'),
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.placeholder.withAlpha(22),
                borderRadius: BorderRadius.circular(10)),
              child: const Text('FIGMA DEMO — sample content only. Not an AI-generated quote.',
                  style: TextStyle(fontFamily: 'Inter', color: AppColors.dark))),
          ],
          Sign2DigitalQuoteShadowPanel(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _panelHeader('Quote Details', _outlineAction(
                key: const Key('quote-edit-details'), label: 'Edit',
                onTap: _editDetails)),
              const SizedBox(height: 15),
              _detailRow('Client', _draft.clientName),
              _detailRow('Quote Number', _draft.quoteNumber.trim().isEmpty
                  ? 'Assigned automatically on save' : _draft.quoteNumber),
              _detailRow('Date', _dateText(_draft.date), divider: false),
            ]),
          ),
          const SizedBox(height: 20),
          Sign2DigitalQuoteShadowPanel(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _panelHeader('Work Items', _outlineAction(
                key: const Key('quote-add-items'), label: 'Add Items',
                icon: Icons.add, onTap: _addItem)),
              const SizedBox(height: 20),
              if (_draft.items.isEmpty)
                const Text('No work items yet. Add an item to continue.',
                  style: TextStyle(color: AppColors.placeholder))
              else
                for (var i = 0; i < _draft.items.length; i++) ...[
                  if (i > 0) const SizedBox(height: 20),
                  Sign2DigitalQuoteWorkItemCard(
                    key: ValueKey(_draft.items[i].id),
                    item: _draft.items[i], number: i + 1,
                    currency: _draft.currency, onChanged: _updated,
                  ),
                ],
            ]),
          ),
          const SizedBox(height: 20),
          _pricingRow('Subtotal', _draft.subtotalMinor == null
              ? '${quoteMoney(_draft.validSubtotalMinor, _draft.currency)} (partial)'
              : quoteMoney(_draft.subtotalMinor, _draft.currency)),
          _pricingRow('VAT (${quotePercentText(_draft.vatBasisPoints)}%)',
              quoteMoney(_draft.vatMinor, _draft.currency)),
          _pricingRow('Deposit (${quotePercentText(_draft.depositBasisPoints)}%)',
              quoteMoney(_draft.depositMinor, _draft.currency)),
          Container(
            key: const Key('quote-grand-total'),
            color: const Color(0xFFEAF4FF),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
            child: Row(children: [
              const Expanded(child: Text('Total', style: TextStyle(
                fontFamily: 'Inter', fontSize: 18, fontWeight: FontWeight.w600,
                color: AppColors.dark))),
              const SizedBox(width: 16),
              Expanded(child: Text(quoteMoney(_draft.totalMinor, _draft.currency),
                textAlign: TextAlign.right,
                style: const TextStyle(fontFamily: 'Inter', fontSize: 18,
                  fontWeight: FontWeight.w600, color: AppColors.dark))),
            ]),
          ),
          if (!_draft.allItemPricesValid) ...[
            const SizedBox(height: 8),
            const Text('Pricing incomplete — resolve amber fields before approval.',
              style: TextStyle(fontFamily: 'Inter', fontSize: 12,
                  color: Color(0xFFE6A23C))),
          ],
          const SizedBox(height: 25),
          Container(
            decoration: BoxDecoration(
              color: AppColors.white,
              border: Border.all(color: AppColors.lightBorder),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              InkWell(
                key: const Key('quote-terms-toggle'),
                onTap: () => setState(() => _termsExpanded = !_termsExpanded),
                child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [
                  const Expanded(child: Text('Terms & Conditions', style: TextStyle(
                      fontFamily: 'Inter', fontSize: 14,
                      fontWeight: FontWeight.w500, color: AppColors.dark))),
                  Icon(_termsExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      color: AppColors.dark),
                ])),
              ),
              if (_termsExpanded) Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: TextFormField(
                  key: const Key('quote-terms-edit'),
                  initialValue: _draft.terms,
                  minLines: 3, maxLines: null,
                  onChanged: (value) { _draft.terms = value; _updated(); },
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 14,
                    color: AppColors.dark),
                  decoration: const InputDecoration(
                    hintText: 'No company terms attached. Enter applicable terms here.',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ]),
          ),
        ]),
      ),
    ),
  );

  Widget _bottomButtons() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 36, 20, 24),
    child: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 900),
      child: LayoutBuilder(builder: (context, constraints) {
        final save = SizedBox(height: 48,
          child: OutlinedButton(
            key: const Key('quote-save-draft'),
            onPressed: _saveDraft,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.primary),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('Save Draft', textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Inter', fontSize: 16,
                fontWeight: FontWeight.w500, color: AppColors.primary)),
          ),
        );
        final approve = Sign2DigitalPrimaryButton(
          key: const Key('quote-approve'), label: 'Approve Quote', onPressed: _approve);
        if (constraints.maxWidth < 330) {
          return Column(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(width: double.infinity, child: save),
            const SizedBox(height: 10),
            approve,
          ]);
        }
        return Row(children: [
          Expanded(child: save),
          const SizedBox(width: 10),
          Expanded(child: approve),
        ]);
      }),
    )),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.white,
    body: SafeArea(child: Column(children: [
      Sign2DigitalHeader(title: 'Review Quote',
        onBack: () => Navigator.of(context).maybePop()),
      Expanded(child: SingleChildScrollView(
        key: const Key('review-quote-scroll'),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _body(),
          _bottomButtons(),
        ]),
      )),
    ])),
  );
}
