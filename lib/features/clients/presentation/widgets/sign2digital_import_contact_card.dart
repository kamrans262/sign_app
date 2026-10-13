import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sign2digital_checkbox.dart';
import '../../../../core/widgets/sign2digital_outlined_container.dart';
import '../../models/import_contact_model.dart';

/// Selectable demo/device contact. The entire row is a tap target.
class Sign2DigitalImportContactCard extends StatelessWidget {
  const Sign2DigitalImportContactCard({
    super.key,
    required this.contact,
    required this.selected,
    required this.onChanged,
  });

  final ImportContactModel contact;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      child: Sign2DigitalOutlinedContainer(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: InkWell(
          key: ValueKey('import-contact-${contact.id}'),
          onTap: () => onChanged(!selected),
          child: Row(
            children: [
              Sign2DigitalCheckbox(
                value: selected,
                onChanged: onChanged,
                showLabel: false,
                boxSize: 16,
                label: 'Select ${contact.fullName}, ${contact.phoneNumber}',
              ),
              const SizedBox(width: 16),
              _ImportAvatar(contact: contact),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contact.fullName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.3,
                        color: AppColors.dark,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(contact.phoneNumber, style: _detailStyle),
                    const SizedBox(height: 5),
                    Text(
                      contact.email,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: _detailStyle,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static const _detailStyle = TextStyle(
    fontFamily: 'Inter',
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.secondaryText,
  );
}

class _ImportAvatar extends StatelessWidget {
  const _ImportAvatar({required this.contact});

  final ImportContactModel contact;

  @override
  Widget build(BuildContext context) {
    final parts = contact.fullName.trim().split(RegExp(r'\s+'));
    final initials = parts
        .where((name) => name.isNotEmpty)
        .take(2)
        .map((name) => name[0].toUpperCase())
        .join();
    final fallback = Center(
      child: Text(
        initials.isEmpty ? '?' : initials,
        style: const TextStyle(
          color: AppColors.dark,
          fontFamily: 'Inter',
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
    );

    return ClipOval(
      child: SizedBox(
        width: 50,
        height: 50,
        child: ColoredBox(
          color: const Color(0xFFE3ECF0),
          child: contact.avatarAsset == null
              ? fallback
              : Image.asset(
                  contact.avatarAsset!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => fallback,
                ),
        ),
      ),
    );
  }
}
