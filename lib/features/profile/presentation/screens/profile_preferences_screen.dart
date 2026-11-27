import 'package:flutter/material.dart';

import '../../../../core/localization/app_language_controller.dart';
import '../../../../core/localization/app_strings.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/sign2digital_bottom_navigation_bar.dart';
import '../../../../core/widgets/sign2digital_header.dart';
import '../../../../core/widgets/sign2digital_primary_button.dart';
import '../../../../core/widgets/sign2digital_selection_field.dart';
import '../../../../core/widgets/sign2digital_selection_sheet.dart';
import '../../data/profile_preferences_repository.dart';
import '../widgets/profile_notification_row.dart';

/// Profile & Settings -> Preferences.
/// Uses the existing preferences repository and a device-local UI language.
/// Notification preferences are never presented as OS permissions.
class ProfilePreferencesScreen extends StatefulWidget {
  const ProfilePreferencesScreen({
    super.key,
    this.repository = LocalProfilePreferencesRepository.shared,
    this.onNavigationSelected,
    this.languageController,
  });

  final ProfilePreferencesRepository repository;
  final AppLanguageController? languageController;
  final ValueChanged<int>? onNavigationSelected;

  @override
  State<ProfilePreferencesScreen> createState() =>
      _ProfilePreferencesScreenState();
}

class _ProfilePreferencesScreenState extends State<ProfilePreferencesScreen> {
  static const _languages = AppLanguages.names;
  AppLanguageController get _language =>
      widget.languageController ?? AppLanguageController.shared;
  String _storedLanguage = 'English';
  bool _languageSelected = false;
  static const _dateFormats = ['DD/MM/YYYY', 'MM/DD/YYYY', 'YYYY-MM-DD'];
  static const _timeFormats = ['24 hours', '12 hours'];
  static const _timeZones = [
    'Europe/Zurich',
    'Europe/London',
    'America/New_York',
    'Asia/Karachi',
    'UTC',
  ];

