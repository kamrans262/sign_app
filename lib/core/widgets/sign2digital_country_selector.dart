// Sign2Digital: reusable, frontend-only phone country picker.
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'sign2digital_outlined_container.dart';

@immutable
class Sign2DigitalCountry {
  const Sign2DigitalCountry({
    required this.isoCode,
    required this.name,
    required this.dialCode,
    required this.flag,
  });

  final String isoCode;
  final String name;
  final String dialCode;
  final String flag;

  String get displayName => '$name ($dialCode)';
}

/// Curated initial list; future production work can add a complete ISO catalog.
abstract final class Sign2DigitalCountries {
  static const switzerland = Sign2DigitalCountry(
    isoCode: 'CH',
    name: 'Switzerland',
    dialCode: '+41',
    flag: '🇨🇭',
  );
  static const canada = Sign2DigitalCountry(
    isoCode: 'CA',
    name: 'Canada',
    dialCode: '+1',
    flag: '🇨🇦',
  );

  static const all = <Sign2DigitalCountry>[
    Sign2DigitalCountry(
      isoCode: 'AU',
      name: 'Australia',
      dialCode: '+61',
      flag: '🇦🇺',
    ),
    Sign2DigitalCountry(
      isoCode: 'AT',
      name: 'Austria',
      dialCode: '+43',
      flag: '🇦🇹',
    ),
    Sign2DigitalCountry(
      isoCode: 'BD',
      name: 'Bangladesh',
      dialCode: '+880',
      flag: '🇧🇩',
    ),
    Sign2DigitalCountry(
      isoCode: 'BE',
      name: 'Belgium',
      dialCode: '+32',
      flag: '🇧🇪',
    ),
    Sign2DigitalCountry(
      isoCode: 'BR',
      name: 'Brazil',
      dialCode: '+55',
      flag: '🇧🇷',
    ),
    canada,
    Sign2DigitalCountry(
      isoCode: 'CN',
      name: 'China',
      dialCode: '+86',
      flag: '🇨🇳',
    ),
    Sign2DigitalCountry(
      isoCode: 'DK',
      name: 'Denmark',
      dialCode: '+45',
      flag: '🇩🇰',
    ),
    Sign2DigitalCountry(
      isoCode: 'FR',
      name: 'France',
      dialCode: '+33',
      flag: '🇫🇷',
    ),
    Sign2DigitalCountry(
      isoCode: 'DE',
      name: 'Germany',
      dialCode: '+49',
      flag: '🇩🇪',
    ),
    Sign2DigitalCountry(
      isoCode: 'IN',
      name: 'India',
      dialCode: '+91',
      flag: '🇮🇳',
    ),
    Sign2DigitalCountry(
      isoCode: 'IE',
      name: 'Ireland',
      dialCode: '+353',
      flag: '🇮🇪',
    ),
    Sign2DigitalCountry(
      isoCode: 'IT',
      name: 'Italy',
      dialCode: '+39',
      flag: '🇮🇹',
    ),
    Sign2DigitalCountry(
      isoCode: 'JP',
      name: 'Japan',
      dialCode: '+81',
      flag: '🇯🇵',
    ),
    Sign2DigitalCountry(
      isoCode: 'MY',
      name: 'Malaysia',
      dialCode: '+60',
      flag: '🇲🇾',
    ),
    Sign2DigitalCountry(
      isoCode: 'NL',
      name: 'Netherlands',
      dialCode: '+31',
      flag: '🇳🇱',
    ),
    Sign2DigitalCountry(
      isoCode: 'NZ',
      name: 'New Zealand',
      dialCode: '+64',
      flag: '🇳🇿',
    ),
    Sign2DigitalCountry(
      isoCode: 'NO',
      name: 'Norway',
      dialCode: '+47',
      flag: '🇳🇴',
    ),
    Sign2DigitalCountry(
      isoCode: 'PK',
      name: 'Pakistan',
      dialCode: '+92',
      flag: '🇵🇰',
    ),
    Sign2DigitalCountry(
      isoCode: 'SA',
      name: 'Saudi Arabia',
      dialCode: '+966',
      flag: '🇸🇦',
    ),
    Sign2DigitalCountry(
      isoCode: 'SG',
      name: 'Singapore',
      dialCode: '+65',
      flag: '🇸🇬',
    ),
    Sign2DigitalCountry(
      isoCode: 'ZA',
      name: 'South Africa',
      dialCode: '+27',
      flag: '🇿🇦',
    ),
    Sign2DigitalCountry(
      isoCode: 'KR',
      name: 'South Korea',
      dialCode: '+82',
      flag: '🇰🇷',
    ),
    Sign2DigitalCountry(
      isoCode: 'ES',
      name: 'Spain',
      dialCode: '+34',
      flag: '🇪🇸',
    ),
    Sign2DigitalCountry(
      isoCode: 'SE',
      name: 'Sweden',
      dialCode: '+46',
      flag: '🇸🇪',
    ),
    switzerland,
    Sign2DigitalCountry(
      isoCode: 'TR',
      name: 'Türkiye',
      dialCode: '+90',
      flag: '🇹🇷',
    ),
    Sign2DigitalCountry(
      isoCode: 'AE',
      name: 'United Arab Emirates',
      dialCode: '+971',
      flag: '🇦🇪',
    ),
    Sign2DigitalCountry(
      isoCode: 'GB',
      name: 'United Kingdom',
      dialCode: '+44',
      flag: '🇬🇧',
    ),
    Sign2DigitalCountry(
      isoCode: 'US',
      name: 'United States',
      dialCode: '+1',
      flag: '🇺🇸',
    ),
  ];
}

