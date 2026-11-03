import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/sign2digital_bottom_navigation_bar.dart';
import '../../../../core/widgets/sign2digital_header.dart';
import '../../../../core/widgets/sign2digital_primary_button.dart';
import '../../../auth/data/mobile_auth_repository.dart';
import '../../../../core/services/sign_api_client.dart';
import '../../data/device_phone_contact_source.dart';
import '../../data/mock_import_contacts.dart';
import '../../data/remote_client_repository.dart';
import '../../domain/client_draft.dart';
import '../../models/import_contact_model.dart';
import '../widgets/sign2digital_import_contact_card.dart';

/// Same approved Import Clients screen and cards, with opt-in phone reading
/// and a separate explicit confirmation before uploading reviewed contacts.
class ImportClientsScreen extends StatefulWidget {
  const ImportClientsScreen({
    super.key,
    this.contacts,
    this.onReviewSelected,
    this.onTabSelected,
    this.contactSource,
    this.clientRepository,
  });

  final List<ImportContactModel>? contacts;
  final ValueChanged<List<ImportContactModel>>? onReviewSelected;
  final ValueChanged<int>? onTabSelected;
  final PhoneContactSource? contactSource;
  final RemoteClientRepository? clientRepository;

  @override
  State<ImportClientsScreen> createState() => _ImportClientsScreenState();
}

class _ImportClientsScreenState extends State<ImportClientsScreen> {
  late List<ImportContactModel> _contacts;
  late Set<String> _selectedIds;
  bool _loadingContacts = false;
  bool _savingContacts = false;
  String? _contactError;

  bool get _liveImport =>
      widget.contacts == null && widget.onReviewSelected == null &&
      MobileAuthRepository.shared.isSignedIn;

  @override
  void initState() {
    super.initState();
    _contacts = List.of(widget.contacts ??
        (_liveImport ? <ImportContactModel>[] : buildDemoImportContacts()));
    _selectedIds = {
      for (final item in _contacts)
        if (item.isSelected) item.id,
    };
  }

  List<ImportContactModel> get _selected => [
    for (final item in _contacts)
      if (_selectedIds.contains(item.id)) item.copyWith(isSelected: true),
  ];

  Future<void> _readContacts() async {
    if (_loadingContacts) return;
    setState(() {
      _loadingContacts = true;
      _contactError = null;
    });
    try {
      final contacts = await (widget.contactSource ??
          const DevicePhoneContactSource()).load();
      if (!mounted) return;
      setState(() {
        _contacts = contacts;
        _selectedIds = {};
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _contactError =
          'Unable to access contacts. Check your device permissions or add clients manually.');
    } finally {
      if (mounted) setState(() => _loadingContacts = false);
    }
  }

  void _toggle(ImportContactModel contact, bool checked) {
    setState(() {
      if (checked) {
        _selectedIds.add(contact.id);
      } else {
        _selectedIds.remove(contact.id);
      }
    });
  }

  Future<void> _saveReviewed(List<ImportContactModel> chosen,
      BuildContext sheetContext) async {
    if (_savingContacts) return;
    if (chosen.length > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at most 100 contacts at a time.')),
      );
      return;
    }
    setState(() => _savingContacts = true);
    try {
      // Imported contact values remain exactly as selected/reviewed; no
      // fabricated company names, notes, or international dialing codes.
      final drafts = chosen.map((item) => ClientDraft(
        fullName: item.fullName.trim(),
        companyName: '',
        address: '',
        countryIsoCode: 'CH',
        dialingCode: '',
        phoneNumber: item.phoneNumber.trim(),
        email: item.email.trim(),
        notes: '',
      )).toList();
      final count = await (widget.clientRepository ??
          RemoteClientRepository.shared).importReviewed(drafts);
      if (!mounted) return;
      if (sheetContext.mounted) Navigator.of(sheetContext).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$count clients imported to the selected company.')),
      );
      Navigator.of(context).pop(2);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(error is SignApiException
            ? error.message : 'Unable to import selected clients.'),
      ));
    } finally {
      if (mounted) setState(() => _savingContacts = false);
    }
  }

  void _review() {
    final selected = _selected;
    if (selected.isEmpty) return;
    FocusManager.instance.primaryFocus?.unfocus();
    if (widget.onReviewSelected != null) {
      widget.onReviewSelected!(List.unmodifiable(selected));
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.65,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Selected contacts (${selected.length})',
                  style: AppTextStyles.heading,
                ),
                const SizedBox(height: 8),
                Text(
                  _liveImport
                      ? 'Review each name, phone and email before importing to your current company.'
                      : 'Demo preview only. No device contacts accessed and nothing imported.',
                  style: AppTextStyles.subtitle,
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: selected.length,
                    separatorBuilder: (context, index) => const Divider(),
                    itemBuilder: (context, index) {
                      final item = selected[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(item.fullName),
                        subtitle: Text('${item.phoneNumber} • ${item.email}'),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                if (_liveImport) ...[
                  Sign2DigitalPrimaryButton(
                    key: const Key('confirm-import-clients'),
                    label: 'Import Selected Contacts',
                    enabled: !_savingContacts,
                    onPressed: () => _saveReviewed(selected, sheetContext),
                  ),
                  const SizedBox(height: 8),
                ],
                TextButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  child: Text(_liveImport ? 'Cancel' : 'Close preview'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _chooseTab(int index) {
    if (index == 2) {
      Navigator.of(context).maybePop();
      return;
    }
    if (widget.onTabSelected != null) {
      widget.onTabSelected!(index);
    } else {
      Navigator.of(context).pop(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Sign2DigitalHeader(
              title: 'Import Clients',
              onBack: () => Navigator.of(context).maybePop(),
            ),
            if (_liveImport) Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Column(children: [
                OutlinedButton.icon(
                  key: const Key('load-phone-contacts'),
                  onPressed: _loadingContacts ? null : _readContacts,
                  icon: const Icon(Icons.contacts_outlined),
                  label: Text(_loadingContacts
                      ? 'Loading contacts...' : 'Choose Phone Contacts'),
                ),
                if (_contactError != null)
                  Text(_contactError!, style: AppTextStyles.subtitle),
              ]),
            ),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth:
                    MediaQuery.orientationOf(context) == Orientation.landscape
                        ? double.infinity : 560),
                  child: _loadingContacts
                      ? const Center(child: CircularProgressIndicator())
                      : _contacts.isEmpty
                      ? Center(
                          child: Text(
                            _liveImport
                                ? 'Choose Phone Contacts to review entries before importing.'
                                : 'No contacts available in this preview',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.subtitle,
                          ),
                        )
                      : ListView.separated(
                          key: const Key('import-clients-list'),
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                          itemCount: _contacts.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final item = _contacts[index];
                            return Sign2DigitalImportContactCard(
                              key: ValueKey(item.id),
                              contact: item,
                              selected: _selectedIds.contains(item.id),
                              onChanged: (checked) => _toggle(item, checked),
                            );
                          },
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth:
                MediaQuery.orientationOf(context) == Orientation.landscape
                    ? double.infinity : 560),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
                child: Sign2DigitalPrimaryButton(
                  key: const Key('review-selected-button'),
                  label: 'Review Selected',
                  enabled: _selectedIds.isNotEmpty && !_savingContacts,
                  onPressed: _review,
                ),
              ),
            ),
          ),
          Sign2DigitalBottomNavigationBar(
            selectedIndex: 2,
            onSelected: _chooseTab,
          ),
        ],
      ),
    );
  }
}
