import 'package:flutter/material.dart';
import '../../../../core/widgets/sign2digital_approved_confirmation.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/sign2digital_bottom_navigation_bar.dart';
import '../../../../core/widgets/sign2digital_header.dart';
import '../../../../core/widgets/sign2digital_selection_field.dart';
import '../../../../core/widgets/sign2digital_selection_sheet.dart';
import '../../data/app_settings_repository.dart';
import '../widgets/profile_notification_row.dart';

/// Settings uses the existing Preferences form surfaces and compact toggles.
/// All selections auto-save; the clear-cache row is a one-shot action.
class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({
    super.key,
    this.repository = LocalAppSettingsRepository.shared,
    this.cache = LocalDisposableCache.shared,
    this.onNavigationSelected,
  });

  final AppSettingsRepository repository;
  final AppDisposableCache cache;
  final ValueChanged<int>? onNavigationSelected;

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  static const _heading = TextStyle(
    fontFamily: 'Inter', fontSize: 18, fontWeight: FontWeight.w600,
    height: 1, letterSpacing: -0.3, color: AppColors.dark,
  );
  static const _documentTypes = ['Quote', 'Invoice', 'Report', 'Addendum'];
  // These four codes are supported by the quote-saving API.
  static const _currencies = [
    'CHF (Swiss franc)',
    'EUR (Euro)',
    'GBP (British pound)',
    'USD (US dollar)',
  ];
  static const _units = ['Metric (m, kg)', 'Imperial (ft, lb)'];

  AppSettings _settings = const AppSettings();
  bool _loading = true;
  bool _saving = false;
  bool _clearing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final value = await widget.repository.load();
      if (!mounted) {
        return;
      }
      setState(() { _settings = value; _loading = false; });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = 'Unable to load app settings.';
      });
    }
  }

  void _message(String text) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _persist(AppSettings next) async {
    if (_saving || _loading) {
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.repository.save(next);
      if (!mounted) {
        return;
      }
      setState(() => _settings = next);
      if (next.offlineMode && !_settingsSupportsOffline) {
        _message('Offline Mode preference saved. Offline access is not '
          'available until caching and synchronization are connected.');
      }
    } catch (_) {
      _message('Unable to save this setting. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  // No cache/sync integration is present in the current application.
  bool get _settingsSupportsOffline => false;

  Future<void> _pick({
    required String label,
    required String current,
    required List<String> values,
    required IconData icon,
    required AppSettings Function(String) update,
  }) async {
    if (_saving || _loading) {
      return;
    }
    final choice = await Sign2DigitalSelectionSheet.show(
      context,
      title: label,
      subtitle: 'Choose a ${label.toLowerCase()} option',
      options: values,
      selected: current,
      icon: icon,
      iconForOption: (value) => switch (label) {
        'Default Document Type' => switch (value) {
          'Quote' => Icons.request_quote_outlined,
          'Invoice' => Icons.receipt_long_outlined,
          'Report' => Icons.description_outlined,
          'Addendum' => Icons.note_add_outlined,
          _ => Icons.insert_drive_file_outlined,
        },
        'Default Currency' => Icons.account_balance_wallet_outlined,
        'Units' => value.startsWith('Metric')
            ? Icons.straighten_outlined : Icons.square_foot_outlined,
        _ => icon,
      },
      keyForOption: (value) => Key(
        'app-settings-option-${value.toLowerCase().replaceAll(' ', '-').replaceAll('/', '-')}',
      ),
    );
    if (!mounted || choice == null || choice == current) {
      return;
    }
    await _persist(update(choice));
  }

  Widget _field({
    required Key key,
    required String title,
    required String value,
    required IconData icon,
    required List<String> options,
    required AppSettings Function(String) update,
  }) => Sign2DigitalSelectionField(
    key: key,
    label: title,
    value: value,
    hintText: value,
    iconAsset: '',
    leadingIcon: icon,
    leadingIconSize: 24,
    valueTextStyle: AppTextStyles.fieldHint,
    trailing: const Icon(Icons.keyboard_arrow_down_rounded,
      size: 24, color: AppColors.secondaryText),
    onTap: () => _pick(
      label: title, current: value, values: options,
      icon: icon, update: update),
  );

  Future<void> _clearCache() async {
    if (_clearing || _saving) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => Sign2DigitalApprovedConfirmation(
        title: const Text('Clear Cache?'),
        content: const Text(
          'Only disposable cached files will be deleted. '
          'Saved documents, account details, and unsynchronized '
          'offline changes will be preserved.'),
        actions: [
          TextButton(
            key: const Key('app-settings-cache-cancel'),
            onPressed: () => Navigator.of(dialog).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            key: const Key('app-settings-cache-confirm'),
            onPressed: () => Navigator.of(dialog).pop(true),
            child: const Text('Clear Cache'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) {
      return;
    }
    setState(() => _clearing = true);
    try {
      final removed = await widget.cache.clear();
      if (removed == 0) {
        _message('No disposable cached files found.');
      } else {
        _message('Disposable app cache cleared.');
      }
    } catch (_) {
      _message('Unable to clear disposable cache.');
    } finally {
      if (mounted) {
        setState(() => _clearing = false);
      }
    }
  }

  void _navigate(int index) {
    if (index == 4) {
      Navigator.of(context).maybePop();
      return;
    }
    final onSelected = widget.onNavigationSelected;
    if (onSelected == null) {
      _message('Navigation is not connected yet.');
      return;
    }
    Navigator.of(context).maybePop();
    onSelected(index);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.white,
    body: SafeArea(bottom: false, child: Column(children: [
      const Sign2DigitalHeader(title: 'Settings'),
      Expanded(child: Center(child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth:
            MediaQuery.orientationOf(context) == Orientation.landscape
                ? double.infinity : 720),
        child: ListView(
          key: const Key('app-settings-scroll'),
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          children: [
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 30),
                child: Center(child: CircularProgressIndicator()))
            else if (_error != null)
              TextButton(
                key: const Key('app-settings-retry'),
                onPressed: _load,
                child: Text('$_error Tap to retry.'))
            else ...[
              const Text('Default Settings', style: _heading),
              const SizedBox(height: 20),
              _field(
                key: const Key('app-settings-document-type'),
                title: 'Default Document Type',
                value: _settings.documentType,
                icon: Icons.file_present_outlined,
                options: _documentTypes,
                update: (v) => _settings.copyWith(documentType: v),
              ),
              const SizedBox(height: 20),
              _field(
                key: const Key('app-settings-currency'),
                title: 'Default Currency', value: _settings.currency,
                icon: Icons.currency_exchange_rounded,
                options: _currencies,
                update: (v) => _settings.copyWith(currency: v),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your choice is saved as the default for new quotations. '
                'Existing prices are never converted. Invoices, deposits '
                'and expenses remain CHF until multi-currency accounting '
                'is enabled on the server.',
                style: TextStyle(fontFamily: 'Inter', fontSize: 12,
                  color: AppColors.secondaryText),
              ),
              const SizedBox(height: 20),
              _field(
                key: const Key('app-settings-units'),
                title: 'Units', value: _settings.units,
                icon: Icons.straighten_outlined, options: _units,
                update: (v) => _settings.copyWith(units: v),
              ),
              const SizedBox(height: 20),
              const Text('Data & Storage', style: _heading),
              const SizedBox(height: 20),
              ProfileNotificationRow(
                key: const Key('app-settings-offline-mode'),
                title: 'Offline Mode',
                description: 'Allow offline access to recent data',
                enabled: _settings.offlineMode,
                onChanged: (v) => _persist(_settings.copyWith(offlineMode: v)),
              ),
              const SizedBox(height: 20),
              ProfileNotificationRow(
                key: const Key('app-settings-clear-cache'),
                title: 'Clear Cache',
                description: 'Free up storage space',
                // This is a momentary action, never a persistent preference.
                enabled: _clearing,
                onChanged: (_) => _clearCache(),
              ),
            ],
          ],
        ),
      ))),
    ])),
    bottomNavigationBar: Sign2DigitalBottomNavigationBar(
      selectedIndex: 4,
      onSelected: _navigate,
    ),
  );
}
