import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/sign2digital_bottom_navigation_bar.dart';
import '../../../../core/widgets/sign2digital_header.dart';
import '../../../../core/widgets/sign2digital_primary_button.dart';
import '../../data/mock_import_contacts.dart';
import '../../models/import_contact_model.dart';
import '../widgets/sign2digital_import_contact_card.dart';

/// Selection preview only. Device contacts are not accessed until explicitly
/// implemented in a later product milestone.
class ImportClientsScreen extends StatefulWidget {
  const ImportClientsScreen({
    super.key,
    this.contacts,
    this.onReviewSelected,
    this.onTabSelected,
  });

  final List<ImportContactModel>? contacts;
  final ValueChanged<List<ImportContactModel>>? onReviewSelected;

  /// Selects a dashboard tab (0–4); the parent Clients screen owns navigation.
  final ValueChanged<int>? onTabSelected;

  @override
  State<ImportClientsScreen> createState() => _ImportClientsScreenState();
}

class _ImportClientsScreenState extends State<ImportClientsScreen> {
  late final List<ImportContactModel> _contacts;
  late final Set<String> _selectedIds;

  @override
  void initState() {
    super.initState();
    _contacts = List.of(widget.contacts ?? buildDemoImportContacts());
    _selectedIds = {
      for (final item in _contacts)
        if (item.isSelected) item.id,
    };
  }

  List<ImportContactModel> get _selected => [
    for (final item in _contacts)
      if (_selectedIds.contains(item.id)) item.copyWith(isSelected: true),
  ];

  void _toggle(ImportContactModel contact, bool checked) {
    setState(() {
      if (checked) {
        _selectedIds.add(contact.id);
      } else {
        _selectedIds.remove(contact.id);
      }
    });
  }

  void _review() {
    final selected = _selected;
    if (selected.isEmpty) {
      return;
    }
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
                const Text(
                  'Demo preview only. No device contacts accessed and nothing imported.',
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
                TextButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  child: const Text('Close preview'),
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
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: _contacts.isEmpty
                      ? const Center(
                          child: Text(
                            'No contacts available in this preview',
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
              constraints: const BoxConstraints(maxWidth: 560),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
                child: Sign2DigitalPrimaryButton(
                  key: const Key('review-selected-button'),
                  label: 'Review Selected',
                  enabled: _selectedIds.isNotEmpty,
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