class Sign2DigitalCountrySelector extends StatelessWidget {
  const Sign2DigitalCountrySelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final Sign2DigitalCountry selected;
  final ValueChanged<Sign2DigitalCountry> onChanged;

  Future<void> _openSelector(BuildContext context) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final country = await showModalBottomSheet<Sign2DigitalCountry>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.white,
      builder: (_) => const _CountrySelectionSheet(),
    );
    if (country != null) onChanged(country);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Country calling code ${selected.name} ${selected.dialCode}',
      button: true,
      child: InkWell(
        key: const Key('country-selector'),
        borderRadius: BorderRadius.circular(8),
        onTap: () => _openSelector(context),
        child: Sign2DigitalOutlinedContainer(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(selected.flag, style: const TextStyle(fontSize: 15)),
              const SizedBox(width: 5),
              Text(selected.dialCode, style: AppTextStyles.fieldInput),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountrySelectionSheet extends StatefulWidget {
  const _CountrySelectionSheet();

  @override
  State<_CountrySelectionSheet> createState() => _CountrySelectionSheetState();
}

class _CountrySelectionSheetState extends State<_CountrySelectionSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = Sign2DigitalCountries.all.where((item) {
      final needle = _query.toLowerCase().trim();
      return item.name.toLowerCase().contains(needle) ||
          item.dialCode.contains(needle) ||
          item.isoCode.toLowerCase().contains(needle);
    }).toList();
    final availableHeight = MediaQuery.sizeOf(context).height * 0.67;
    return SizedBox(
      height: availableHeight,
      child: Column(
        children: [
          const SizedBox(height: 16),
          Text('Select country', style: AppTextStyles.heading),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: TextField(
              key: const Key('country-search'),
              onChanged: (value) => setState(() => _query = value),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                labelText: 'Search country or calling code',
                prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final country = filtered[index];
                return ListTile(
                  key: Key('country-${country.isoCode}'),
                  leading: Text(
                    country.flag,
                    style: const TextStyle(fontSize: 24),
                  ),
                  title: Text(country.name, style: AppTextStyles.fieldInput),
                  trailing: Text(
                    country.dialCode,
                    style: AppTextStyles.fieldInput,
                  ),
                  onTap: () => Navigator.of(context).pop(country),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