  ProfilePreferences _draft = const ProfilePreferences();
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final saved = await widget.repository.load();
      if (!mounted) {
        return;
      }
      setState(() {
        _storedLanguage = _languages.contains(saved.language)
            ? saved.language : 'English';
        _languageSelected = false;
        final locale = _language.effectiveLocale(
          WidgetsBinding.instance.platformDispatcher.locales,
        );
        _draft = saved.copyWith(language: AppLanguages.nameFor(locale));
        _loading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = 'Could not load preferences.';
      });
    }
  }

  Future<void> _pick({
    required String title,
    required String current,
    required List<String> options,
    required IconData icon,
    required ValueChanged<String> onPicked,
  }) async {
    if (_saving) return;
    final strings = AppStrings.of(context);
    final value = await Sign2DigitalSelectionSheet.show(
      context,
      title: strings.tr(title),
      subtitle: strings.tr('Choose a ${title.toLowerCase()} option'),
      labelForOption: strings.tr,
      options: options,
      selected: current,
      icon: icon,
      iconForOption: (option) => switch (title) {
        'Language' => Icons.translate_rounded,
        'Date Format' => Icons.calendar_month_outlined,
        'Time Format' => option == '24 hours'
            ? Icons.schedule_outlined : Icons.watch_later_outlined,
        'Time Zone' => option == 'UTC'
            ? Icons.public_outlined : Icons.location_on_outlined,
        _ => icon,
      },
      keyForOption: (option) => Key(
        'preferences-option-${option.replaceAll('/', '-').replaceAll(' ', '-')}',
      ),
    );
    if (!mounted || _saving || value == null) return;
    if (title != 'Language') {
      setState(() => onPicked(value));
      return;
    }

    // The interface choice is device-local. Apply it immediately instead of
    // waiting for an unrelated account preferences request to succeed.
    setState(() => _saving = true);
    try {
      await _language.select(value);
      if (!mounted) return;
      setState(() => onPicked(value));
    } catch (_) {
      if (mounted) _showMessage('Unable to save preferences. Try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _save() async {
    if (_saving || _loading) {
      return;
    }
    final valid = _languages.contains(_draft.language) &&
        _dateFormats.contains(_draft.dateFormat) &&
        _timeFormats.contains(_draft.timeFormat) &&
        _timeZones.contains(_draft.timeZone);
    if (!valid) {
      _showMessage('Select supported preference values.');
      return;
    }
    setState(() => _saving = true);
    try {
      final selectedLanguage = _draft.language;
      final shouldApplyLanguage = _languageSelected;
      final savedLanguage = shouldApplyLanguage
          ? selectedLanguage : _storedLanguage;
      await widget.repository.save(_draft.copyWith(language: savedLanguage));
      _storedLanguage = savedLanguage;
      if (shouldApplyLanguage) _languageSelected = false;
      if (mounted) {
        _showMessage('Preferences saved.', locale: _language.value);
      }
    } catch (_) {
      if (mounted) {
        _showMessage('Unable to save preferences. Try again.');
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _showMessage(String message, {Locale? locale}) {
    final strings = locale == null ? AppStrings.of(context) : AppStrings(locale);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(strings.tr(message))));
  }

  void _navigate(int index) {
    if (index == 4) {
      Navigator.of(context).maybePop();
      return;
    }
    final onSelected = widget.onNavigationSelected;
    if (onSelected == null) {
      _showMessage('Navigation is not connected yet.');
      return;
    }
    Navigator.of(context).maybePop();
    onSelected(index);
  }

  Widget _selection({
    required Key key,
    required String label,
    required String value,
    String? displayValue,
    required IconData icon,
    required List<String> options,
    required ValueChanged<String> onSelected,
    bool chevron = true,
  }) => Sign2DigitalSelectionField(
    key: key,
    label: AppStrings.of(context).tr(label),
    value: AppStrings.of(context).tr(displayValue ?? value),
    hintText: AppStrings.of(context).tr(displayValue ?? value),
    iconAsset: '',
    leadingIcon: icon,
    leadingIconSize: 24,
    valueTextStyle: AppTextStyles.fieldHint,
    trailing: chevron
        ? const Icon(Icons.keyboard_arrow_down_rounded,
            color: AppColors.secondaryText, size: 24)
        : null,
    onTap: () => _pick(
      title: label,
      current: value,
      options: options,
      icon: icon,
      onPicked: onSelected,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final tr = AppStrings.of(context).tr;
    return Scaffold(
    backgroundColor: AppColors.white,
    body: SafeArea(bottom: false, child: Column(children: [
      Sign2DigitalHeader(title: tr('Preferences')),
      Expanded(child: Center(child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth:
            MediaQuery.orientationOf(context) == Orientation.landscape
                ? double.infinity : 720),
        child: ListView(
          key: const Key('preferences-scroll'),
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          children: [
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 30),
                child: Center(child: CircularProgressIndicator()))
            else if (_error != null)
              TextButton(
                key: const Key('preferences-retry'),
                onPressed: _load,
                child: Text('${tr(_error!)} ${tr('Tap to retry.')}'))
            else ...[
              _selection(
                key: const Key('preferences-language'),
                label: 'Language',
                value: _draft.language,
                icon: Icons.language_rounded,
                options: _languages,
                chevron: true,
                onSelected: (value) {
                  _languageSelected = true;
                  _draft = _draft.copyWith(language: value);
                },
              ),
              const SizedBox(height: 8),
              Text(
                tr('Your interface language updates immediately. Save Preferences to synchronize notification language with your account.'),
                style: const TextStyle(fontFamily: 'Inter', fontSize: 12,
                  color: AppColors.secondaryText),
              ),
              const SizedBox(height: 20),
              _selection(
                key: const Key('preferences-date-format'),
                label: 'Date Format',
                value: _draft.dateFormat,
                displayValue: _draft.dateFormat == 'DD/MM/YYYY'
                    ? 'DD / MM / YYYY' : null,
                icon: Icons.calendar_today_outlined,
                options: _dateFormats,
                onSelected: (value) =>
                    _draft = _draft.copyWith(dateFormat: value),
              ),
              const SizedBox(height: 20),
              _selection(
                key: const Key('preferences-time-format'),
                label: 'Time Format',
                value: _draft.timeFormat,
                icon: Icons.schedule_outlined,
                options: _timeFormats,
                onSelected: (value) =>
                    _draft = _draft.copyWith(timeFormat: value),
              ),
              const SizedBox(height: 20),
              _selection(
                key: const Key('preferences-time-zone'),
                label: 'Time Zone',
                value: _draft.timeZone,
                icon: Icons.public_outlined,
                options: _timeZones,
                onSelected: (value) =>
                    _draft = _draft.copyWith(timeZone: value),
              ),
              const SizedBox(height: 20),
              Text(tr('Notifications'), style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 18,
                height: 1.0,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.3,
                color: AppColors.dark,
              )),
              const SizedBox(height: 10),
              ProfileNotificationRow(
                key: const Key('preferences-push'),
                title: tr('Push Notification'),
                description: tr('Receive important updates'),
                enabled: _draft.pushNotifications,
                onChanged: (value) => setState(() =>
                    _draft = _draft.copyWith(pushNotifications: value)),
              ),
              const SizedBox(height: 20),
              ProfileNotificationRow(
                key: const Key('preferences-email'),
                title: tr('Email Notification'),
                description: tr('Save your email preference for supported messages'),
                enabled: _draft.emailNotifications,
                onChanged: (value) => setState(() =>
                    _draft = _draft.copyWith(emailNotifications: value)),
              ),
              const SizedBox(height: 20),
              ProfileNotificationRow(
                key: const Key('preferences-sms'),
                title: tr('SMS Notification'),
                description: tr('Unavailable until SMS delivery is configured'),
                enabled: false,
                onChanged: (_) => _showMessage(
                    'SMS notifications are unavailable until configured.'),
              ),
              const SizedBox(height: 45),
              Sign2DigitalPrimaryButton(
                key: const Key('preferences-save'),
                label: tr('Save Preferences'),
                height: 48,
                loading: _saving,
                onPressed: _save,
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
}
